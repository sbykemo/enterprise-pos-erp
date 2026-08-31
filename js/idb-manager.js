/**
 * Generates a UUID v4 string
 * @returns {string} UUID v4
 */
function generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

/**
 * IndexedDB abstraction layer for offline POS data storage.
 */
class IDBManager {
  constructor() {
    this.dbName = 'POS_OFFLINE_DB';
    this.dbVersion = 1;
    this.db = null;
    this.initPromise = this.openDB();
  }

  /**
   * Opens the IndexedDB connection and handles schema creation/upgrades.
   * @returns {Promise<IDBDatabase>}
   */
  openDB() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(this.dbName, this.dbVersion);

      request.onupgradeneeded = (event) => {
        const db = event.target.result;
        
        if (!db.objectStoreNames.contains('items')) {
          const itemsStore = db.createObjectStore('items', { keyPath: 'item_id' });
          itemsStore.createIndex('barcode', 'barcode', { unique: false });
          itemsStore.createIndex('alt_barcode', 'alt_barcode', { unique: false });
          itemsStore.createIndex('category_id', 'category_id', { unique: false });
          itemsStore.createIndex('item_code', 'item_code', { unique: false });
          itemsStore.createIndex('is_active', 'is_active', { unique: false });
        }

        if (!db.objectStoreNames.contains('variants')) {
          const variantsStore = db.createObjectStore('variants', { keyPath: 'variant_id' });
          variantsStore.createIndex('item_id', 'item_id', { unique: false });
          variantsStore.createIndex('sku_code', 'sku_code', { unique: false });
          variantsStore.createIndex('barcode', 'barcode', { unique: false });
        }

        if (!db.objectStoreNames.contains('categories')) {
          const categoriesStore = db.createObjectStore('categories', { keyPath: 'category_id' });
          categoriesStore.createIndex('parent_category_id', 'parent_category_id', { unique: false });
          categoriesStore.createIndex('is_active', 'is_active', { unique: false });
        }

        if (!db.objectStoreNames.contains('priceLists')) {
          const priceListsStore = db.createObjectStore('priceLists', { keyPath: 'price_line_id' });
          priceListsStore.createIndex('price_list_id', 'price_list_id', { unique: false });
          priceListsStore.createIndex('item_id', 'item_id', { unique: false });
        }

        if (!db.objectStoreNames.contains('customers')) {
          const customersStore = db.createObjectStore('customers', { keyPath: 'customer_id' });
          customersStore.createIndex('customer_code', 'customer_code', { unique: false });
          customersStore.createIndex('phone', 'phone', { unique: false });
          customersStore.createIndex('customer_name_en', 'customer_name_en', { unique: false });
        }

        if (!db.objectStoreNames.contains('paymentMethods')) {
          const pmStore = db.createObjectStore('paymentMethods', { keyPath: 'payment_method_id' });
          pmStore.createIndex('method_code', 'method_code', { unique: true });
        }

        if (!db.objectStoreNames.contains('offlineOrders')) {
          const offlineOrdersStore = db.createObjectStore('offlineOrders', { keyPath: 'idempotency_key' });
          offlineOrdersStore.createIndex('sync_status', 'sync_status', { unique: false });
          offlineOrdersStore.createIndex('created_at', 'created_at', { unique: false });
          offlineOrdersStore.createIndex('order_no', 'order_no', { unique: false });
        }

        if (!db.objectStoreNames.contains('offlineQueue')) {
          const offlineQueueStore = db.createObjectStore('offlineQueue', { keyPath: 'queue_id', autoIncrement: true });
          offlineQueueStore.createIndex('payload_type', 'payload_type', { unique: false });
          offlineQueueStore.createIndex('status', 'status', { unique: false });
          offlineQueueStore.createIndex('created_at', 'created_at', { unique: false });
        }

        if (!db.objectStoreNames.contains('settings')) {
          db.createObjectStore('settings', { keyPath: 'key' });
        }

        if (!db.objectStoreNames.contains('syncLog')) {
          const syncLogStore = db.createObjectStore('syncLog', { keyPath: 'log_id', autoIncrement: true });
          syncLogStore.createIndex('sync_date', 'sync_date', { unique: false });
          syncLogStore.createIndex('status', 'status', { unique: false });
        }
      };

      request.onsuccess = (event) => {
        this.db = event.target.result;
        resolve(this.db);
      };

      request.onerror = (event) => {
        console.error('IDBManager: Error opening DB', event.target.error);
        reject(event.target.error);
      };
    });
  }

  async _getDB() {
    if (!this.db) {
      await this.initPromise;
    }
    return this.db;
  }

  /**
   * Get all records from a store, optionally filtered by an index and query.
   * @param {string} storeName
   * @param {string} [indexName]
   * @param {any} [query]
   * @returns {Promise<Array>}
   */
  async getAll(storeName, indexName = null, query = null) {
    const db = await this._getDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(storeName, 'readonly');
      const store = transaction.objectStore(storeName);
      let request;

      if (indexName) {
        const index = store.index(indexName);
        request = query ? index.getAll(query) : index.getAll();
      } else {
        request = query ? store.getAll(query) : store.getAll();
      }

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  /**
   * Get a single record by primary key.
   * @param {string} storeName
   * @param {any} key
   * @returns {Promise<Object>}
   */
  async getByKey(storeName, key) {
    const db = await this._getDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(storeName, 'readonly');
      const store = transaction.objectStore(storeName);
      const request = store.get(key);

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  /**
   * Get records by index value.
   * @param {string} storeName
   * @param {string} indexName
   * @param {any} value
   * @returns {Promise<Array>}
   */
  async getByIndex(storeName, indexName, value) {
    return this.getAll(storeName, indexName, IDBKeyRange.only(value));
  }

  /**
   * Insert or update a single record.
   * @param {string} storeName
   * @param {Object} data
   * @returns {Promise<void>}
   */
  async put(storeName, data) {
    const db = await this._getDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(storeName, 'readwrite');
      const store = transaction.objectStore(storeName);
      const request = store.put(data);

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  /**
   * Batch insert/update for bulk sync operations.
   * @param {string} storeName
   * @param {Array<Object>} dataArray
   * @returns {Promise<void>}
   */
  async putBatch(storeName, dataArray) {
    if (!Array.isArray(dataArray) || dataArray.length === 0) return;
    const db = await this._getDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(storeName, 'readwrite');
      const store = transaction.objectStore(storeName);
      
      transaction.oncomplete = () => resolve();
      transaction.onerror = (e) => reject(e.target.error);

      dataArray.forEach(data => store.put(data));
    });
  }

  /**
   * Delete a record by key.
   * @param {string} storeName
   * @param {any} key
   * @returns {Promise<void>}
   */
  async delete(storeName, key) {
    const db = await this._getDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(storeName, 'readwrite');
      const store = transaction.objectStore(storeName);
      const request = store.delete(key);

      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  /**
   * Clear all records in a store.
   * @param {string} storeName
   * @returns {Promise<void>}
   */
  async clear(storeName) {
    const db = await this._getDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(storeName, 'readwrite');
      const store = transaction.objectStore(storeName);
      const request = store.clear();

      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  /**
   * Count records in a store.
   * @param {string} storeName
   * @returns {Promise<number>}
   */
  async count(storeName) {
    const db = await this._getDB();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(storeName, 'readonly');
      const store = transaction.objectStore(storeName);
      const request = store.count();

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  /**
   * Search items by name, barcode, or code. Scans items and variants stores.
   * @param {string} query
   * @returns {Promise<Array>}
   */
  async searchItems(query) {
    if (!query) return [];
    query = query.toLowerCase();
    
    // Simplistic search: fetch all items and variants and filter in memory
    const [allItems, allVariants] = await Promise.all([
      this.getAll('items'),
      this.getAll('variants')
    ]);

    const matchingItems = allItems.filter(item => 
      (item.item_code && item.item_code.toLowerCase().includes(query)) ||
      (item.barcode && item.barcode.toLowerCase().includes(query)) ||
      (item.alt_barcode && item.alt_barcode.toLowerCase().includes(query)) ||
      (item.name_en && item.name_en.toLowerCase().includes(query))
    );

    const matchingVariants = allVariants.filter(variant => 
      (variant.sku_code && variant.sku_code.toLowerCase().includes(query)) ||
      (variant.barcode && variant.barcode.toLowerCase().includes(query))
    );

    return { items: matchingItems, variants: matchingVariants };
  }

  /**
   * Resolve price from local priceLists store.
   * @param {number|string} itemId
   * @param {number|string} variantId
   * @param {number|string} priceListId
   * @returns {Promise<Object>}
   */
  async getItemPrice(itemId, variantId, priceListId) {
    const prices = await this.getByIndex('priceLists', 'item_id', itemId);
    if (!prices || prices.length === 0) return null;

    let applicablePrices = prices.filter(p => p.price_list_id === priceListId);
    if (applicablePrices.length === 0) return null;

    if (variantId) {
      const variantPrice = applicablePrices.find(p => p.variant_id === variantId);
      if (variantPrice) return variantPrice;
    }
    
    return applicablePrices.find(p => !p.variant_id) || applicablePrices[0];
  }

  /**
   * Save order to offlineOrders with status 'PENDING' and generate idempotency_key (UUID).
   * @param {Object} orderData
   * @returns {Promise<string>} The generated idempotency_key
   */
  async queueOfflineOrder(orderData) {
    const idempotency_key = generateUUID();
    const order = {
      ...orderData,
      idempotency_key,
      sync_status: 'PENDING',
      created_at: new Date().toISOString()
    };
    await this.put('offlineOrders', order);
    
    // Also push to offlineQueue for sync background job
    await this.put('offlineQueue', {
      payload_type: 'ORDER',
      payload: order,
      status: 'PENDING',
      created_at: order.created_at
    });

    return idempotency_key;
  }

  /**
   * Get all orders with sync_status='PENDING'.
   * @returns {Promise<Array>}
   */
  async getPendingOrders() {
    return this.getByIndex('offlineOrders', 'sync_status', 'PENDING');
  }

  /**
   * Update order status to 'SYNCED'.
   * @param {string} idempotencyKey
   * @param {string|number} serverOrderId
   * @returns {Promise<void>}
   */
  async markOrderSynced(idempotencyKey, serverOrderId) {
    const order = await this.getByKey('offlineOrders', idempotencyKey);
    if (order) {
      order.sync_status = 'SYNCED';
      order.server_order_id = serverOrderId;
      order.synced_at = new Date().toISOString();
      await this.put('offlineOrders', order);
    }
  }

  /**
   * Update order status to 'FAILED'.
   * @param {string} idempotencyKey
   * @param {any} error
   * @returns {Promise<void>}
   */
  async markOrderFailed(idempotencyKey, error) {
    const order = await this.getByKey('offlineOrders', idempotencyKey);
    if (order) {
      order.sync_status = 'FAILED';
      order.sync_error = error ? error.toString() : 'Unknown error';
      order.failed_at = new Date().toISOString();
      await this.put('offlineOrders', order);
    }
  }

  /**
   * Get value from settings store.
   * @param {string} key
   * @returns {Promise<any>}
   */
  async getSetting(key) {
    const record = await this.getByKey('settings', key);
    return record ? record.value : null;
  }

  /**
   * Put value to settings store.
   * @param {string} key
   * @param {any} value
   * @returns {Promise<void>}
   */
  async setSetting(key, value) {
    return this.put('settings', { key, value });
  }

  /**
   * Get 'lastSyncDate' from settings.
   * @returns {Promise<string>}
   */
  async getLastSyncDate() {
    return this.getSetting('lastSyncDate');
  }

  /**
   * Save sync timestamp.
   * @param {string|Date} date
   * @returns {Promise<void>}
   */
  async setLastSyncDate(date) {
    const dateStr = date instanceof Date ? date.toISOString() : date;
    return this.setSetting('lastSyncDate', dateStr);
  }
}

// Export as ES6 module
export { IDBManager, generateUUID };

// Attach to window object if available (for non-module script tags)
if (typeof window !== 'undefined') {
  window.IDBManager = IDBManager;
}
