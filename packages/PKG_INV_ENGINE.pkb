CREATE OR REPLACE PACKAGE BODY PKG_INV_ENGINE AS
-- ============================================================================
-- Package Body: PKG_INV_ENGINE  
-- ============================================================================

  FUNCTION VALIDATE_STOCK(
    p_inv_org_id  IN NUMBER,
    p_item_id     IN NUMBER,
    p_variant_id  IN NUMBER DEFAULT NULL,
    p_quantity    IN NUMBER
  ) RETURN BOOLEAN IS
    v_available NUMBER;
  BEGIN
    v_available := GET_AVAILABLE_QTY(p_inv_org_id, p_item_id, p_variant_id);
    RETURN (v_available >= p_quantity);
  END VALIDATE_STOCK;

  FUNCTION GET_AVAILABLE_QTY(
    p_inv_org_id IN NUMBER,
    p_item_id    IN NUMBER,
    p_variant_id IN NUMBER DEFAULT NULL
  ) RETURN NUMBER IS
    v_qty NUMBER := 0;
  BEGIN
    SELECT NVL(SUM(QUANTITY_ON_HAND - NVL(QUANTITY_RESERVED, 0)), 0)
    INTO v_qty
    FROM POS_INVENTORY_BALANCES
    WHERE INV_ORG_ID = p_inv_org_id
      AND ITEM_ID = p_item_id
      AND (VARIANT_ID = p_variant_id OR (p_variant_id IS NULL AND VARIANT_ID IS NULL));
    RETURN v_qty;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 0;
  END GET_AVAILABLE_QTY;

  FUNCTION FIFO_CONSUME_LAYERS(
    p_inv_org_id  IN NUMBER,
    p_item_id     IN NUMBER,
    p_variant_id  IN NUMBER DEFAULT NULL,
    p_quantity    IN NUMBER,
    p_txn_id      IN NUMBER
  ) RETURN NUMBER IS
    v_remaining_to_consume NUMBER := p_quantity;
    v_total_cost NUMBER := 0;
    v_layer_consume_qty NUMBER;
  BEGIN
    -- FIFO cost processing
    FOR r_layer IN (
      SELECT LAYER_ID, REMAINING_QUANTITY, UNIT_COST
      FROM POS_FIFO_COST_LAYERS
      WHERE INV_ORG_ID = p_inv_org_id
        AND ITEM_ID = p_item_id
        AND (VARIANT_ID = p_variant_id OR (p_variant_id IS NULL AND VARIANT_ID IS NULL))
        AND LAYER_STATUS IN ('OPEN', 'PARTIAL')
      ORDER BY RECEIPT_DATE ASC, LAYER_ID ASC
      FOR UPDATE NOWAIT
    ) LOOP
      IF v_remaining_to_consume <= 0 THEN
        EXIT;
      END IF;

      IF r_layer.REMAINING_QUANTITY <= v_remaining_to_consume THEN
        v_layer_consume_qty := r_layer.REMAINING_QUANTITY;
        UPDATE POS_FIFO_COST_LAYERS
        SET REMAINING_QUANTITY = 0, LAYER_STATUS = 'CONSUMED'
        WHERE LAYER_ID = r_layer.LAYER_ID;
      ELSE
        v_layer_consume_qty := v_remaining_to_consume;
        UPDATE POS_FIFO_COST_LAYERS
        SET REMAINING_QUANTITY = REMAINING_QUANTITY - v_layer_consume_qty, LAYER_STATUS = 'PARTIAL'
        WHERE LAYER_ID = r_layer.LAYER_ID;
      END IF;

      v_total_cost := v_total_cost + (v_layer_consume_qty * r_layer.UNIT_COST);
      v_remaining_to_consume := v_remaining_to_consume - v_layer_consume_qty;
    END LOOP;

    IF p_quantity > 0 THEN
      RETURN v_total_cost / p_quantity;
    ELSE
      RETURN 0;
    END IF;
  END FIFO_CONSUME_LAYERS;

  PROCEDURE FIFO_CREATE_LAYER(
    p_inv_org_id  IN NUMBER,
    p_subinv_id   IN NUMBER DEFAULT NULL,
    p_item_id     IN NUMBER,
    p_variant_id  IN NUMBER DEFAULT NULL,
    p_quantity    IN NUMBER,
    p_unit_cost   IN NUMBER,
    p_receipt_txn_id IN NUMBER
  ) IS
  BEGIN
    INSERT INTO POS_FIFO_COST_LAYERS (
      LAYER_ID, INV_ORG_ID, SUBINV_ID, ITEM_ID, VARIANT_ID, 
      RECEIPT_DATE, RECEIPT_TXN_ID, ORIGINAL_QUANTITY, 
      REMAINING_QUANTITY, UNIT_COST, LAYER_STATUS
    ) VALUES (
      pos_fifo_cost_layers_seq.NEXTVAL, p_inv_org_id, p_subinv_id, p_item_id, p_variant_id,
      SYSDATE, p_receipt_txn_id, p_quantity, p_quantity, p_unit_cost, 'OPEN'
    );
  END FIFO_CREATE_LAYER;

  FUNCTION RECALCULATE_AVERAGE_COST(
    p_inv_org_id IN NUMBER,
    p_item_id    IN NUMBER,
    p_variant_id IN NUMBER DEFAULT NULL
  ) RETURN NUMBER IS
    v_qty NUMBER;
    v_total NUMBER;
    v_cost NUMBER;
  BEGIN
    SELECT SUM(QUANTITY_ON_HAND), SUM(TOTAL_COST)
    INTO v_qty, v_total
    FROM POS_INVENTORY_BALANCES
    WHERE INV_ORG_ID = p_inv_org_id
      AND ITEM_ID = p_item_id
      AND (VARIANT_ID = p_variant_id OR (p_variant_id IS NULL AND VARIANT_ID IS NULL));
      
    IF v_qty > 0 THEN
      RETURN v_total / v_qty;
    END IF;

    -- Fallback
    SELECT COST_PRICE INTO v_cost FROM POS_ITEMS WHERE ITEM_ID = p_item_id;
    RETURN v_cost;
  EXCEPTION
    WHEN OTHERS THEN RETURN 0;
  END RECALCULATE_AVERAGE_COST;

  PROCEDURE TRANSACT_INVENTORY(
    p_inv_org_id    IN NUMBER,
    p_subinv_id     IN NUMBER,
    p_item_id       IN NUMBER,
    p_variant_id    IN NUMBER DEFAULT NULL,
    p_lot_serial_id IN NUMBER DEFAULT NULL,
    p_uom_code      IN VARCHAR2,
    p_txn_type      IN VARCHAR2,
    p_quantity      IN NUMBER,
    p_unit_cost     IN NUMBER DEFAULT NULL,
    p_order_id      IN NUMBER DEFAULT NULL,
    p_order_line_id IN NUMBER DEFAULT NULL,
    p_transfer_id   IN NUMBER DEFAULT NULL,
    p_notes         IN VARCHAR2 DEFAULT NULL,
    p_txn_id        OUT NUMBER
  ) IS
    v_actual_cost NUMBER := p_unit_cost;
    v_cost_method VARCHAR2(30);
    v_txn_total NUMBER;
  BEGIN
    -- Validate params
    IF p_inv_org_id IS NULL OR p_subinv_id IS NULL OR p_item_id IS NULL THEN
      RAISE_APPLICATION_ERROR(-20010, 'Missing mandatory parameters for transaction.');
    END IF;

    SAVEPOINT inv_txn_sp;

    -- Get Costing Method
    SELECT COSTING_METHOD INTO v_cost_method
    FROM POS_INVENTORY_ORGS
    WHERE INV_ORG_ID = p_inv_org_id;

    -- Validate Stock for depletion
    IF p_txn_type IN ('SALE', 'TRANSFER_OUT') AND p_quantity < 0 THEN
      IF NOT VALIDATE_STOCK(p_inv_org_id, p_item_id, p_variant_id, ABS(p_quantity)) THEN
        RAISE_APPLICATION_ERROR(E_INSUFFICIENT_STOCK, 'Insufficient stock for transaction.');
      END IF;
    END IF;

    -- Determine Unit Cost
    IF v_actual_cost IS NULL THEN
      IF v_cost_method = 'FIFO' AND p_quantity < 0 THEN
        v_actual_cost := FIFO_CONSUME_LAYERS(p_inv_org_id, p_item_id, p_variant_id, ABS(p_quantity), NULL);
      ELSIF v_cost_method = 'AVERAGE' THEN
        v_actual_cost := RECALCULATE_AVERAGE_COST(p_inv_org_id, p_item_id, p_variant_id);
      ELSE
        SELECT COST_PRICE INTO v_actual_cost FROM POS_ITEMS WHERE ITEM_ID = p_item_id;
      END IF;
    END IF;
    
    v_txn_total := ABS(p_quantity) * NVL(v_actual_cost, 0);
    p_txn_id := pos_inv_transactions_seq.NEXTVAL;

    -- Insert Txn
    INSERT INTO POS_INVENTORY_TRANSACTIONS (
      INV_TXN_ID, INV_ORG_ID, SUBINV_ID, ITEM_ID, VARIANT_ID, LOT_SERIAL_ID,
      UOM_CODE, TXN_TYPE, TXN_DATE, QUANTITY, UNIT_COST, TOTAL_COST,
      ORDER_ID, ORDER_LINE_ID, TRANSFER_ID, NOTES
    ) VALUES (
      p_txn_id, p_inv_org_id, p_subinv_id, p_item_id, p_variant_id, p_lot_serial_id,
      p_uom_code, p_txn_type, SYSDATE, p_quantity, v_actual_cost, v_txn_total,
      p_order_id, p_order_line_id, p_transfer_id, p_notes
    );

    IF v_cost_method = 'FIFO' AND p_quantity > 0 AND p_txn_type IN ('RECEIPT', 'TRANSFER_IN', 'RETURN') THEN
      FIFO_CREATE_LAYER(p_inv_org_id, p_subinv_id, p_item_id, p_variant_id, p_quantity, v_actual_cost, p_txn_id);
    END IF;

    -- Update Balances UPSERT
    MERGE INTO POS_INVENTORY_BALANCES b
    USING (SELECT 1 FROM DUAL) d
    ON (b.INV_ORG_ID = p_inv_org_id AND b.SUBINV_ID = p_subinv_id AND b.ITEM_ID = p_item_id AND NVL(b.VARIANT_ID,-1) = NVL(p_variant_id,-1))
    WHEN MATCHED THEN
      UPDATE SET 
        QUANTITY_ON_HAND = QUANTITY_ON_HAND + p_quantity,
        TOTAL_COST = TOTAL_COST + (p_quantity * v_actual_cost),
        LAST_TRANSACTION_DATE = SYSDATE
    WHEN NOT MATCHED THEN
      INSERT (BALANCE_ID, INV_ORG_ID, SUBINV_ID, ITEM_ID, VARIANT_ID, UOM_CODE, QUANTITY_ON_HAND, TOTAL_COST, LAST_TRANSACTION_DATE)
      VALUES (pos_inv_balances_seq.NEXTVAL, p_inv_org_id, p_subinv_id, p_item_id, p_variant_id, p_uom_code, p_quantity, (p_quantity * v_actual_cost), SYSDATE);

    -- If lot/serial update
    IF p_lot_serial_id IS NOT NULL THEN
      UPDATE POS_LOT_SERIAL_CONTROL
      SET QUANTITY_ON_HAND = QUANTITY_ON_HAND + p_quantity
      WHERE LOT_SERIAL_ID = p_lot_serial_id;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO inv_txn_sp;
      RAISE;
  END TRANSACT_INVENTORY;

  PROCEDURE PROCESS_ORDER_INVENTORY(
    p_order_id IN NUMBER
  ) IS
    v_inv_org_id POS_ORDERS.INV_ORG_ID%TYPE;
    v_subinv_id NUMBER;
    v_txn_id NUMBER;
  BEGIN
    SELECT INV_ORG_ID INTO v_inv_org_id FROM POS_ORDERS WHERE ORDER_ID = p_order_id;
    
    SELECT SUBINV_ID INTO v_subinv_id FROM POS_SUBINVENTORIES 
    WHERE INV_ORG_ID = v_inv_org_id FETCH FIRST 1 ROWS ONLY;

    FOR r_line IN (SELECT * FROM POS_ORDER_LINES WHERE ORDER_ID = p_order_id AND LINE_STATUS != 'CANCELLED') LOOP
      TRANSACT_INVENTORY(
        p_inv_org_id => v_inv_org_id,
        p_subinv_id => v_subinv_id,
        p_item_id => r_line.ITEM_ID,
        p_variant_id => r_line.VARIANT_ID,
        p_lot_serial_id => r_line.LOT_SERIAL_ID,
        p_uom_code => r_line.UOM_CODE,
        p_txn_type => 'SALE',
        p_quantity => -r_line.QUANTITY,
        p_order_id => p_order_id,
        p_order_line_id => r_line.ORDER_LINE_ID,
        p_txn_id => v_txn_id
      );
    END LOOP;
  END PROCESS_ORDER_INVENTORY;

  PROCEDURE RESERVE_STOCK(
    p_inv_org_id IN NUMBER,
    p_item_id    IN NUMBER,
    p_variant_id IN NUMBER DEFAULT NULL,
    p_quantity   IN NUMBER
  ) IS
  BEGIN
    UPDATE POS_INVENTORY_BALANCES
    SET QUANTITY_RESERVED = NVL(QUANTITY_RESERVED, 0) + p_quantity
    WHERE INV_ORG_ID = p_inv_org_id
      AND ITEM_ID = p_item_id
      AND NVL(VARIANT_ID,-1) = NVL(p_variant_id,-1);
  END RESERVE_STOCK;

  PROCEDURE RELEASE_RESERVATION(
    p_inv_org_id IN NUMBER,
    p_item_id    IN NUMBER,
    p_variant_id IN NUMBER DEFAULT NULL,
    p_quantity   IN NUMBER
  ) IS
  BEGIN
    UPDATE POS_INVENTORY_BALANCES
    SET QUANTITY_RESERVED = GREATEST(NVL(QUANTITY_RESERVED, 0) - p_quantity, 0)
    WHERE INV_ORG_ID = p_inv_org_id
      AND ITEM_ID = p_item_id
      AND NVL(VARIANT_ID,-1) = NVL(p_variant_id,-1);
  END RELEASE_RESERVATION;

  PROCEDURE CREATE_TRANSFER(
    p_from_org_id   IN NUMBER,
    p_to_org_id     IN NUMBER,
    p_from_subinv   IN NUMBER DEFAULT NULL,
    p_to_subinv     IN NUMBER DEFAULT NULL,
    p_transfer_id   OUT NUMBER
  ) IS
  BEGIN
    p_transfer_id := pos_stock_transfers_seq.NEXTVAL;
    INSERT INTO POS_STOCK_TRANSFERS (
      TRANSFER_ID, FROM_INV_ORG_ID, TO_INV_ORG_ID, FROM_SUBINV_ID, TO_SUBINV_ID, 
      TRANSFER_STATUS, TRANSFER_DATE
    ) VALUES (
      p_transfer_id, p_from_org_id, p_to_org_id, p_from_subinv, p_to_subinv,
      'DRAFT', SYSDATE
    );
  END CREATE_TRANSFER;

  PROCEDURE SHIP_TRANSFER(p_transfer_id IN NUMBER) IS
    v_txn_id NUMBER;
  BEGIN
    FOR r_line IN (SELECT * FROM POS_STOCK_TRANSFER_LINES WHERE TRANSFER_ID = p_transfer_id) LOOP
      -- Txn logic omitted for brevity, would loop and TRANSACT_INVENTORY out
      NULL;
    END LOOP;
    UPDATE POS_STOCK_TRANSFERS SET TRANSFER_STATUS = 'IN_TRANSIT' WHERE TRANSFER_ID = p_transfer_id;
  END SHIP_TRANSFER;

  PROCEDURE RECEIVE_TRANSFER(p_transfer_id IN NUMBER) IS
  BEGIN
    UPDATE POS_STOCK_TRANSFERS SET TRANSFER_STATUS = 'RECEIVED' WHERE TRANSFER_ID = p_transfer_id;
  END RECEIVE_TRANSFER;

END PKG_INV_ENGINE;
/
