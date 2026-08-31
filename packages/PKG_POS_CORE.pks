CREATE OR REPLACE PACKAGE PKG_POS_CORE AS
-- ============================================================================
-- Package: PKG_POS_CORE
-- Purpose: Core POS Order Engine - Order lifecycle, pricing, payment settlement
-- ============================================================================

  -- Custom exception numbers
  E_SHIFT_NOT_OPEN     CONSTANT NUMBER := -20101;
  E_ITEM_NOT_SELLABLE  CONSTANT NUMBER := -20102;
  E_INSUFFICIENT_STOCK CONSTANT NUMBER := -20103;
  E_PRICE_BELOW_MIN    CONSTANT NUMBER := -20104;
  E_ORDER_NOT_DRAFT    CONSTANT NUMBER := -20105;
  E_PAYMENT_MISMATCH   CONSTANT NUMBER := -20106;
  E_ALREADY_VOIDED     CONSTANT NUMBER := -20107;
  E_CREDIT_EXCEEDED    CONSTANT NUMBER := -20108;

  -- Order number generation format: ORG-YYYYMMDD-SEQNO (e.g., BR001-20240315-000042)
  FUNCTION GENERATE_ORDER_NO(p_inv_org_id IN NUMBER) RETURN VARCHAR2;

  -- Create a new order header in DRAFT status
  PROCEDURE CREATE_ORDER(
    p_inv_org_id     IN  NUMBER,
    p_terminal_id    IN  NUMBER,
    p_shift_id       IN  NUMBER,
    p_cashier_user_id IN NUMBER,
    p_order_type     IN  VARCHAR2 DEFAULT 'SALE',
    p_sector_type    IN  VARCHAR2 DEFAULT 'RETAIL',
    p_customer_id    IN  NUMBER   DEFAULT NULL,
    p_table_id       IN  NUMBER   DEFAULT NULL,
    p_currency_code  IN  VARCHAR2 DEFAULT 'SAR',
    p_price_list_id  IN  NUMBER   DEFAULT NULL,
    p_order_id       OUT NUMBER,
    p_order_no       OUT VARCHAR2
  );

  -- Add a line item to an existing DRAFT order
  -- Automatically resolves price from price list hierarchy
  PROCEDURE ADD_ORDER_LINE(
    p_order_id    IN  NUMBER,
    p_item_id     IN  NUMBER,
    p_variant_id  IN  NUMBER   DEFAULT NULL,
    p_quantity    IN  NUMBER   DEFAULT 1,
    p_uom_code    IN  VARCHAR2 DEFAULT NULL,
    p_unit_price  IN  NUMBER   DEFAULT NULL,  -- NULL = auto from price list
    p_discount_pct IN NUMBER   DEFAULT 0,
    p_line_notes  IN  VARCHAR2 DEFAULT NULL,
    p_line_id     OUT NUMBER
  );

  -- Update quantity on an existing order line
  PROCEDURE UPDATE_LINE_QTY(
    p_order_line_id IN NUMBER,
    p_new_quantity  IN NUMBER
  );

  -- Void (cancel) a single line item
  PROCEDURE VOID_ORDER_LINE(
    p_order_line_id IN NUMBER
  );

  -- Apply a header-level discount (% or fixed) to the order
  PROCEDURE APPLY_ORDER_DISCOUNT(
    p_order_id        IN NUMBER,
    p_discount_type   IN VARCHAR2,  -- 'PERCENT' or 'FIXED'
    p_discount_value  IN NUMBER
  );

  -- Apply a coupon code to the order
  PROCEDURE APPLY_COUPON(
    p_order_id    IN NUMBER,
    p_coupon_code IN VARCHAR2
  );

  -- Recalculate all order totals (subtotal, discount, tax, rounding, total)
  PROCEDURE CALCULATE_ORDER_TOTALS(
    p_order_id IN NUMBER
  );

  -- Resolve item price from price list hierarchy
  FUNCTION GET_ITEM_PRICE(
    p_item_id       IN NUMBER,
    p_variant_id    IN NUMBER DEFAULT NULL,
    p_price_list_id IN NUMBER,
    p_uom_code      IN VARCHAR2,
    p_order_date    IN DATE DEFAULT SYSDATE
  ) RETURN NUMBER;

  -- Record a payment against the order (supports split tender)
  PROCEDURE ADD_PAYMENT(
    p_order_id          IN  NUMBER,
    p_payment_method_id IN  NUMBER,
    p_amount_tendered   IN  NUMBER,
    p_payment_reference IN  VARCHAR2 DEFAULT NULL,
    p_card_last4        IN  VARCHAR2 DEFAULT NULL,
    p_auth_code         IN  VARCHAR2 DEFAULT NULL,
    p_payment_id        OUT NUMBER
  );

  -- Finalize and settle the order - validates full payment, triggers inventory and GL
  PROCEDURE SETTLE_ORDER(
    p_order_id IN NUMBER
  );

  -- Void an entire order (only DRAFT or CONFIRMED, not already PAID)
  PROCEDURE VOID_ORDER(
    p_order_id IN NUMBER,
    p_void_reason IN VARCHAR2 DEFAULT NULL
  );

  -- Create a return order referencing the original
  PROCEDURE RETURN_ORDER(
    p_original_order_id IN NUMBER,
    p_return_line_ids   IN SYS.ODCINUMBERLIST DEFAULT NULL, -- NULL = full return
    p_return_order_id   OUT NUMBER
  );

  -- Hold an order (park it) for later recall
  PROCEDURE HOLD_ORDER(p_order_id IN NUMBER);

  -- Recall a held order back to DRAFT for editing
  PROCEDURE RECALL_ORDER(
    p_order_id    IN  NUMBER,
    p_new_shift_id IN NUMBER DEFAULT NULL
  );

END PKG_POS_CORE;
/
