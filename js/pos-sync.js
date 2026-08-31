/**
 * Custom Error class for Sync Operations
 */
export class SyncError extends Error {
  /**
   * Creates a new SyncError
   * @param {string} message Error message
   * @param {string} endpoint The endpoint that failed
   * @param {number} statusCode HTTP status code
   * @param {boolean} retryable Whether the operation can be retried
   */
  constructor(message, endpoint, statusCode, retryable = false) {
    super(message);
    this.name = 'SyncError';
    this.endpoint = endpoint;
    this.statusCode = statusCode;
    this.retryable = retryable;
  }
}

/**
 * Bidirectional synchronization engine between PWA client (IndexedDB) and Oracle ORDS REST APIs.
 */
export class POSSync {
  /**
   * Sync endpoints mapping entity names to API paths
   * @type {Object<string, string>}
   */
  static SYNC_ENDPOINTS = {
    items: '/api/items',
    variants: '/api/variants',
    categories: '/api/categories',
    priceLists: '/api/price-lists',
    customers: '/api/customers',
    paymentMethods: '/api/payment-methods',
    syncOrders: '/api/sync/orders',
    syncBatch: '/api/sync/batch',
  };

  /** Default synchronization interval in milliseconds (5 minutes) */
  static SYNC_INTERVAL = 300000;
  
  /** Maximum number of retry attempts for failed sync operations */
  static MAX_RETRY = 5;
  
  /** Threshold for price mismatch tolerance (1%) */
  static PRICE_MISMATCH_THRESHOLD = 0.01;

  /**
   * Initialize POSSync instance
   * @param {Object} params Configuration parameters
   * @param {string} params.baseUrl ORDS base URL e.g., 'https://your-server.com/ords/pos'
   * @param {string} params.terminalId POS terminal identifier
   * @param {string} params.orgId Inventory Organization ID
   * @param {string} params.userId Cashier user identifier
   */
  constructor({ baseUrl, terminalId, orgId, userId }) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.terminalId = terminalId;
    this.orgId = orgId;
    this.userId = userId;
    this._syncIntervalId = null;
    this._isSyncing = false;
    
    // Bind event listeners
    this._handleOnline = this._handleOnline.bind(this);
  }

  /**
   * Download master data from server to IndexedDB
   * @returns {Promise<Object>} Summary of updated entities
   */
  async pullMasterData() {
    this._dispatchEvent('pos-sync-start', { type: 'pullMasterData' });
    this._log('info', 'Starting master data pull');
    const summary = {};
    const entities = ['items', 'variants', 'categories', 'priceLists', 'customers', 'paymentMethods'];

    try {
      const lastSyncDate = await window.idbManager.getLastSyncDate();

      for (const entity of entities) {
        const endpoint = POSSync.SYNC_ENDPOINTS[entity];
        const url = this._buildUrl(endpoint, lastSyncDate ? { last_modified_after: lastSyncDate } : {});
        
        try {
          const response = await this._fetch(url);
          if (!response.ok) {
            throw new SyncError(`Failed to fetch ${entity}`, endpoint, response.status, response.status >= 500);
          }
          
          const data = await response.json();
          const items = Array.isArray(data.items) ? data.items : (Array.isArray(data) ? data : []);
          
          if (items.length > 0) {
            await window.idbManager.putBatch(entity, items);
          }
          
          summary[`${entity}Updated`] = items.length;
        } catch (error) {
          this._log('error', `Error syncing entity ${entity}`, error);
          summary[`${entity}Error`] = error.message;
        }
      }

      await window.idbManager.setLastSyncDate(new Date().toISOString());
      this._dispatchEvent('pos-sync-complete', { type: 'pullMasterData', summary });
      return summary;
    } catch (error) {
      this._log('error', 'Critical failure during pullMasterData', error);
      this._dispatchEvent('pos-sync-error', { type: 'pullMasterData', error });
      throw error;
    }
  }

  /**
   * Push pending offline orders to server
   * @returns {Promise<Object>} Summary of pushed orders
   */
  async pushOfflineOrders() {
    this._dispatchEvent('pos-sync-start', { type: 'pushOfflineOrders' });
    this._log('info', 'Starting push offline orders');
    const summary = { synced: 0, failed: 0, conflicts: 0 };

    try {
      const pendingOrders = await window.idbManager.getPendingOrders();
      if (!pendingOrders || pendingOrders.length === 0) {
        return summary;
      }

      const endpoint = POSSync.SYNC_ENDPOINTS.syncOrders;
      const url = this._buildUrl(endpoint);

      for (const order of pendingOrders) {
        try {
          const mismatches = await this.validatePriceConsistency(order.lines || []);
          if (mismatches.length > 0) {
            this._dispatchEvent('pos-sync-conflict', { type: 'price-mismatch', orderId: order.id, mismatches });
            this._log('warn', `Price mismatch for order ${order.id}`, mismatches);
            summary.conflicts++;
            order.hasPriceConflict = true;
            order.priceMismatches = mismatches;
          }

          const payload = {
            idempotency_key: order.id,
            terminal_id: this.terminalId,
            inv_org_id: this.orgId,
            cashier_user_id: this.userId,
            client_timestamp: order.timestamp || new Date().toISOString(),
            header: order.header || {},
            lines: order.lines || [],
            payments: order.payments || []
          };

          const attemptPush = async (attempt = 0) => {
            const response = await this._fetch(url, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(payload)
            });

            if (response.ok) {
              const result = await response.json();
              await window.idbManager.markOrderSynced(order.id, result.order_id);
              summary.synced++;
              return;
            } else if (response.status === 409) {
              await window.idbManager.markOrderSynced(order.id, null);
              summary.conflicts++;
              this._log('warn', `Duplicate order conflict: ${order.id}`);
              return;
            } else {
              throw new SyncError('Failed to push order', endpoint, response.status, response.status >= 500 || response.status === 429);
            }
          };

          await this._retry(attemptPush);
        } catch (error) {
          this._log('error', `Failed to push order ${order.id}`, error);
          const currentRetries = (order.retryCount || 0) + 1;
          if (currentRetries > POSSync.MAX_RETRY) {
            await window.idbManager.markOrderFailed(order.id, error.message);
          } else {
            await window.idbManager.updateOrder(order.id, { retryCount: currentRetries });
          }
          summary.failed++;
        }
      }

      this._dispatchEvent('pos-sync-complete', { type: 'pushOfflineOrders', summary });
      return summary;
    } catch (error) {
      this._log('error', 'Critical failure during pushOfflineOrders', error);
      this._dispatchEvent('pos-sync-error', { type: 'pushOfflineOrders', error });
      throw error;
    }
  }

  /**
   * Batch push all pending items (orders + cash movements + shift events)
   * @returns {Promise<Object>} Summary of batch processing results
   */
  async pushBatch() {
    this._dispatchEvent('pos-sync-start', { type: 'pushBatch' });
    this._log('info', 'Starting batch push');
    const summary = { processed: 0, successes: 0, failures: 0 };

    try {
      const offlineQueue = await window.idbManager.getOfflineQueue();
      if (!offlineQueue || offlineQueue.length === 0) {
        return summary;
      }

      const endpoint = POSSync.SYNC_ENDPOINTS.syncBatch;
      const url = this._buildUrl(endpoint);

      const response = await this._fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          terminal_id: this.terminalId,
          org_id: this.orgId,
          batch_timestamp: new Date().toISOString(),
          items: offlineQueue
        })
      });

      if (!response.ok) {
        throw new SyncError('Failed to push batch', endpoint, response.status, response.status >= 500);
      }

      const results = await response.json();
      const processResults = Array.isArray(results) ? results : results.items || [];
      
      summary.processed = processResults.length;
      for (const res of processResults) {
        if (res.status === 'success' || res.status === 'conflict') {
          await window.idbManager.removeFromOfflineQueue(res.id);
          summary.successes++;
        } else {
          summary.failures++;
        }
      }

      this._dispatchEvent('pos-sync-complete', { type: 'pushBatch', summary });
      return summary;
    } catch (error) {
      this._log('error', 'Critical failure during pushBatch', error);
      this._dispatchEvent('pos-sync-error', { type: 'pushBatch', error });
      throw error;
    }
  }

  /**
   * Complete bidirectional sync
   * @returns {Promise<Object>} Combined sync results
   */
  async fullSync() {
    if (this._isSyncing) {
      this._log('warn', 'Sync already in progress, skipping fullSync');
      return { skipped: true };
    }
    if (!this.isOnline()) {
      this._log('info', 'Client is offline, skipping fullSync');
      return { skipped: true, reason: 'offline' };
    }

    this._isSyncing = true;
    this._dispatchEvent('pos-sync-start', { type: 'fullSync' });
    const startTime = performance.now();
    const results = {};

    try {
      // Step 1: push pending changes to avoid conflicts
      results.pushOrders = await this.pushOfflineOrders();
      results.pushBatch = await this.pushBatch();

      // Step 2: pull master data to get fresh state
      results.pullData = await this.pullMasterData();

      const duration = performance.now() - startTime;
      results.durationMs = duration;

      this._log('info', 'Full sync completed successfully', results);
      this._dispatchEvent('pos-sync-complete', { type: 'fullSync', results });
      return results;
    } catch (error) {
      this._log('error', 'Full sync failed', error);
      this._dispatchEvent('pos-sync-error', { type: 'fullSync', error });
      throw error;
    } finally {
      this._isSyncing = false;
    }
  }

  /**
   * Start periodic sync
   * @param {number} [intervalMs=SYNC_INTERVAL] Sync interval in milliseconds
   */
  startAutoSync(intervalMs = POSSync.SYNC_INTERVAL) {
    if (this._syncIntervalId) {
      this.stopAutoSync();
    }
    
    this._syncIntervalId = setInterval(() => {
      this.fullSync().catch(err => this._log('error', 'Auto sync failed', err));
    }, intervalMs);

    window.addEventListener('online', this._handleOnline);
    this._log('info', `Auto sync started with interval ${intervalMs}ms`);
  }

  /**
   * Stop periodic sync
   */
  stopAutoSync() {
    if (this._syncIntervalId) {
      clearInterval(this._syncIntervalId);
      this._syncIntervalId = null;
    }
    window.removeEventListener('online', this._handleOnline);
    this._log('info', 'Auto sync stopped');
  }

  /**
   * Event listener for 'online' event to trigger immediate sync
   * @private
   */
  _handleOnline() {
    this._log('info', 'Client came online, triggering full sync');
    this.fullSync().catch(err => this._log('error', 'Online event sync failed', err));
  }

  /**
   * Check if server is reachable
   * @returns {Promise<boolean>} True if server responds to health check
   */
  async checkConnectivity() {
    if (!this.isOnline()) return false;
    
    try {
      const url = this._buildUrl('/api/health');
      const response = await this._fetch(url, { method: 'HEAD' }, 5000);
      return response.ok;
    } catch (error) {
      this._log('warn', 'Connectivity check failed', error);
      return false;
    }
  }

  /**
   * Returns true if the browser reports it's online
   * @returns {boolean}
   */
  isOnline() {
    return navigator.onLine;
  }

  /**
   * Retrieve current server time
   * @returns {Promise<string>} ISO timestamp string
   */
  async getServerTime() {
    const url = this._buildUrl('/api/server-time');
    const response = await this._fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to get server time, status ${response.status}`);
    }
    const data = await response.json();
    return data.timestamp || new Date().toISOString();
  }

  /**
   * Check local vs server prices for order lines
   * @param {Array<Object>} orderLines 
   * @returns {Promise<Array<Object>>} Array of mismatches found
   */
  async validatePriceConsistency(orderLines) {
    const mismatches = [];
    
    for (const line of orderLines) {
      if (!line.itemId || typeof line.price !== 'number') continue;

      try {
        const localItem = await window.idbManager.getItem(line.itemId);
        if (localItem && typeof localItem.price === 'number') {
          const diff = Math.abs(localItem.price - line.price);
          const maxDiff = localItem.price * POSSync.PRICE_MISMATCH_THRESHOLD;
          
          if (diff > maxDiff) {
            mismatches.push({
              itemId: line.itemId,
              localPrice: localItem.price,
              orderPrice: line.price,
              difference: diff
            });
          }
        }
      } catch (error) {
        this._log('warn', `Could not validate price for item ${line.itemId}`, error);
      }
    }
    
    return mismatches;
  }

  /**
   * Fetch wrapper with timeout and AbortController
   * @param {string} url Request URL
   * @param {Object} [options={}] Fetch options
   * @param {number} [timeoutMs=10000] Timeout in milliseconds
   * @returns {Promise<Response>}
   * @private
   */
  async _fetch(url, options = {}, timeoutMs = 10000) {
    const controller = new AbortController();
    const id = setTimeout(() => controller.abort(), timeoutMs);
    
    try {
      const response = await fetch(url, {
        ...options,
        signal: controller.signal
      });
      clearTimeout(id);
      return response;
    } catch (error) {
      clearTimeout(id);
      throw error;
    }
  }

  /**
   * Construct URL with query parameters
   * @param {string} endpoint API endpoint path
   * @param {Object} [params={}] Query parameters
   * @returns {string} Fully constructed URL
   * @private
   */
  _buildUrl(endpoint, params = {}) {
    const url = new URL(`${this.baseUrl}${endpoint}`);
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== null) {
        url.searchParams.append(key, value);
      }
    }
    return url.toString();
  }

  /**
   * Structured logging with timestamp
   * @param {string} level Log level (info, warn, error)
   * @param {string} message Log message
   * @param {*} [data] Additional data to log
   * @private
   */
  _log(level, message, data = null) {
    const timestamp = new Date().toISOString();
    const logPrefix = `[POSSync ${timestamp}]`;
    if (data) {
      console[level](`${logPrefix} ${message}`, data);
    } else {
      console[level](`${logPrefix} ${message}`);
    }
  }

  /**
   * Dispatch a CustomEvent on the document
   * @param {string} eventName Name of the event
   * @param {Object} detail Event payload
   * @private
   */
  _dispatchEvent(eventName, detail) {
    const event = new CustomEvent(eventName, { detail });
    document.dispatchEvent(event);
  }

  /**
   * Retry logic with exponential backoff
   * @param {Function} asyncFn Function returning a promise to execute
   * @param {number} [maxRetries=POSSync.MAX_RETRY] Maximum retry attempts
   * @returns {Promise<any>}
   * @private
   */
  async _retry(asyncFn, maxRetries = POSSync.MAX_RETRY) {
    let attempt = 0;
    while (attempt <= maxRetries) {
      try {
        return await asyncFn(attempt);
      } catch (error) {
        const isRetryable = error instanceof SyncError ? error.retryable : true;
        if (!isRetryable || attempt === maxRetries || error.name === 'AbortError') {
          throw error;
        }
        
        attempt++;
        const waitTime = Math.min(1000 * Math.pow(2, attempt), 30000);
        this._log('warn', `Retry attempt ${attempt} in ${waitTime}ms due to: ${error.message}`);
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }
    }
  }
}

// Export to window object for global availability
if (typeof window !== 'undefined') {
  window.POSSync = POSSync;
}
