CREATE OR REPLACE PACKAGE BODY PKG_OFFLINE_SYNC AS
-- ============================================================================
-- Package: PKG_OFFLINE_SYNC
-- Purpose: Process offline POS transactions from PWA/IndexedDB.
-- ============================================================================

  -- Log Conflict autonomously
  -- تسجيل التعارض بمعاملة مستقلة
  PROCEDURE LOG_CONFLICT(
    p_sync_id       IN NUMBER,
    p_conflict_type IN VARCHAR2,
    p_detail        IN CLOB DEFAULT NULL,
    p_server_value  IN CLOB DEFAULT NULL,
    p_client_value  IN CLOB DEFAULT NULL
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO POS_SYNC_CONFLICT_LOG (
      CONFLICT_ID, SYNC_ID, CONFLICT_TYPE, CONFLICT_DETAIL,
      SERVER_VALUE, CLIENT_VALUE
    ) VALUES (
      POS_SYNC_CONFLICT_LOG_SEQ.NEXTVAL, p_sync_id, p_conflict_type, p_detail,
      p_server_value, p_client_value
    );
    COMMIT;
  END LOG_CONFLICT;

  -- Receive Payload
  -- استلام الحمولة
  PROCEDURE RECEIVE_PAYLOAD(
    p_idempotency_key IN VARCHAR2,
    p_terminal_id     IN NUMBER,
    p_inv_org_id      IN NUMBER,
    p_cashier_user_id IN NUMBER,
    p_payload_type    IN VARCHAR2,
    p_payload_json    IN CLOB,
    p_client_timestamp IN TIMESTAMP,
    p_sync_id         OUT NUMBER,
    p_status          OUT VARCHAR2
  ) IS
    v_sync_status VARCHAR2(20);
    v_sync_id     NUMBER;
    v_checksum    VARCHAR2(256);
  BEGIN
    -- Check for duplicate idempotency key
    -- التحقق من تكرار المفتاح
    BEGIN
      SELECT SYNC_ID, SYNC_STATUS INTO v_sync_id, v_sync_status
      FROM POS_OFFLINE_SYNC_QUEUE
      WHERE IDEMPOTENCY_KEY = p_idempotency_key;

      IF v_sync_status = 'COMPLETED' THEN
        p_status := 'DUPLICATE';
        p_sync_id := v_sync_id;
        RETURN;
      ELSIF v_sync_status = 'FAILED' THEN
        UPDATE POS_OFFLINE_SYNC_QUEUE
        SET SYNC_STATUS = 'PENDING', RETRY_COUNT = RETRY_COUNT + 1
        WHERE SYNC_ID = v_sync_id;
        p_status := 'PENDING';
        p_sync_id := v_sync_id;
        RETURN;
      END IF;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL; -- Continue to insert new
    END;

    BEGIN
      SELECT STANDARD_HASH(SUBSTR(p_payload_json, 1, 4000), 'SHA256') INTO v_checksum FROM DUAL;
    EXCEPTION
      WHEN OTHERS THEN
        v_checksum := TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISSFF6');
    END;

    INSERT INTO POS_OFFLINE_SYNC_QUEUE (
      SYNC_ID, IDEMPOTENCY_KEY, TERMINAL_ID, INV_ORG_ID, CASHIER_USER_ID,
      PAYLOAD_TYPE, PAYLOAD, PAYLOAD_CHECKSUM, CLIENT_TIMESTAMP,
      SERVER_RECEIVED_TIMESTAMP, SYNC_STATUS, RETRY_COUNT
    ) VALUES (
      POS_OFFLINE_SYNC_QUEUE_SEQ.NEXTVAL, p_idempotency_key, p_terminal_id, p_inv_org_id, p_cashier_user_id,
      p_payload_type, p_payload_json, v_checksum, p_client_timestamp,
      SYSTIMESTAMP, 'PENDING', 0
    ) RETURNING SYNC_ID INTO p_sync_id;

    p_status := 'PENDING';
  END RECEIVE_PAYLOAD;

  -- Apply Order Payload
  -- تطبيق حمولة الطلب
  PROCEDURE APPLY_ORDER_PAYLOAD(
    p_sync_id IN NUMBER,
    p_payload IN CLOB
  ) IS
    v_order_type VARCHAR2(50);
    v_currency_code VARCHAR2(10);
    v_customer_id NUMBER;
    v_order_id NUMBER;
    v_server_price NUMBER;
    v_price_threshold NUMBER := 0.05; -- 5% tolerance
  BEGIN
    -- Extract Header using JSON_VALUE (Oracle 12c+)
    -- استخراج بيانات الترويسة
    v_order_type := JSON_VALUE(p_payload, '$.order_type');
    v_currency_code := JSON_VALUE(p_payload, '$.currency_code');
    v_customer_id := TO_NUMBER(JSON_VALUE(p_payload, '$.customer_id'));

    -- MOCK: Call PKG_POS_CORE.CREATE_ORDER
    -- v_order_id := PKG_POS_CORE.CREATE_ORDER(...);
    -- Here we simulate returning a new ID:
    v_order_id := 9999; 

    -- Extract and loop lines using JSON_TABLE
    -- استخراج واللف على أسطر الطلب
    FOR r_line IN (
      SELECT * FROM JSON_TABLE(p_payload, '$.lines[*]'
        COLUMNS (
          item_id NUMBER PATH '$.item_id',
          qty NUMBER PATH '$.qty',
          price NUMBER PATH '$.price',
          discount NUMBER PATH '$.discount'
        )
      )
    ) LOOP
      -- MOCK: Verify server price
      v_server_price := r_line.price; -- Assume matched for simulation
      
      IF ABS(v_server_price - r_line.price) > v_price_threshold THEN
        LOG_CONFLICT(
          p_sync_id       => p_sync_id,
          p_conflict_type => 'PRICE_MISMATCH',
          p_detail        => 'Client price differs from server price for Item: ' || r_line.item_id,
          p_server_value  => TO_CHAR(v_server_price),
          p_client_value  => TO_CHAR(r_line.price)
        );
      END IF;

      -- MOCK: Call PKG_POS_CORE.ADD_ORDER_LINE
      -- PKG_POS_CORE.ADD_ORDER_LINE(v_order_id, r_line.item_id, r_line.qty, ...);
    END LOOP;

    -- Extract and loop payments
    -- استخراج واللف على المدفوعات
    FOR r_pay IN (
      SELECT * FROM JSON_TABLE(p_payload, '$.payments[*]'
        COLUMNS (
          method_id NUMBER PATH '$.method_id',
          amount NUMBER PATH '$.amount',
          reference VARCHAR2(100) PATH '$.reference'
        )
      )
    ) LOOP
      -- MOCK: Call PKG_POS_CORE.ADD_PAYMENT
      -- PKG_POS_CORE.ADD_PAYMENT(v_order_id, r_pay.method_id, r_pay.amount, ...);
      NULL;
    END LOOP;

    -- MOCK: Call PKG_POS_CORE.SETTLE_ORDER
    -- PKG_POS_CORE.SETTLE_ORDER(v_order_id);

    -- Update processed order ID
    UPDATE POS_OFFLINE_SYNC_QUEUE
    SET PROCESSED_ORDER_ID = v_order_id
    WHERE SYNC_ID = p_sync_id;
  END APPLY_ORDER_PAYLOAD;

  -- Process Payload
  -- معالجة الحمولة
  PROCEDURE PROCESS_PAYLOAD(
    p_sync_id IN NUMBER
  ) IS
    v_sync_rec POS_OFFLINE_SYNC_QUEUE%ROWTYPE;
  BEGIN
    SAVEPOINT process_payload_sp;
    
    -- Lock row
    SELECT * INTO v_sync_rec
    FROM POS_OFFLINE_SYNC_QUEUE
    WHERE SYNC_ID = p_sync_id
    FOR UPDATE SKIP LOCKED;

    UPDATE POS_OFFLINE_SYNC_QUEUE SET SYNC_STATUS = 'PROCESSING' WHERE SYNC_ID = p_sync_id;

    -- Branch by Type
    IF v_sync_rec.PAYLOAD_TYPE = 'ORDER' THEN
      APPLY_ORDER_PAYLOAD(p_sync_id, v_sync_rec.PAYLOAD);
    ELSIF v_sync_rec.PAYLOAD_TYPE = 'SHIFT_OPEN' THEN
      NULL; -- implement logic
    ELSIF v_sync_rec.PAYLOAD_TYPE = 'SHIFT_CLOSE' THEN
      NULL; -- implement logic
    END IF;

    UPDATE POS_OFFLINE_SYNC_QUEUE
    SET SYNC_STATUS = 'COMPLETED', PROCESSED_TIMESTAMP = SYSTIMESTAMP
    WHERE SYNC_ID = p_sync_id;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO process_payload_sp;
      DECLARE
        v_err VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 4000);
      BEGIN
        UPDATE POS_OFFLINE_SYNC_QUEUE
        SET SYNC_STATUS = 'FAILED', 
            RETRY_COUNT = RETRY_COUNT + 1,
            LAST_ERROR = v_err
        WHERE SYNC_ID = p_sync_id;
      END;
  END PROCESS_PAYLOAD;

  -- Batch Process
  -- المعالجة المجمعة
  PROCEDURE PROCESS_PENDING_BATCH(
    p_inv_org_id IN NUMBER DEFAULT NULL,
    p_max_records IN NUMBER DEFAULT 100
  ) IS
  BEGIN
    FOR r_sync IN (
      SELECT SYNC_ID 
      FROM POS_OFFLINE_SYNC_QUEUE
      WHERE SYNC_STATUS = 'PENDING'
        AND RETRY_COUNT < MAX_RETRY_COUNT
        AND (p_inv_org_id IS NULL OR INV_ORG_ID = p_inv_org_id)
      ORDER BY CLIENT_TIMESTAMP ASC
      FETCH FIRST p_max_records ROWS ONLY
    ) LOOP
      PROCESS_PAYLOAD(r_sync.SYNC_ID);
    END LOOP;
  END PROCESS_PENDING_BATCH;

  -- Retry
  PROCEDURE RETRY_PAYLOAD(p_sync_id IN NUMBER) IS
  BEGIN
    UPDATE POS_OFFLINE_SYNC_QUEUE
    SET SYNC_STATUS = 'PENDING'
    WHERE SYNC_ID = p_sync_id AND SYNC_STATUS = 'FAILED';
  END RETRY_PAYLOAD;

  -- Resolve Conflict
  PROCEDURE RESOLVE_CONFLICT(
    p_conflict_id  IN NUMBER,
    p_resolution   IN VARCHAR2
  ) IS
  BEGIN
    UPDATE POS_SYNC_CONFLICT_LOG
    SET RESOLUTION = p_resolution,
        RESOLVED_BY = TO_NUMBER(SYS_CONTEXT('POS_CTX', 'APP_USER_ID')),
        RESOLVED_DATE = SYSDATE
    WHERE CONFLICT_ID = p_conflict_id;
  END RESOLVE_CONFLICT;

  -- Get Sync Summary
  FUNCTION GET_SYNC_SUMMARY(
    p_inv_org_id IN NUMBER DEFAULT NULL
  ) RETURN SYS_REFCURSOR IS
    v_rc SYS_REFCURSOR;
  BEGIN
    OPEN v_rc FOR
      SELECT SYNC_STATUS, COUNT(*) AS TOTAL_COUNT
      FROM POS_OFFLINE_SYNC_QUEUE
      WHERE (p_inv_org_id IS NULL OR INV_ORG_ID = p_inv_org_id)
      GROUP BY SYNC_STATUS;
    RETURN v_rc;
  END GET_SYNC_SUMMARY;

END PKG_OFFLINE_SYNC;
/
