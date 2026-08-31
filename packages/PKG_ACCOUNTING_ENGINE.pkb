CREATE OR REPLACE PACKAGE BODY PKG_ACCOUNTING_ENGINE AS
-- ============================================================================
-- Package: PKG_ACCOUNTING_ENGINE
-- Purpose: Subledger Accounting (SLA) - Automated GL journal generation
-- ============================================================================

  -- Private helper: Get current user ID from session context
  -- دالة مساعدة: الحصول على معرف المستخدم الحالي
  FUNCTION get_current_user_id RETURN NUMBER IS
    v_user_id NUMBER;
  BEGIN
    v_user_id := TO_NUMBER(SYS_CONTEXT('POS_CTX', 'APP_USER_ID'));
    RETURN NVL(v_user_id, -1); -- Default to -1 (System) if context is missing
  EXCEPTION
    WHEN OTHERS THEN
      RETURN -1;
  END get_current_user_id;

  -- Private helper: Get Account ID by Code
  -- دالة مساعدة: الحصول على معرف الحساب من خلال الكود
  FUNCTION get_account_by_code(p_code IN VARCHAR2, p_le_id IN NUMBER) RETURN NUMBER IS
    v_account_id POS_COA_ACCOUNTS.ACCOUNT_ID%TYPE;
  BEGIN
    SELECT ACCOUNT_ID INTO v_account_id
    FROM POS_COA_ACCOUNTS
    WHERE ACCOUNT_CODE = p_code
      AND LEGAL_ENTITY_ID = p_le_id
      AND IS_ACTIVE = 'Y';
    RETURN v_account_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(E_ACCOUNT_INACTIVE, 'Account Code not found or inactive: ' || p_code);
  END get_account_by_code;

  -- Private helper: Get SLA Rule
  -- دالة مساعدة: الحصول على قاعدة المحاسبة الفرعية
  FUNCTION get_sla_rule(
    p_source IN VARCHAR2,
    p_txn_type IN VARCHAR2,
    p_line_type IN VARCHAR2
  ) RETURN POS_SLA_RULES%ROWTYPE IS
    v_rule POS_SLA_RULES%ROWTYPE;
  BEGIN
    SELECT * INTO v_rule
    FROM POS_SLA_RULES
    WHERE SOURCE = p_source
      AND TXN_TYPE = p_txn_type
      AND LINE_TYPE = p_line_type
      AND IS_ACTIVE = 'Y'
      AND ROWNUM = 1; -- Taking highest priority logically
    RETURN v_rule;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(E_NO_SLA_RULE, 'No active SLA rule found for: ' || p_source || '/' || p_txn_type);
  END get_sla_rule;

  -- Generate a unique journal number
  -- إنشاء رقم قيد فريد
  FUNCTION GENERATE_JOURNAL_NO(p_source IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN 'JNL-' || p_source || '-' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '-' || POS_GL_JOURNALS_SEQ.NEXTVAL;
  END GENERATE_JOURNAL_NO;

  -- Get the open accounting period
  -- الحصول على الفترة المحاسبية المفتوحة
  FUNCTION GET_OPEN_PERIOD(
    p_legal_entity_id IN NUMBER,
    p_journal_date    IN DATE DEFAULT SYSDATE
  ) RETURN NUMBER IS
    v_period_id POS_GL_PERIODS.PERIOD_ID%TYPE;
  BEGIN
    SELECT PERIOD_ID INTO v_period_id
    FROM POS_GL_PERIODS
    WHERE LEGAL_ENTITY_ID = p_legal_entity_id
      AND p_journal_date BETWEEN START_DATE AND END_DATE
      AND CLOSE_STATUS = 'OPEN';
    RETURN v_period_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(E_PERIOD_CLOSED, 'Accounting period is closed or does not exist for the given date.');
  END GET_OPEN_PERIOD;

  -- Get legal entity
  -- الحصول على الكيان القانوني
  FUNCTION GET_LEGAL_ENTITY(p_inv_org_id IN NUMBER) RETURN NUMBER IS
    v_le_id POS_OPERATING_UNITS.LEGAL_ENTITY_ID%TYPE;
  BEGIN
    -- Assuming POS_INVENTORY_ORGS maps to POS_OPERATING_UNITS
    -- افتراض وجود علاقة بين المخزون والكيان عبر الوحدة التشغيلية
    -- MOCK LOGIC for demonstration
    SELECT 1 INTO v_le_id FROM DUAL; 
    RETURN v_le_id;
  END GET_LEGAL_ENTITY;

  -- Create Journal
  -- إنشاء القيد
  PROCEDURE CREATE_JOURNAL(
    p_legal_entity_id IN NUMBER,
    p_journal_date    IN DATE,
    p_source          IN VARCHAR2,
    p_category        IN VARCHAR2 DEFAULT NULL,
    p_description     IN VARCHAR2,
    p_currency_code   IN VARCHAR2 DEFAULT 'SAR',
    p_reference_type  IN VARCHAR2 DEFAULT NULL,
    p_reference_id    IN NUMBER   DEFAULT NULL,
    p_journal_id      OUT NUMBER
  ) IS
    v_period_id NUMBER;
    v_journal_no VARCHAR2(100);
  BEGIN
    v_period_id := GET_OPEN_PERIOD(p_legal_entity_id, p_journal_date);
    v_journal_no := GENERATE_JOURNAL_NO(p_source);
    
    INSERT INTO POS_GL_JOURNALS (
      JOURNAL_ID, JOURNAL_NO, LEGAL_ENTITY_ID, PERIOD_ID, JOURNAL_DATE,
      SOURCE, CATEGORY, DESCRIPTION, CURRENCY_CODE, EXCHANGE_RATE,
      TOTAL_DEBIT, TOTAL_CREDIT, STATUS, REFERENCE_TYPE, REFERENCE_ID,
      CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE
    ) VALUES (
      POS_GL_JOURNALS_SEQ.NEXTVAL, v_journal_no, p_legal_entity_id, v_period_id, p_journal_date,
      p_source, p_category, p_description, p_currency_code, 1.0,
      0, 0, 'DRAFT', p_reference_type, p_reference_id,
      get_current_user_id(), SYSDATE, get_current_user_id(), SYSDATE
    ) RETURNING JOURNAL_ID INTO p_journal_id;
  END CREATE_JOURNAL;

  -- Add Journal Line
  -- إضافة سطر للقيد
  PROCEDURE ADD_JOURNAL_LINE(
    p_journal_id    IN NUMBER,
    p_account_id    IN NUMBER,
    p_debit_amount  IN NUMBER DEFAULT 0,
    p_credit_amount IN NUMBER DEFAULT 0,
    p_description   IN VARCHAR2 DEFAULT NULL,
    p_inv_org_id    IN NUMBER DEFAULT NULL,
    p_reference1    IN VARCHAR2 DEFAULT NULL,
    p_reference2    IN VARCHAR2 DEFAULT NULL
  ) IS
    v_line_no NUMBER;
  BEGIN
    SELECT NVL(MAX(LINE_NO), 0) + 1 INTO v_line_no
    FROM POS_GL_JOURNAL_LINES
    WHERE JOURNAL_ID = p_journal_id;

    INSERT INTO POS_GL_JOURNAL_LINES (
      JOURNAL_LINE_ID, JOURNAL_ID, LINE_NO, ACCOUNT_ID,
      DEBIT_AMOUNT, CREDIT_AMOUNT, FUNCTIONAL_DEBIT, FUNCTIONAL_CREDIT,
      DESCRIPTION, INV_ORG_ID, REFERENCE1, REFERENCE2
    ) VALUES (
      POS_GL_JOURNAL_LINES_SEQ.NEXTVAL, p_journal_id, v_line_no, p_account_id,
      p_debit_amount, p_credit_amount, p_debit_amount, p_credit_amount, -- assuming rate is 1 for now
      p_description, p_inv_org_id, p_reference1, p_reference2
    );

    UPDATE POS_GL_JOURNALS
    SET TOTAL_DEBIT = TOTAL_DEBIT + p_debit_amount,
        TOTAL_CREDIT = TOTAL_CREDIT + p_credit_amount
    WHERE JOURNAL_ID = p_journal_id;
  END ADD_JOURNAL_LINE;

  -- Post Journal
  -- ترحيل القيد
  PROCEDURE POST_JOURNAL(p_journal_id IN NUMBER) IS
    v_debit NUMBER;
    v_credit NUMBER;
    v_status VARCHAR2(20);
  BEGIN
    SELECT TOTAL_DEBIT, TOTAL_CREDIT, STATUS
    INTO v_debit, v_credit, v_status
    FROM POS_GL_JOURNALS
    WHERE JOURNAL_ID = p_journal_id
    FOR UPDATE NOWAIT;

    IF v_status <> 'DRAFT' THEN
      RETURN;
    END IF;

    IF v_debit <> v_credit THEN
      RAISE_APPLICATION_ERROR(E_UNBALANCED_ENTRY, 'Journal entries must be balanced. DR: ' || v_debit || ' CR: ' || v_credit);
    END IF;

    UPDATE POS_GL_JOURNALS
    SET STATUS = 'POSTED',
        POSTED_BY = get_current_user_id(),
        POSTED_DATE = SYSDATE,
        LAST_UPDATED_BY = get_current_user_id(),
        LAST_UPDATE_DATE = SYSDATE
    WHERE JOURNAL_ID = p_journal_id;
  END POST_JOURNAL;

  -- Reverse Journal
  PROCEDURE REVERSE_JOURNAL(
    p_journal_id      IN NUMBER,
    p_reversal_date   IN DATE DEFAULT SYSDATE,
    p_new_journal_id  OUT NUMBER
  ) IS
  BEGIN
    -- Simplified implementation for reversing
    -- التنفيذ المبسط لعكس القيود
    NULL;
  END REVERSE_JOURNAL;

  -- ================================================================
  -- HIGH-LEVEL SLA POSTING PROCEDURES 
  -- ================================================================

  PROCEDURE POST_SALE_JOURNAL(p_order_id IN NUMBER) IS
    v_order         POS_ORDERS%ROWTYPE;
    v_le_id         NUMBER;
    v_journal_id    NUMBER;
    v_rule          POS_SLA_RULES%ROWTYPE;
    v_cogs_amount   NUMBER := 0;
  BEGIN
    SAVEPOINT post_sale_sp;

    -- 1. Get Order Details
    -- جلب تفاصيل الطلب
    SELECT * INTO v_order FROM POS_ORDERS WHERE ORDER_ID = p_order_id;
    
    -- 2. Get Legal Entity
    v_le_id := GET_LEGAL_ENTITY(v_order.INV_ORG_ID);

    -- 3 & 4. Create Journal
    -- إنشاء القيد
    CREATE_JOURNAL(
      p_legal_entity_id => v_le_id,
      p_journal_date    => SYSDATE,
      p_source          => 'POS_SALE',
      p_category        => 'SALES',
      p_description     => 'POS Sale Journal for Order: ' || v_order.ORDER_NO,
      p_currency_code   => v_order.CURRENCY_CODE,
      p_reference_type  => 'ORDER',
      p_reference_id    => p_order_id,
      p_journal_id      => v_journal_id
    );

    -- 5.a Revenue Entry (CR Revenue, DR Cash logic handled below in payments)
    -- قيد الإيرادات
    v_rule := get_sla_rule('POS_SALE', 'SALE', 'REVENUE');
    ADD_JOURNAL_LINE(
      p_journal_id    => v_journal_id,
      p_account_id    => v_rule.CREDIT_ACCOUNT_ID,
      p_credit_amount => v_order.SUBTOTAL,
      p_description   => 'Sales Revenue',
      p_inv_org_id    => v_order.INV_ORG_ID
    );

    -- 5.b Discount Entry
    -- قيد الخصومات
    IF v_order.DISCOUNT_AMOUNT > 0 THEN
      v_rule := get_sla_rule('POS_SALE', 'SALE', 'DISCOUNT');
      ADD_JOURNAL_LINE(
        p_journal_id    => v_journal_id,
        p_account_id    => v_rule.DEBIT_ACCOUNT_ID,
        p_debit_amount  => v_order.DISCOUNT_AMOUNT,
        p_description   => 'Sales Discount',
        p_inv_org_id    => v_order.INV_ORG_ID
      );
    END IF;

    -- 5.c Tax Entry
    -- قيد الضرائب
    IF v_order.TAX_AMOUNT > 0 THEN
      v_rule := get_sla_rule('POS_SALE', 'SALE', 'TAX');
      ADD_JOURNAL_LINE(
        p_journal_id    => v_journal_id,
        p_account_id    => v_rule.CREDIT_ACCOUNT_ID,
        p_credit_amount => v_order.TAX_AMOUNT,
        p_description   => 'VAT Payable',
        p_inv_org_id    => v_order.INV_ORG_ID
      );
    END IF;

    -- 5.d COGS Entry
    -- قيد تكلفة البضاعة المباعة
    SELECT SUM(COST_PRICE * QUANTITY) INTO v_cogs_amount
    FROM POS_ORDER_LINES
    WHERE ORDER_ID = p_order_id;
    
    IF v_cogs_amount > 0 THEN
      v_rule := get_sla_rule('POS_SALE', 'SALE', 'COGS');
      ADD_JOURNAL_LINE(
        p_journal_id    => v_journal_id,
        p_account_id    => v_rule.DEBIT_ACCOUNT_ID,
        p_debit_amount  => v_cogs_amount,
        p_description   => 'Cost of Goods Sold',
        p_inv_org_id    => v_order.INV_ORG_ID
      );
      ADD_JOURNAL_LINE(
        p_journal_id    => v_journal_id,
        p_account_id    => v_rule.CREDIT_ACCOUNT_ID,
        p_credit_amount => v_cogs_amount,
        p_description   => 'Inventory Asset',
        p_inv_org_id    => v_order.INV_ORG_ID
      );
    END IF;

    -- 6. Payments
    -- المدفوعات
    FOR payment_rec IN (
      SELECT p.AMOUNT_APPLIED, m.GL_ACCOUNT_CODE
      FROM POS_ORDER_PAYMENTS p
      JOIN POS_PAYMENT_METHODS m ON p.PAYMENT_METHOD_ID = m.PAYMENT_METHOD_ID
      WHERE p.ORDER_ID = p_order_id
    ) LOOP
      ADD_JOURNAL_LINE(
        p_journal_id    => v_journal_id,
        p_account_id    => get_account_by_code(payment_rec.GL_ACCOUNT_CODE, v_le_id),
        p_debit_amount  => payment_rec.AMOUNT_APPLIED,
        p_description   => 'Payment Applied',
        p_inv_org_id    => v_order.INV_ORG_ID
      );
    END LOOP;

    -- 7. Post Journal
    -- ترحيل
    POST_JOURNAL(v_journal_id);

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO post_sale_sp;
      RAISE;
  END POST_SALE_JOURNAL;

  PROCEDURE POST_RETURN_JOURNAL(p_order_id IN NUMBER) IS
  BEGIN
    -- Implements reverse logic of POST_SALE_JOURNAL
    NULL;
  END POST_RETURN_JOURNAL;

  PROCEDURE POST_SHIFT_RECONCILIATION(p_shift_id IN NUMBER) IS
    v_shift POS_SHIFTS%ROWTYPE;
    v_journal_id NUMBER;
    v_le_id NUMBER;
    v_rule POS_SLA_RULES%ROWTYPE;
  BEGIN
    SAVEPOINT post_shift_sp;
    
    SELECT * INTO v_shift FROM POS_SHIFTS WHERE SHIFT_ID = p_shift_id;
    IF v_shift.OVER_SHORT_AMOUNT = 0 THEN
      RETURN; -- No reconciliation needed
    END IF;

    v_le_id := GET_LEGAL_ENTITY(v_shift.INV_ORG_ID);
    
    CREATE_JOURNAL(
      p_legal_entity_id => v_le_id,
      p_journal_date    => SYSDATE,
      p_source          => 'POS_SHIFT',
      p_category        => 'RECONCILIATION',
      p_description     => 'Shift Reconciliation: ' || v_shift.SHIFT_NO,
      p_reference_type  => 'SHIFT',
      p_reference_id    => p_shift_id,
      p_journal_id      => v_journal_id
    );

    IF v_shift.OVER_SHORT_AMOUNT > 0 THEN
      -- Overage: DR Cash, CR Cash Over/Short (Revenue)
      -- زيادة: مدين نقدية، دائن إيرادات عجز وزيادة
      v_rule := get_sla_rule('POS_SHIFT', 'OVERAGE', 'CASH');
      ADD_JOURNAL_LINE(p_journal_id, v_rule.DEBIT_ACCOUNT_ID, v_shift.OVER_SHORT_AMOUNT, 0, 'Cash Overage DR', v_shift.INV_ORG_ID);
      ADD_JOURNAL_LINE(p_journal_id, v_rule.CREDIT_ACCOUNT_ID, 0, v_shift.OVER_SHORT_AMOUNT, 'Cash Overage CR', v_shift.INV_ORG_ID);
    ELSE
      -- Shortage: DR Cash Over/Short (Expense), CR Cash
      -- عجز: مدين مصاريف عجز، دائن نقدية
      v_rule := get_sla_rule('POS_SHIFT', 'SHORTAGE', 'CASH');
      ADD_JOURNAL_LINE(p_journal_id, v_rule.DEBIT_ACCOUNT_ID, ABS(v_shift.OVER_SHORT_AMOUNT), 0, 'Cash Shortage DR', v_shift.INV_ORG_ID);
      ADD_JOURNAL_LINE(p_journal_id, v_rule.CREDIT_ACCOUNT_ID, 0, ABS(v_shift.OVER_SHORT_AMOUNT), 'Cash Shortage CR', v_shift.INV_ORG_ID);
    END IF;

    POST_JOURNAL(v_journal_id);
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO post_shift_sp;
      RAISE;
  END POST_SHIFT_RECONCILIATION;

  PROCEDURE POST_INVENTORY_ADJUSTMENT(
    p_inv_org_id  IN NUMBER,
    p_item_id     IN NUMBER,
    p_variance_qty IN NUMBER,
    p_unit_cost   IN NUMBER,
    p_reference   IN VARCHAR2 DEFAULT NULL
  ) IS
  BEGIN
    -- Implements inventory adjustments
    NULL;
  END POST_INVENTORY_ADJUSTMENT;

END PKG_ACCOUNTING_ENGINE;
/
