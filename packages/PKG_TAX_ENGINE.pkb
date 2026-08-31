CREATE OR REPLACE PACKAGE BODY PKG_TAX_ENGINE AS
-- ============================================================================
-- Package Body: PKG_TAX_ENGINE
-- ============================================================================

  FUNCTION IS_CUSTOMER_EXEMPT(
    p_customer_id IN NUMBER,
    p_tax_type_id IN NUMBER,
    p_check_date  IN DATE DEFAULT SYSDATE
  ) RETURN BOOLEAN IS
    v_count NUMBER;
  BEGIN
    IF p_customer_id IS NULL OR p_tax_type_id IS NULL THEN
      RETURN FALSE;
    END IF;

    SELECT COUNT(*)
    INTO v_count
    FROM POS_TAX_EXEMPTIONS
    WHERE CUSTOMER_ID = p_customer_id
      AND TAX_TYPE_ID = p_tax_type_id
      AND IS_ACTIVE = 'Y'
      AND VALID_FROM <= p_check_date
      AND (VALID_TO IS NULL OR VALID_TO >= p_check_date);
      
    RETURN (v_count > 0);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN FALSE;
  END IS_CUSTOMER_EXEMPT;

  FUNCTION IS_ITEM_EXEMPT(
    p_item_id     IN NUMBER,
    p_category_id IN NUMBER,
    p_tax_type_id IN NUMBER,
    p_check_date  IN DATE DEFAULT SYSDATE
  ) RETURN BOOLEAN IS
    v_count NUMBER;
  BEGIN
    IF (p_item_id IS NULL AND p_category_id IS NULL) OR p_tax_type_id IS NULL THEN
      RETURN FALSE;
    END IF;

    SELECT COUNT(*)
    INTO v_count
    FROM POS_TAX_EXEMPTIONS
    WHERE (ITEM_ID = p_item_id OR (CATEGORY_ID = p_category_id AND p_category_id IS NOT NULL))
      AND TAX_TYPE_ID = p_tax_type_id
      AND IS_ACTIVE = 'Y'
      AND VALID_FROM <= p_check_date
      AND (VALID_TO IS NULL OR VALID_TO >= p_check_date);
      
    RETURN (v_count > 0);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN FALSE;
  END IS_ITEM_EXEMPT;

  FUNCTION DETERMINE_TAX_RATE(
    p_item_id         IN NUMBER,
    p_category_id     IN NUMBER DEFAULT NULL,
    p_customer_id     IN NUMBER DEFAULT NULL,
    p_customer_type   IN VARCHAR2 DEFAULT NULL,
    p_inv_org_id      IN NUMBER DEFAULT NULL,
    p_legal_entity_id IN NUMBER DEFAULT NULL,
    p_transaction_date IN DATE DEFAULT SYSDATE
  ) RETURN t_tax_result IS
    v_result t_tax_result;
    v_tax_rate_id POS_TAX_RATES.TAX_RATE_ID%TYPE;
    v_rate_code   POS_TAX_RATES.RATE_CODE%TYPE;
    v_rate_percent POS_TAX_RATES.RATE_PERCENT%TYPE;
    v_is_inclusive CHAR(1) := 'N'; 
    v_is_exempt CHAR(1) := 'N';
    v_tax_type_id POS_TAX_TYPES.TAX_TYPE_ID%TYPE;
  BEGIN
    -- Initialize defaults
    v_result.tax_rate_id := NULL;
    v_result.tax_code := 'NONE';
    v_result.tax_percent := 0;
    v_result.is_exempt := 'N';
    v_result.is_inclusive := 'N';
    v_result.is_recoverable := 'Y';
    
    BEGIN
      -- Query POS_TAX_RULES joined with POS_TAX_RATES and POS_TAX_TYPES
      -- Filter by active, effective dates
      -- A NULL in a rule column means "matches all"
      SELECT r.TAX_RATE_ID, rt.RATE_CODE, rt.RATE_PERCENT, ty.TAX_TYPE_ID
      INTO v_tax_rate_id, v_rate_code, v_rate_percent, v_tax_type_id
      FROM POS_TAX_RULES r
      JOIN POS_TAX_RATES rt ON r.TAX_RATE_ID = rt.TAX_RATE_ID
      JOIN POS_TAX_TYPES ty ON rt.TAX_TYPE_ID = ty.TAX_TYPE_ID
      WHERE r.IS_ACTIVE = 'Y'
        AND rt.IS_ACTIVE = 'Y'
        AND ty.IS_ACTIVE = 'Y'
        AND rt.EFFECTIVE_FROM <= p_transaction_date
        AND (rt.EFFECTIVE_TO IS NULL OR rt.EFFECTIVE_TO >= p_transaction_date)
        AND (r.ITEM_ID IS NULL OR r.ITEM_ID = p_item_id)
        AND (r.CATEGORY_ID IS NULL OR r.CATEGORY_ID = p_category_id)
        AND (r.CUSTOMER_ID IS NULL OR r.CUSTOMER_ID = p_customer_id)
        AND (r.CUSTOMER_TYPE IS NULL OR r.CUSTOMER_TYPE = p_customer_type)
        AND (r.INV_ORG_ID IS NULL OR r.INV_ORG_ID = p_inv_org_id)
        AND (r.LEGAL_ENTITY_ID IS NULL OR r.LEGAL_ENTITY_ID = p_legal_entity_id)
      ORDER BY r.PRIORITY ASC
      FETCH FIRST 1 ROWS ONLY;
      
      -- Check exemptions
      IF v_tax_rate_id IS NOT NULL THEN
        IF p_customer_id IS NOT NULL AND IS_CUSTOMER_EXEMPT(p_customer_id, v_tax_type_id, p_transaction_date) THEN
          v_is_exempt := 'Y';
        ELSIF p_item_id IS NOT NULL AND IS_ITEM_EXEMPT(p_item_id, p_category_id, v_tax_type_id, p_transaction_date) THEN
          v_is_exempt := 'Y';
        END IF;
      END IF;
      
      v_result.tax_rate_id := v_tax_rate_id;
      v_result.tax_code := v_rate_code;
      
      IF v_is_exempt = 'Y' THEN
        v_result.tax_percent := 0;
        v_result.is_exempt := 'Y';
      ELSE
        v_result.tax_percent := v_rate_percent;
        v_result.is_exempt := 'N';
      END IF;
      
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        -- No rule found, returns initialized empty defaults
        NULL;
    END;
    
    RETURN v_result;
  END DETERMINE_TAX_RATE;

  FUNCTION CALCULATE_LINE_TAX(
    p_order_line_id IN NUMBER,
    p_taxable_amount IN NUMBER,
    p_item_id       IN NUMBER,
    p_category_id   IN NUMBER DEFAULT NULL,
    p_customer_id   IN NUMBER DEFAULT NULL,
    p_customer_type IN VARCHAR2 DEFAULT NULL,
    p_inv_org_id    IN NUMBER DEFAULT NULL,
    p_legal_entity_id IN NUMBER DEFAULT NULL
  ) RETURN t_tax_result IS
    v_result t_tax_result;
  BEGIN
    -- Validate params
    IF p_taxable_amount IS NULL OR p_item_id IS NULL THEN
      RAISE_APPLICATION_ERROR(-20010, 'Invalid parameters for CALCULATE_LINE_TAX');
    END IF;

    v_result := DETERMINE_TAX_RATE(
                  p_item_id => p_item_id,
                  p_category_id => p_category_id,
                  p_customer_id => p_customer_id,
                  p_customer_type => p_customer_type,
                  p_inv_org_id => p_inv_org_id,
                  p_legal_entity_id => p_legal_entity_id,
                  p_transaction_date => SYSDATE
                );
                
    v_result.taxable_amount := p_taxable_amount;
    
    IF v_result.is_inclusive = 'Y' THEN
      v_result.tax_amount := (p_taxable_amount * v_result.tax_percent) / (100 + v_result.tax_percent);
    ELSE
      v_result.tax_amount := (p_taxable_amount * v_result.tax_percent) / 100;
    END IF;
    
    RETURN v_result;
  END CALCULATE_LINE_TAX;

  PROCEDURE CALCULATE_ORDER_TAX(
    p_order_id IN NUMBER
  ) IS
    v_inv_org_id POS_ORDERS.INV_ORG_ID%TYPE;
    v_customer_id NUMBER; 
    v_customer_type POS_CUSTOMERS.CUSTOMER_TYPE%TYPE;
    v_category_id NUMBER; 
    v_tax_result t_tax_result;
  BEGIN
    IF p_order_id IS NULL THEN
      RAISE_APPLICATION_ERROR(-20020, 'Order ID is required');
    END IF;

    SAVEPOINT order_tax_sp;
    
    -- DELETE existing POS_ORDER_TAX_LINES for this order
    DELETE FROM POS_ORDER_TAX_LINES WHERE ORDER_ID = p_order_id;
    
    -- Get order details
    BEGIN
      -- Note: Added pseudo-column lookups per spec context.
      SELECT INV_ORG_ID
      INTO v_inv_org_id
      FROM POS_ORDERS
      WHERE ORDER_ID = p_order_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20021, 'Order not found');
    END;
    
    -- CURSOR over active POS_ORDER_LINES
    FOR r_line IN (
      SELECT ORDER_LINE_ID, ITEM_ID, QUANTITY, UNIT_PRICE, LINE_SUBTOTAL
      FROM POS_ORDER_LINES
      WHERE ORDER_ID = p_order_id
        AND LINE_STATUS != 'CANCELLED'
    ) LOOP
      
      v_tax_result := CALCULATE_LINE_TAX(
                        p_order_line_id => r_line.ORDER_LINE_ID,
                        p_taxable_amount => NVL(r_line.LINE_SUBTOTAL, r_line.QUANTITY * r_line.UNIT_PRICE),
                        p_item_id => r_line.ITEM_ID,
                        p_category_id => NULL, -- Normally fetched from item
                        p_customer_id => NULL, -- Normally fetched from order
                        p_customer_type => NULL,
                        p_inv_org_id => v_inv_org_id,
                        p_legal_entity_id => NULL
                      );
                      
      IF v_tax_result.tax_amount IS NOT NULL THEN
        -- INSERT into POS_ORDER_TAX_LINES
        INSERT INTO POS_ORDER_TAX_LINES (
          ORDER_TAX_ID, ORDER_ID, ORDER_LINE_ID, TAX_RATE_ID, TAXABLE_AMOUNT, 
          TAX_PERCENT, TAX_AMOUNT, IS_INCLUSIVE, IS_RECOVERABLE
        ) VALUES (
          POS_ORDER_TAX_LINES_SEQ.NEXTVAL, p_order_id, r_line.ORDER_LINE_ID, v_tax_result.tax_rate_id,
          v_tax_result.taxable_amount, v_tax_result.tax_percent, v_tax_result.tax_amount,
          v_tax_result.is_inclusive, v_tax_result.is_recoverable
        );
        
        -- UPDATE POS_ORDER_LINES
        UPDATE POS_ORDER_LINES
        SET TAX_RATE = v_tax_result.tax_percent,
            TAX_AMOUNT = v_tax_result.tax_amount
        WHERE ORDER_LINE_ID = r_line.ORDER_LINE_ID;
      END IF;
      
    END LOOP;
    
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO order_tax_sp;
      RAISE_APPLICATION_ERROR(-20001, 'Error calculating order tax: ' || SQLERRM);
  END CALCULATE_ORDER_TAX;

END PKG_TAX_ENGINE;
/
