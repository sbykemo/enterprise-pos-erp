CREATE OR REPLACE PACKAGE BODY PKG_POS_CORE AS
-- ============================================================================
-- Package: PKG_POS_CORE
-- Purpose: Core POS Order Engine - Order lifecycle, pricing, payment settlement
-- ============================================================================

  -- ==========================================
  -- PRIVATE HELPER FUNCTIONS
  -- ==========================================

  FUNCTION get_current_user_id RETURN NUMBER IS
  BEGIN
    RETURN NVL(SYS_CONTEXT('POS_CTX', 'APP_USER_ID'), -1);
  END get_current_user_id;

  PROCEDURE validate_shift_open(p_shift_id IN NUMBER) IS
    v_status VARCHAR2(30);
  BEGIN
    SELECT SHIFT_STATUS INTO v_status
    FROM POS_SHIFTS
    WHERE SHIFT_ID = p_shift_id;
    
    IF v_status != 'OPEN' THEN
      RAISE_APPLICATION_ERROR(E_SHIFT_NOT_OPEN, 'Shift is not open.');
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(E_SHIFT_NOT_OPEN, 'Shift not found.');
  END validate_shift_open;

  PROCEDURE validate_order_draft(p_order_id IN NUMBER) IS
    v_status VARCHAR2(30);
  BEGIN
    SELECT ORDER_STATUS INTO v_status
    FROM POS_ORDERS
    WHERE ORDER_ID = p_order_id;
    
    IF v_status != 'DRAFT' THEN
      RAISE_APPLICATION_ERROR(E_ORDER_NOT_DRAFT, 'Order is not in DRAFT status.');
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(E_ORDER_NOT_DRAFT, 'Order not found.');
  END validate_order_draft;

  FUNCTION get_next_line_no(p_order_id IN NUMBER) RETURN NUMBER IS
    v_next_no NUMBER;
  BEGIN
    SELECT NVL(MAX(LINE_NO), 0) + 1 INTO v_next_no
    FROM POS_ORDER_LINES
    WHERE ORDER_ID = p_order_id;
    RETURN v_next_no;
  END get_next_line_no;

  FUNCTION get_item_cost(p_item_id IN NUMBER, p_variant_id IN NUMBER, p_inv_org_id IN NUMBER) RETURN NUMBER IS
    v_cost NUMBER := 0;
  BEGIN
    IF p_variant_id IS NOT NULL THEN
      SELECT COST_PRICE INTO v_cost
      FROM POS_ITEM_VARIANTS
      WHERE VARIANT_ID = p_variant_id AND ITEM_ID = p_item_id;
    ELSE
      SELECT COST_PRICE INTO v_cost
      FROM POS_ITEMS
      WHERE ITEM_ID = p_item_id;
    END IF;
    RETURN NVL(v_cost, 0);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 0;
  END get_item_cost;

  -- ==========================================
  -- PUBLIC PROCEDURES & FUNCTIONS
  -- ==========================================

  FUNCTION GENERATE_ORDER_NO(p_inv_org_id IN NUMBER) RETURN VARCHAR2 IS
    v_org_code VARCHAR2(10) := 'ORG';
    v_seq NUMBER;
    v_date_str VARCHAR2(8) := TO_CHAR(SYSDATE, 'YYYYMMDD');
    v_order_no VARCHAR2(50);
  BEGIN
    -- Fallback ORG code (In reality, fetch from POS_INVENTORY_ORGS if exists)
    BEGIN
      -- Assume POS_INVENTORY_ORGS has ORG_CODE, otherwise default
      -- SELECT ORG_CODE INTO v_org_code FROM POS_INVENTORY_ORGS WHERE INV_ORG_ID = p_inv_org_id;
      v_org_code := 'ORG' || p_inv_org_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN NULL;
    END;

    -- Get sequence count for the day
    SELECT COUNT(*) + 1 INTO v_seq
    FROM POS_ORDERS
    WHERE INV_ORG_ID = p_inv_org_id
      AND TRUNC(ORDER_DATETIME) = TRUNC(SYSDATE);

    v_order_no := v_org_code || '-' || v_date_str || '-' || LPAD(v_seq, 6, '0');
    RETURN v_order_no;
  END GENERATE_ORDER_NO;

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
  ) IS
    v_price_list_id NUMBER := p_price_list_id;
    v_table_status VARCHAR2(30);
  BEGIN
    SAVEPOINT create_order_sp;

    -- Validations
    validate_shift_open(p_shift_id);
    
    -- Terminals check (basic logic placeholder)
    
    -- Resolve Price List
    IF v_price_list_id IS NULL THEN
      BEGIN
        SELECT DEFAULT_PRICE_LIST_ID INTO v_price_list_id
        FROM POS_POS_TERMINALS
        WHERE TERMINAL_ID = p_terminal_id;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL; -- handle or assign standard
      END;
    END IF;

    -- Table management
    IF p_table_id IS NOT NULL THEN
      SELECT TABLE_STATUS INTO v_table_status
      FROM POS_TABLES
      WHERE TABLE_ID = p_table_id FOR UPDATE NOWAIT;
      
      IF v_table_status != 'AVAILABLE' THEN
        RAISE_APPLICATION_ERROR(-20201, 'Table is not available.');
      END IF;
    END IF;

    -- Sequence and Order No
    -- Assume sequence exists: pos_orders_seq
    -- SELECT pos_orders_seq.NEXTVAL INTO p_order_id FROM DUAL; 
    -- Faking sequence for compile without real DB
    p_order_id := 1000 + DBMS_RANDOM.VALUE(1,1000000); 
    p_order_no := GENERATE_ORDER_NO(p_inv_org_id);

    INSERT INTO POS_ORDERS (
      ORDER_ID, ORDER_NO, INV_ORG_ID, TERMINAL_ID, SHIFT_ID, CASHIER_USER_ID, 
      CUSTOMER_ID, TABLE_ID, ORDER_TYPE, ORDER_STATUS, SECTOR_TYPE, 
      ORDER_DATETIME, CURRENCY_CODE, PRICE_LIST_ID, CREATED_BY, CREATION_DATE,
      SUBTOTAL, DISCOUNT_AMOUNT, TAX_AMOUNT, ROUNDING_AMOUNT, TOTAL_AMOUNT, PAID_AMOUNT
    ) VALUES (
      p_order_id, p_order_no, p_inv_org_id, p_terminal_id, p_shift_id, p_cashier_user_id,
      p_customer_id, p_table_id, p_order_type, 'DRAFT', p_sector_type, 
      SYSDATE, p_currency_code, v_price_list_id, get_current_user_id(), SYSDATE,
      0, 0, 0, 0, 0, 0
    );

    IF p_table_id IS NOT NULL THEN
      UPDATE POS_TABLES 
      SET TABLE_STATUS = 'OCCUPIED', CURRENT_ORDER_ID = p_order_id
      WHERE TABLE_ID = p_table_id;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO create_order_sp;
      RAISE;
  END CREATE_ORDER;

  PROCEDURE ADD_ORDER_LINE(
    p_order_id    IN  NUMBER,
    p_item_id     IN  NUMBER,
    p_variant_id  IN  NUMBER   DEFAULT NULL,
    p_quantity    IN  NUMBER   DEFAULT 1,
    p_uom_code    IN  VARCHAR2 DEFAULT NULL,
    p_unit_price  IN  NUMBER   DEFAULT NULL,
    p_discount_pct IN NUMBER   DEFAULT 0,
    p_line_notes  IN  VARCHAR2 DEFAULT NULL,
    p_line_id     OUT NUMBER
  ) IS
    v_inv_org_id NUMBER;
    v_price_list_id NUMBER;
    v_has_variants VARCHAR2(1);
    v_primary_uom VARCHAR2(30);
    v_min_sale_price NUMBER;
    v_is_open_price VARCHAR2(1);
    v_actual_uom VARCHAR2(30);
    v_actual_price NUMBER;
    v_line_subtotal NUMBER;
    v_discount_amt NUMBER;
    v_cost NUMBER;
  BEGIN
    SAVEPOINT add_line_sp;

    validate_order_draft(p_order_id);

    SELECT INV_ORG_ID, PRICE_LIST_ID INTO v_inv_org_id, v_price_list_id
    FROM POS_ORDERS WHERE ORDER_ID = p_order_id;

    -- Item checks
    SELECT HAS_VARIANTS, PRIMARY_UOM_CODE, MIN_SALE_PRICE, IS_OPEN_PRICE
    INTO v_has_variants, v_primary_uom, v_min_sale_price, v_is_open_price
    FROM POS_ITEMS WHERE ITEM_ID = p_item_id AND IS_ACTIVE = 'Y';

    IF v_has_variants = 'Y' AND p_variant_id IS NULL THEN
      RAISE_APPLICATION_ERROR(-20202, 'Item requires variant.');
    END IF;

    -- UOM resolution
    v_actual_uom := NVL(p_uom_code, v_primary_uom);

    -- Price resolution
    IF p_unit_price IS NULL THEN
      v_actual_price := GET_ITEM_PRICE(p_item_id, p_variant_id, v_price_list_id, v_actual_uom);
    ELSE
      v_actual_price := p_unit_price;
    END IF;

    IF v_is_open_price != 'Y' AND v_actual_price < NVL(v_min_sale_price, 0) THEN
      RAISE_APPLICATION_ERROR(E_PRICE_BELOW_MIN, 'Price is below minimum allowed.');
    END IF;

    -- Calc
    v_line_subtotal := p_quantity * v_actual_price;
    v_discount_amt := v_line_subtotal * (NVL(p_discount_pct, 0) / 100);
    v_cost := get_item_cost(p_item_id, p_variant_id, v_inv_org_id);

    p_line_id := 1000 + DBMS_RANDOM.VALUE(1,1000000); -- Fake sequence

    INSERT INTO POS_ORDER_LINES (
      ORDER_LINE_ID, ORDER_ID, LINE_NO, ITEM_ID, VARIANT_ID, UOM_CODE, QUANTITY,
      UNIT_PRICE, DISCOUNT_PERCENT, DISCOUNT_AMOUNT, LINE_SUBTOTAL, COST_PRICE,
      LINE_TYPE, LINE_STATUS, LINE_NOTES
    ) VALUES (
      p_line_id, p_order_id, get_next_line_no(p_order_id), p_item_id, p_variant_id, v_actual_uom, p_quantity,
      v_actual_price, p_discount_pct, v_discount_amt, (v_line_subtotal - v_discount_amt), v_cost,
      'REGULAR', 'ACTIVE', p_line_notes
    );

    CALCULATE_ORDER_TOTALS(p_order_id);

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO add_line_sp;
      RAISE;
  END ADD_ORDER_LINE;

  PROCEDURE UPDATE_LINE_QTY(
    p_order_line_id IN NUMBER,
    p_new_quantity  IN NUMBER
  ) IS
    v_order_id NUMBER;
    v_unit_price NUMBER;
    v_disc_pct NUMBER;
  BEGIN
    SAVEPOINT update_qty_sp;

    SELECT ORDER_ID, UNIT_PRICE, DISCOUNT_PERCENT INTO v_order_id, v_unit_price, v_disc_pct
    FROM POS_ORDER_LINES WHERE ORDER_LINE_ID = p_order_line_id AND LINE_STATUS = 'ACTIVE';

    validate_order_draft(v_order_id);

    UPDATE POS_ORDER_LINES
    SET QUANTITY = p_new_quantity,
        LINE_SUBTOTAL = (p_new_quantity * v_unit_price) - ((p_new_quantity * v_unit_price) * (v_disc_pct/100)),
        DISCOUNT_AMOUNT = ((p_new_quantity * v_unit_price) * (v_disc_pct/100))
    WHERE ORDER_LINE_ID = p_order_line_id;

    CALCULATE_ORDER_TOTALS(v_order_id);

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO update_qty_sp;
      RAISE;
  END UPDATE_LINE_QTY;

  PROCEDURE VOID_ORDER_LINE(
    p_order_line_id IN NUMBER
  ) IS
    v_order_id NUMBER;
    v_status VARCHAR2(30);
  BEGIN
    SAVEPOINT void_line_sp;

    SELECT ORDER_ID, LINE_STATUS INTO v_order_id, v_status
    FROM POS_ORDER_LINES WHERE ORDER_LINE_ID = p_order_line_id FOR UPDATE NOWAIT;

    IF v_status = 'VOIDED' THEN
      RAISE_APPLICATION_ERROR(E_ALREADY_VOIDED, 'Line already voided.');
    END IF;

    validate_order_draft(v_order_id);

    UPDATE POS_ORDER_LINES
    SET LINE_STATUS = 'VOIDED',
        QUANTITY = 0,
        LINE_SUBTOTAL = 0,
        TAX_AMOUNT = 0,
        DISCOUNT_AMOUNT = 0
    WHERE ORDER_LINE_ID = p_order_line_id;

    CALCULATE_ORDER_TOTALS(v_order_id);

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO void_line_sp;
      RAISE;
  END VOID_ORDER_LINE;

  PROCEDURE APPLY_ORDER_DISCOUNT(
    p_order_id        IN NUMBER,
    p_discount_type   IN VARCHAR2,  
    p_discount_value  IN NUMBER
  ) IS
    v_subtotal NUMBER;
    v_disc NUMBER := 0;
  BEGIN
    SAVEPOINT apply_disc_sp;
    validate_order_draft(p_order_id);

    SELECT NVL(SUM(LINE_SUBTOTAL), 0) INTO v_subtotal
    FROM POS_ORDER_LINES WHERE ORDER_ID = p_order_id AND LINE_STATUS = 'ACTIVE';

    IF p_discount_type = 'PERCENT' THEN
      v_disc := v_subtotal * (p_discount_value / 100);
    ELSE
      v_disc := p_discount_value;
    END IF;

    UPDATE POS_ORDERS
    SET DISCOUNT_AMOUNT = v_disc
    WHERE ORDER_ID = p_order_id;

    CALCULATE_ORDER_TOTALS(p_order_id);
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO apply_disc_sp;
      RAISE;
  END APPLY_ORDER_DISCOUNT;

  PROCEDURE APPLY_COUPON(
    p_order_id    IN NUMBER,
    p_coupon_code IN VARCHAR2
  ) IS
  BEGIN
    -- Simplified coupon logic
    NULL;
  END APPLY_COUPON;

  PROCEDURE CALCULATE_ORDER_TOTALS(
    p_order_id IN NUMBER
  ) IS
    v_subtotal NUMBER := 0;
    v_tax NUMBER := 0;
    v_hdr_disc NUMBER := 0;
    v_total NUMBER := 0;
    v_rounding NUMBER := 0;
  BEGIN
    SELECT NVL(SUM(LINE_SUBTOTAL), 0), NVL(SUM(TAX_AMOUNT), 0)
    INTO v_subtotal, v_tax
    FROM POS_ORDER_LINES
    WHERE ORDER_ID = p_order_id AND LINE_STATUS = 'ACTIVE';

    SELECT NVL(DISCOUNT_AMOUNT, 0) INTO v_hdr_disc
    FROM POS_ORDERS WHERE ORDER_ID = p_order_id;

    v_total := v_subtotal - v_hdr_disc + v_tax;
    
    -- Saudi Halala Rounding to 0.05
    v_rounding := ROUND(v_total / 0.05) * 0.05 - v_total;
    v_total := v_total + v_rounding;

    UPDATE POS_ORDERS
    SET SUBTOTAL = v_subtotal,
        TAX_AMOUNT = v_tax,
        ROUNDING_AMOUNT = v_rounding,
        TOTAL_AMOUNT = v_total
    WHERE ORDER_ID = p_order_id;

  END CALCULATE_ORDER_TOTALS;

  FUNCTION GET_ITEM_PRICE(
    p_item_id       IN NUMBER,
    p_variant_id    IN NUMBER DEFAULT NULL,
    p_price_list_id IN NUMBER,
    p_uom_code      IN VARCHAR2,
    p_order_date    IN DATE DEFAULT SYSDATE
  ) RETURN NUMBER IS
    v_price NUMBER;
    v_curr_list NUMBER := p_price_list_id;
  BEGIN
    WHILE v_curr_list IS NOT NULL LOOP
      BEGIN
        SELECT LIST_PRICE INTO v_price
        FROM POS_PRICE_LIST_LINES
        WHERE PRICE_LIST_ID = v_curr_list
          AND ITEM_ID = p_item_id
          AND (VARIANT_ID = p_variant_id OR (VARIANT_ID IS NULL AND p_variant_id IS NULL))
          AND UOM_CODE = p_uom_code;
        RETURN v_price;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          -- Check parent
          BEGIN
            SELECT PARENT_PRICE_LIST_ID INTO v_curr_list
            FROM POS_PRICE_LISTS
            WHERE PRICE_LIST_ID = v_curr_list;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_curr_list := NULL;
          END;
      END;
    END LOOP;
    
    RAISE_APPLICATION_ERROR(-20301, 'Price not found for item.');
  END GET_ITEM_PRICE;

  PROCEDURE ADD_PAYMENT(
    p_order_id          IN  NUMBER,
    p_payment_method_id IN  NUMBER,
    p_amount_tendered   IN  NUMBER,
    p_payment_reference IN  VARCHAR2 DEFAULT NULL,
    p_card_last4        IN  VARCHAR2 DEFAULT NULL,
    p_auth_code         IN  VARCHAR2 DEFAULT NULL,
    p_payment_id        OUT NUMBER
  ) IS
    v_status VARCHAR2(30);
    v_total NUMBER;
    v_paid NUMBER;
    v_rem NUMBER;
    v_applied NUMBER;
    v_change NUMBER := 0;
    v_is_change_app VARCHAR2(1);
  BEGIN
    SAVEPOINT add_pay_sp;

    SELECT ORDER_STATUS, TOTAL_AMOUNT, NVL(PAID_AMOUNT, 0)
    INTO v_status, v_total, v_paid
    FROM POS_ORDERS WHERE ORDER_ID = p_order_id FOR UPDATE NOWAIT;

    IF v_status NOT IN ('DRAFT', 'CONFIRMED') THEN
      RAISE_APPLICATION_ERROR(-20401, 'Order not ready for payment.');
    END IF;

    SELECT IS_CHANGE_APPLICABLE INTO v_is_change_app
    FROM POS_PAYMENT_METHODS WHERE PAYMENT_METHOD_ID = p_payment_method_id;

    v_rem := v_total - v_paid;
    
    IF p_amount_tendered > v_rem AND v_is_change_app = 'Y' THEN
      v_applied := v_rem;
      v_change := p_amount_tendered - v_rem;
    ELSE
      v_applied := LEAST(p_amount_tendered, v_rem);
      v_change := 0;
    END IF;

    p_payment_id := 2000 + DBMS_RANDOM.VALUE(1,1000000);

    INSERT INTO POS_ORDER_PAYMENTS (
      PAYMENT_ID, ORDER_ID, PAYMENT_METHOD_ID, AMOUNT_TENDERED, AMOUNT_APPLIED,
      CHANGE_GIVEN, PAYMENT_REFERENCE, CARD_LAST4, AUTHORIZATION_CODE, PAYMENT_DATETIME, STATUS
    ) VALUES (
      p_payment_id, p_order_id, p_payment_method_id, p_amount_tendered, v_applied,
      v_change, p_payment_reference, p_card_last4, p_auth_code, SYSDATE, 'APPROVED'
    );

    UPDATE POS_ORDERS
    SET PAID_AMOUNT = v_paid + v_applied,
        CHANGE_AMOUNT = NVL(CHANGE_AMOUNT, 0) + v_change,
        ORDER_STATUS = CASE WHEN (v_paid + v_applied) >= v_total THEN 'PAID' ELSE 'PARTIALLY_PAID' END
    WHERE ORDER_ID = p_order_id;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO add_pay_sp;
      RAISE;
  END ADD_PAYMENT;

  PROCEDURE SETTLE_ORDER(
    p_order_id IN NUMBER
  ) IS
    v_total NUMBER;
    v_paid NUMBER;
    v_shift_id NUMBER;
    v_tax NUMBER;
    v_disc NUMBER;
  BEGIN
    SAVEPOINT settle_order_sp;
    
    CALCULATE_ORDER_TOTALS(p_order_id);

    SELECT TOTAL_AMOUNT, NVL(PAID_AMOUNT,0), SHIFT_ID, TAX_AMOUNT, DISCOUNT_AMOUNT
    INTO v_total, v_paid, v_shift_id, v_tax, v_disc
    FROM POS_ORDERS WHERE ORDER_ID = p_order_id FOR UPDATE NOWAIT;

    IF v_paid < v_total THEN
      RAISE_APPLICATION_ERROR(E_PAYMENT_MISMATCH, 'Order not fully paid.');
    END IF;

    UPDATE POS_ORDERS
    SET ORDER_STATUS = 'PAID'
    WHERE ORDER_ID = p_order_id;

    -- External integrations placeholders
    BEGIN
      -- PKG_INV_ENGINE.TRANSACT_INVENTORY(p_order_id);
      NULL; -- called during settlement - will be fully implemented in those packages
    EXCEPTION WHEN OTHERS THEN NULL; END;
    
    BEGIN
      -- PKG_ACCOUNTING_ENGINE.POST_SALE_JOURNAL(p_order_id);
      NULL; -- called during settlement - will be fully implemented in those packages
    EXCEPTION WHEN OTHERS THEN NULL; END;

    UPDATE POS_SHIFTS
    SET TOTAL_SALES = NVL(TOTAL_SALES,0) + v_total,
        TOTAL_TAX = NVL(TOTAL_TAX,0) + v_tax,
        TOTAL_DISCOUNTS = NVL(TOTAL_DISCOUNTS,0) + v_disc
    WHERE SHIFT_ID = v_shift_id;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO settle_order_sp;
      RAISE;
  END SETTLE_ORDER;

  PROCEDURE VOID_ORDER(
    p_order_id IN NUMBER,
    p_void_reason IN VARCHAR2 DEFAULT NULL
  ) IS
    v_status VARCHAR2(30);
    v_shift NUMBER;
  BEGIN
    SAVEPOINT void_ord_sp;
    
    SELECT ORDER_STATUS, SHIFT_ID INTO v_status, v_shift
    FROM POS_ORDERS WHERE ORDER_ID = p_order_id FOR UPDATE NOWAIT;

    IF v_status NOT IN ('DRAFT', 'CONFIRMED') THEN
      RAISE_APPLICATION_ERROR(E_ORDER_NOT_DRAFT, 'Cannot void order in current status.');
    END IF;

    UPDATE POS_ORDER_LINES
    SET LINE_STATUS = 'VOIDED'
    WHERE ORDER_ID = p_order_id AND LINE_STATUS = 'ACTIVE';

    UPDATE POS_ORDERS
    SET ORDER_STATUS = 'VOIDED'
    WHERE ORDER_ID = p_order_id;

    UPDATE POS_SHIFTS
    SET TOTAL_VOIDS = NVL(TOTAL_VOIDS,0) + 1
    WHERE SHIFT_ID = v_shift;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO void_ord_sp;
      RAISE;
  END VOID_ORDER;

  PROCEDURE RETURN_ORDER(
    p_original_order_id IN NUMBER,
    p_return_line_ids   IN SYS.ODCINUMBERLIST DEFAULT NULL,
    p_return_order_id   OUT NUMBER
  ) IS
  BEGIN
    -- Simplified return
    NULL;
  END RETURN_ORDER;

  PROCEDURE HOLD_ORDER(p_order_id IN NUMBER) IS
  BEGIN
    SAVEPOINT hold_sp;
    validate_order_draft(p_order_id);
    UPDATE POS_ORDERS SET ORDER_STATUS = 'HOLD' WHERE ORDER_ID = p_order_id;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO hold_sp;
      RAISE;
  END HOLD_ORDER;

  PROCEDURE RECALL_ORDER(
    p_order_id    IN  NUMBER,
    p_new_shift_id IN NUMBER DEFAULT NULL
  ) IS
    v_status VARCHAR2(30);
  BEGIN
    SAVEPOINT recall_sp;
    SELECT ORDER_STATUS INTO v_status FROM POS_ORDERS WHERE ORDER_ID = p_order_id FOR UPDATE NOWAIT;
    IF v_status != 'HOLD' THEN RAISE_APPLICATION_ERROR(-20501, 'Not on hold'); END IF;
    UPDATE POS_ORDERS SET ORDER_STATUS = 'DRAFT' WHERE ORDER_ID = p_order_id;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO recall_sp;
      RAISE;
  END RECALL_ORDER;

END PKG_POS_CORE;
/
