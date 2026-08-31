CREATE OR REPLACE PACKAGE PKG_TAX_ENGINE AS
-- ============================================================================
-- Package: PKG_TAX_ENGINE
-- Purpose: Dynamic multi-tier tax evaluation, exemptions, and tax line generation
-- ============================================================================

  -- Record type for tax calculation result
  TYPE t_tax_result IS RECORD (
    tax_rate_id     NUMBER,
    tax_code        VARCHAR2(30),
    tax_percent     NUMBER(7,4),
    tax_amount      NUMBER(18,4),
    taxable_amount  NUMBER(18,4),
    is_inclusive    CHAR(1),
    is_exempt       CHAR(1),
    is_recoverable  CHAR(1)
  );
  TYPE t_tax_result_tbl IS TABLE OF t_tax_result INDEX BY PLS_INTEGER;

  -- Determine applicable tax rate for an item based on rule matrix
  -- Evaluates rules by priority: specific customer > item > category > org > legal entity > default
  FUNCTION DETERMINE_TAX_RATE(
    p_item_id         IN NUMBER,
    p_category_id     IN NUMBER DEFAULT NULL,
    p_customer_id     IN NUMBER DEFAULT NULL,
    p_customer_type   IN VARCHAR2 DEFAULT NULL,
    p_inv_org_id      IN NUMBER DEFAULT NULL,
    p_legal_entity_id IN NUMBER DEFAULT NULL,
    p_transaction_date IN DATE DEFAULT SYSDATE
  ) RETURN t_tax_result;

  -- Calculate tax for a single order line and return result
  FUNCTION CALCULATE_LINE_TAX(
    p_order_line_id IN NUMBER,
    p_taxable_amount IN NUMBER,
    p_item_id       IN NUMBER,
    p_category_id   IN NUMBER DEFAULT NULL,
    p_customer_id   IN NUMBER DEFAULT NULL,
    p_customer_type IN VARCHAR2 DEFAULT NULL,
    p_inv_org_id    IN NUMBER DEFAULT NULL,
    p_legal_entity_id IN NUMBER DEFAULT NULL
  ) RETURN t_tax_result;

  -- Calculate and write tax lines for ALL active lines in an order
  PROCEDURE CALCULATE_ORDER_TAX(
    p_order_id IN NUMBER
  );

  -- Check if a customer has a valid tax exemption for a given tax type
  FUNCTION IS_CUSTOMER_EXEMPT(
    p_customer_id IN NUMBER,
    p_tax_type_id IN NUMBER,
    p_check_date  IN DATE DEFAULT SYSDATE
  ) RETURN BOOLEAN;

  -- Check if an item/category has a tax exemption
  FUNCTION IS_ITEM_EXEMPT(
    p_item_id     IN NUMBER,
    p_category_id IN NUMBER,
    p_tax_type_id IN NUMBER,
    p_check_date  IN DATE DEFAULT SYSDATE
  ) RETURN BOOLEAN;

END PKG_TAX_ENGINE;
/
