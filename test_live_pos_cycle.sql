-- ==============================================================================
-- test_live_pos_cycle.sql
-- Live End-to-End POS Transaction Simulation for Oracle APEX SQL Commands
-- ==============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
    v_shift_id       NUMBER;
    v_order_id       NUMBER;
    v_order_no       VARCHAR2(50);
    v_line_id1       NUMBER;
    v_line_id2       NUMBER;
    v_pay_id1        NUMBER;
    v_pay_id2        NUMBER;
    
    v_subtotal       NUMBER;
    v_tax            NUMBER;
    v_total          NUMBER;
    v_paid           NUMBER;
    v_rem            NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('  🚀 STARTING LIVE POS END-TO-END TRANSACTION TEST');
    DBMS_OUTPUT.PUT_LINE('============================================================');

    -- 1. SET USER CONTEXT FOR ADMIN AT OLAYA STORE
    POS_CTX_PKG.SET_SESSION_CONTEXT('ADMIN', 1000001);
    DBMS_OUTPUT.PUT_LINE('✔ 1. Security Context Initialized (User: ADMIN, Org: Olaya Store)');

    -- 2. OPEN A NEW CASHIER SHIFT (وردية جديدة بعهدة 500 ريال)
    INSERT INTO POS_SHIFTS (
        SHIFT_ID, SHIFT_NO, TERMINAL_ID, INV_ORG_ID, CASHIER_USER_ID,
        SHIFT_STATUS, OPEN_DATETIME, OPENING_FLOAT, EXPECTED_CASH
    ) VALUES (
        pos_shifts_seq.NEXTVAL, 'SHF-' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '-001', 
        1000001, 1000001, 1000001,
        'OPEN', SYSTIMESTAMP, 500.00, 500.00
    ) RETURNING SHIFT_ID INTO v_shift_id;
    
    DBMS_OUTPUT.PUT_LINE('✔ 2. Cashier Shift Opened Successfully (Shift ID: ' || v_shift_id || ')');

    -- 3. CREATE DRAFT ORDER (إنشاء مسودة فاتورة)
    PKG_POS_CORE.CREATE_ORDER(
        p_inv_org_id      => 1000001,
        p_terminal_id     => 1000001,
        p_shift_id        => v_shift_id,
        p_cashier_user_id => 1000001,
        p_order_type      => 'SALE',
        p_sector_type     => 'RETAIL',
        p_customer_id     => 1000001, -- عميل نقدي
        p_currency_code   => 'SAR',
        p_price_list_id   => 1000001, -- Standard Retail SAR
        p_order_id        => v_order_id,
        p_order_no        => v_order_no
    );
    
    DBMS_OUTPUT.PUT_LINE('✔ 3. Order Header Created (Order No: ' || v_order_no || ', ID: ' || v_order_id || ')');

    -- 4. ADD ITEM 1: Classic Cafe Latte (2 Cups @ 16.00 SAR from Price List)
    PKG_POS_CORE.ADD_ORDER_LINE(
        p_order_id     => v_order_id,
        p_item_id      => 1000001,
        p_variant_id   => NULL,
        p_quantity     => 2,
        p_uom_code     => 'EA',
        p_unit_price   => NULL, -- Auto-resolved from Price List Hierarchy
        p_discount_pct => 0,
        p_line_notes   => 'Extra Hot',
        p_line_id      => v_line_id1
    );
    DBMS_OUTPUT.PUT_LINE('✔ 4. Line 1 Added: 2x Classic Cafe Latte (Auto-priced from Price List)');

    -- 5. ADD ITEM 2: Polo Shirt Black Medium (1 Qty @ 89.00 SAR with 10% Discount)
    PKG_POS_CORE.ADD_ORDER_LINE(
        p_order_id     => v_order_id,
        p_item_id      => 1000002,
        p_variant_id   => 1000001, -- Black Medium
        p_quantity     => 1,
        p_uom_code     => 'EA',
        p_unit_price   => NULL, -- Auto-resolved (89.00 SAR)
        p_discount_pct => 10,   -- 10% Line Discount
        p_line_notes   => 'Special Promo',
        p_line_id      => v_line_id2
    );
    DBMS_OUTPUT.PUT_LINE('✔ 5. Line 2 Added: 1x Polo Shirt (Black M) with 10% discount');

    -- 6. INSPECT CALCULATED TOTALS & HALALA ROUNDING
    SELECT SUBTOTAL, TAX_AMOUNT, TOTAL_AMOUNT, NVL(PAID_AMOUNT, 0)
      INTO v_subtotal, v_tax, v_total, v_paid
      FROM POS_ORDERS
     WHERE ORDER_ID = v_order_id;
     
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('  🧾 ORDER SUMMARY:');
    DBMS_OUTPUT.PUT_LINE('     - Subtotal (Net)  : ' || TO_CHAR(v_subtotal, '999,990.00') || ' SAR');
    DBMS_OUTPUT.PUT_LINE('     - VAT (15%)       : ' || TO_CHAR(v_tax, '999,990.00') || ' SAR');
    DBMS_OUTPUT.PUT_LINE('     - Total to Settle : ' || TO_CHAR(v_total, '999,990.00') || ' SAR (Rounded to 0.05)');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');

    -- 7. SPLIT TENDER PAYMENTS (دفع مجزأ: 50 ريال كاش + الباقي شبكة مدى)
    -- Tender 1: 50 SAR Cash
    PKG_POS_CORE.ADD_PAYMENT(
        p_order_id          => v_order_id,
        p_payment_method_id => 1000001, -- CASH
        p_amount_tendered   => 50.00,
        p_payment_reference => 'CASH-PAY-01',
        p_payment_id        => v_pay_id1
    );
    DBMS_OUTPUT.PUT_LINE('✔ 7. Payment 1 Processed: 50.00 SAR Cash');

    -- Tender 2: Remaining via Mada Card
    v_rem := v_total - 50.00;
    PKG_POS_CORE.ADD_PAYMENT(
        p_order_id          => v_order_id,
        p_payment_method_id => 1000002, -- MADA
        p_amount_tendered   => v_rem,
        p_payment_reference => 'AUTH-MADA-982144',
        p_card_last4        => '4321',
        p_auth_code         => 'OK-88912',
        p_payment_id        => v_pay_id2
    );
    DBMS_OUTPUT.PUT_LINE('✔ 8. Payment 2 Processed: ' || TO_CHAR(v_rem, '990.00') || ' SAR via Mada Card');

    -- 8. SETTLE AND FINALIZE ORDER (تسوية الفاتورة وتفعيل المخزون والحسابات)
    PKG_POS_CORE.SETTLE_ORDER(v_order_id);
    DBMS_OUTPUT.PUT_LINE('✔ 9. ORDER SETTLED AND FINALIZED (Status: PAID)');

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('  🎉 LIVE TRANSACTION TEST COMPLETED WITH 100% SUCCESS!');
    DBMS_OUTPUT.PUT_LINE('============================================================');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('❌ ERROR: ' || SQLERRM);
        RAISE;
END;
/