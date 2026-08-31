CREATE OR REPLACE PACKAGE PKG_ACCOUNTING_ENGINE AS
-- ============================================================================
-- Package: PKG_ACCOUNTING_ENGINE
-- Purpose: Subledger Accounting (SLA) - Automated GL journal generation
--          from POS transactions (sales, returns, shifts, inventory, AR, AP)
-- الغرض: محرك المحاسبة الفرعية - إنشاء القيود المحاسبية التلقائية
-- ============================================================================

  E_PERIOD_CLOSED    CONSTANT NUMBER := -20301;
  E_UNBALANCED_ENTRY CONSTANT NUMBER := -20302;
  E_ACCOUNT_INACTIVE CONSTANT NUMBER := -20303;
  E_NO_SLA_RULE      CONSTANT NUMBER := -20304;

  -- Generate a unique journal number: JNL-{SOURCE}-{YYYYMMDD}-{SEQ}
  -- إنشاء رقم قيد فريد
  FUNCTION GENERATE_JOURNAL_NO(p_source IN VARCHAR2) RETURN VARCHAR2;

  -- Get the open accounting period for a given date and legal entity
  -- الحصول على الفترة المحاسبية المفتوحة
  FUNCTION GET_OPEN_PERIOD(
    p_legal_entity_id IN NUMBER,
    p_journal_date    IN DATE DEFAULT SYSDATE
  ) RETURN NUMBER;

  -- Get the legal entity for an inventory org
  -- الحصول على الكيان القانوني لفرع المخزون
  FUNCTION GET_LEGAL_ENTITY(p_inv_org_id IN NUMBER) RETURN NUMBER;

  -- Create a complete GL journal with balanced debit/credit lines
  -- إنشاء قيد يومية رئيسي
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
  );

  -- Add a debit or credit line to an existing journal
  -- إضافة سطر مدين أو دائن للقيد
  PROCEDURE ADD_JOURNAL_LINE(
    p_journal_id    IN NUMBER,
    p_account_id    IN NUMBER,
    p_debit_amount  IN NUMBER DEFAULT 0,
    p_credit_amount IN NUMBER DEFAULT 0,
    p_description   IN VARCHAR2 DEFAULT NULL,
    p_inv_org_id    IN NUMBER DEFAULT NULL,
    p_reference1    IN VARCHAR2 DEFAULT NULL,
    p_reference2    IN VARCHAR2 DEFAULT NULL
  );

  -- Validate and post a journal (set status to POSTED)
  -- ترحيل القيد بعد التحقق من التوازن
  PROCEDURE POST_JOURNAL(p_journal_id IN NUMBER);

  -- Reverse a posted journal (create reversing entry)
  -- عكس القيد المرحل
  PROCEDURE REVERSE_JOURNAL(
    p_journal_id      IN NUMBER,
    p_reversal_date   IN DATE DEFAULT SYSDATE,
    p_new_journal_id  OUT NUMBER
  );

  -- ================================================================
  -- HIGH-LEVEL SLA POSTING PROCEDURES (called by other packages)
  -- الإجراءات الرئيسية لترحيل الحركات
  -- ================================================================

  -- Post all accounting entries for a completed POS sale
  -- ترحيل قيود عملية البيع المكتملة
  PROCEDURE POST_SALE_JOURNAL(p_order_id IN NUMBER);

  -- Post accounting entries for a POS return/refund
  -- ترحيل قيود عملية الاسترجاع
  PROCEDURE POST_RETURN_JOURNAL(p_order_id IN NUMBER);

  -- Post shift reconciliation journal (over/short)
  -- ترحيل تسوية الوردية (عجز/زيادة)
  PROCEDURE POST_SHIFT_RECONCILIATION(p_shift_id IN NUMBER);

  -- Post inventory adjustment journal (cycle count variance, write-off)
  -- ترحيل تسويات المخزون
  PROCEDURE POST_INVENTORY_ADJUSTMENT(
    p_inv_org_id  IN NUMBER,
    p_item_id     IN NUMBER,
    p_variance_qty IN NUMBER,
    p_unit_cost   IN NUMBER,
    p_reference   IN VARCHAR2 DEFAULT NULL
  );

END PKG_ACCOUNTING_ENGINE;
/
