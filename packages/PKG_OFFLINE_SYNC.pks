CREATE OR REPLACE PACKAGE PKG_OFFLINE_SYNC AS
-- ============================================================================
-- Package: PKG_OFFLINE_SYNC
-- Purpose: Process offline POS transactions from PWA/IndexedDB.
--          Handles JSON payload parsing, idempotency, conflict detection/resolution.
-- الغرض: معالجة العمليات الغير متصلة بالإنترنت القادمة من الواجهة، 
--        التعامل مع الحمولات بصيغة JSON وحل التعارضات.
-- ============================================================================

  E_DUPLICATE_PAYLOAD  CONSTANT NUMBER := -20401;
  E_INVALID_PAYLOAD    CONSTANT NUMBER := -20402;
  E_SYNC_CONFLICT      CONSTANT NUMBER := -20403;
  E_MAX_RETRIES        CONSTANT NUMBER := -20404;

  MAX_RETRY_COUNT      CONSTANT NUMBER := 5;

  -- Receive a raw JSON payload from the PWA client
  -- استلام حمولة JSON من العميل
  PROCEDURE RECEIVE_PAYLOAD(
    p_idempotency_key IN VARCHAR2,
    p_terminal_id     IN NUMBER,
    p_inv_org_id      IN NUMBER,
    p_cashier_user_id IN NUMBER,
    p_payload_type    IN VARCHAR2,
    p_payload_json    IN CLOB,
    p_client_timestamp IN TIMESTAMP,
    p_sync_id         OUT NUMBER,
    p_status          OUT VARCHAR2  -- 'PENDING' or 'DUPLICATE'
  );

  -- Process a single pending sync payload
  -- معالجة حمولة مزامنة معلقة واحدة
  PROCEDURE PROCESS_PAYLOAD(
    p_sync_id IN NUMBER
  );

  -- Batch-process all pending payloads for an org
  -- معالجة مجمعة لجميع الحمولات المعلقة للفرع
  PROCEDURE PROCESS_PENDING_BATCH(
    p_inv_org_id IN NUMBER DEFAULT NULL,
    p_max_records IN NUMBER DEFAULT 100
  );

  -- Process an ORDER-type payload: parse JSON, create order via PKG_POS_CORE
  -- معالجة حمولة من نوع طلب: استخراج البيانات وإنشاء الطلب
  PROCEDURE APPLY_ORDER_PAYLOAD(
    p_sync_id IN NUMBER,
    p_payload IN CLOB
  );

  -- Log a sync conflict for manual review
  -- تسجيل تعارض مزامنة للمراجعة اليدوية
  PROCEDURE LOG_CONFLICT(
    p_sync_id       IN NUMBER,
    p_conflict_type IN VARCHAR2,
    p_detail        IN CLOB DEFAULT NULL,
    p_server_value  IN CLOB DEFAULT NULL,
    p_client_value  IN CLOB DEFAULT NULL
  );

  -- Retry a failed payload
  -- إعادة محاولة حمولة فاشلة
  PROCEDURE RETRY_PAYLOAD(p_sync_id IN NUMBER);

  -- Mark a conflict as resolved
  -- تحديد التعارض كـ محلول
  PROCEDURE RESOLVE_CONFLICT(
    p_conflict_id  IN NUMBER,
    p_resolution   IN VARCHAR2  -- CLIENT_WINS, SERVER_WINS, MANUAL, MERGED
  );

  -- Get sync status summary (for dashboard)
  -- الحصول على ملخص حالة المزامنة
  FUNCTION GET_SYNC_SUMMARY(
    p_inv_org_id IN NUMBER DEFAULT NULL
  ) RETURN SYS_REFCURSOR;

END PKG_OFFLINE_SYNC;
/
