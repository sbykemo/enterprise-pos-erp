CREATE OR REPLACE PACKAGE PKG_INV_ENGINE AS
-- ============================================================================
-- Package: PKG_INV_ENGINE  
-- Purpose: Inventory transactions, stock validation, FIFO/Average costing,
--          inter-org transfers, and stock balance management
-- ============================================================================

  E_INSUFFICIENT_STOCK CONSTANT NUMBER := -20201;
  E_INVALID_SUBINV     CONSTANT NUMBER := -20202;
  E_LOT_EXPIRED        CONSTANT NUMBER := -20203;
  E_SERIAL_UNAVAILABLE CONSTANT NUMBER := -20204;
  E_TRANSFER_ERROR     CONSTANT NUMBER := -20205;

  -- Core inventory transaction: inserts ledger entry and updates balances
  PROCEDURE TRANSACT_INVENTORY(
    p_inv_org_id    IN NUMBER,
    p_subinv_id     IN NUMBER,
    p_item_id       IN NUMBER,
    p_variant_id    IN NUMBER DEFAULT NULL,
    p_lot_serial_id IN NUMBER DEFAULT NULL,
    p_uom_code      IN VARCHAR2,
    p_txn_type      IN VARCHAR2,  -- SALE, RETURN, RECEIPT, ADJUSTMENT, etc.
    p_quantity      IN NUMBER,    -- positive=increase, negative=decrease
    p_unit_cost     IN NUMBER DEFAULT NULL,
    p_order_id      IN NUMBER DEFAULT NULL,
    p_order_line_id IN NUMBER DEFAULT NULL,
    p_transfer_id   IN NUMBER DEFAULT NULL,
    p_notes         IN VARCHAR2 DEFAULT NULL,
    p_txn_id        OUT NUMBER
  );

  -- Validate stock availability before sale
  FUNCTION VALIDATE_STOCK(
    p_inv_org_id  IN NUMBER,
    p_item_id     IN NUMBER,
    p_variant_id  IN NUMBER DEFAULT NULL,
    p_quantity    IN NUMBER
  ) RETURN BOOLEAN;

  -- Get available quantity (on_hand - reserved) for an item at an org
  FUNCTION GET_AVAILABLE_QTY(
    p_inv_org_id IN NUMBER,
    p_item_id    IN NUMBER,
    p_variant_id IN NUMBER DEFAULT NULL
  ) RETURN NUMBER;

  -- FIFO costing: consume oldest cost layers for a sale
  FUNCTION FIFO_CONSUME_LAYERS(
    p_inv_org_id  IN NUMBER,
    p_item_id     IN NUMBER,
    p_variant_id  IN NUMBER DEFAULT NULL,
    p_quantity    IN NUMBER,
    p_txn_id      IN NUMBER
  ) RETURN NUMBER;  -- returns weighted average cost of consumed qty

  -- FIFO costing: create new cost layer upon receipt
  PROCEDURE FIFO_CREATE_LAYER(
    p_inv_org_id  IN NUMBER,
    p_subinv_id   IN NUMBER DEFAULT NULL,
    p_item_id     IN NUMBER,
    p_variant_id  IN NUMBER DEFAULT NULL,
    p_quantity    IN NUMBER,
    p_unit_cost   IN NUMBER,
    p_receipt_txn_id IN NUMBER
  );

  -- Recalculate moving weighted average cost
  FUNCTION RECALCULATE_AVERAGE_COST(
    p_inv_org_id IN NUMBER,
    p_item_id    IN NUMBER,
    p_variant_id IN NUMBER DEFAULT NULL
  ) RETURN NUMBER;

  -- Reserve stock for an order
  PROCEDURE RESERVE_STOCK(
    p_inv_org_id IN NUMBER,
    p_item_id    IN NUMBER,
    p_variant_id IN NUMBER DEFAULT NULL,
    p_quantity   IN NUMBER
  );

  -- Release previously reserved stock
  PROCEDURE RELEASE_RESERVATION(
    p_inv_org_id IN NUMBER,
    p_item_id    IN NUMBER,
    p_variant_id IN NUMBER DEFAULT NULL,
    p_quantity   IN NUMBER
  );

  -- Process complete order inventory depletion (called by PKG_POS_CORE.SETTLE_ORDER)
  PROCEDURE PROCESS_ORDER_INVENTORY(
    p_order_id IN NUMBER
  );

  -- Create inter-org stock transfer
  PROCEDURE CREATE_TRANSFER(
    p_from_org_id   IN NUMBER,
    p_to_org_id     IN NUMBER,
    p_from_subinv   IN NUMBER DEFAULT NULL,
    p_to_subinv     IN NUMBER DEFAULT NULL,
    p_transfer_id   OUT NUMBER
  );

  -- Ship transfer (move to IN_TRANSIT)
  PROCEDURE SHIP_TRANSFER(p_transfer_id IN NUMBER);

  -- Receive transfer (complete the transfer)
  PROCEDURE RECEIVE_TRANSFER(p_transfer_id IN NUMBER);

END PKG_INV_ENGINE;
/
