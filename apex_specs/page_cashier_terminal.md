# Page 100: Cashier POS Terminal Specification

## 1. Page Attributes
- **Page Mode:** Normal / No Navigation
- **Page Template:** Minimal / Blank (to maximize screen real-estate for touch usage)
- **JavaScript Files to Load:** Include custom offline sync libraries (`pos_sync.js`, `idb_manager.js`, `pos_hardware.js`).
- **Inline CSS:** Custom responsive grid CSS for touch-friendly buttons, high contrast, and large typography suitable for 10"-15" POS displays.

## 2. Layout & Regions

### Header Bar
- **Logo:** Store/Company logo on the far left.
- **Cashier Info:** Display logged-in cashier name.
- **Shift & Terminal info:** Current Shift# and Terminal#.
- **Network Status:** Online/Offline badge with dynamic color (Green/Red).
- **Time:** Real-time clock.
- **Logout/Lock:** Prominent button to quickly lock the terminal or sign out.

### Left Panel (60% width)
- **Search & Barcode Scan Bar:** 
  - Item name `P100_SEARCH`. 
  - Must have Auto-focus on page load.
  - Scanner icon to indicate readiness.
- **Category Fast-Tabs:** 
  - Touch buttons arrayed horizontally or in a grid.
  - Dynamically colored from `POS_ITEM_CATEGORIES`.
- **Item Grid / Quick Tiles:** 
  - Responsive matrix of product buttons.
  - Display properties: Image (if available), Name, Price, and Stock level indicator.

### Right Panel (40% width)
- **Order Header:** 
  - Current Order#.
  - Customer LOV/Selector (with guest default).
  - Table# for F&B (if applicable).
- **Cart Items List / Interactive Grid:** 
  - Editable fields: Quantity, Unit Price, Line Discount.
  - Read-only fields: Line Total.
  - Actions: Trash/Void button per line.
- **Summary Box:** 
  - Metrics: Subtotal, Order Discount, Tax, Rounding, Net Total.
  - Styling: Large bold typography for Net Total.
- **Action & Tender Button Matrix:** 
  - **F1:** Cash Pay
  - **F2:** Card Pay
  - **F3:** Split Tender
  - **F4:** Hold Order
  - **F5:** Recall Order
  - **F6:** Line Discount
  - **F7:** Order Discount
  - **F8:** Price Check
  - **F9:** Quantity Change
  - **F10:** Customer Select
  - **F11:** Table Select
  - **F12:** Settle & Print

## 3. Split Tender Payment Modal (Page 101)
- **Page Mode:** Modal Dialog
- **Payment Method Tiles:** Touch-friendly tiles for Cash, Mada, Visa/Mastercard, Apple Pay, Loyalty Points, Credit Voucher.
- **Numeric Keypad:** Large on-screen keypad for touch entry.
- **Financial Details:** Display Tendered amount, Change to give, Remaining balance.

## 4. Dynamic Actions (DA) Specifications

- **DA_BARCODE_SCAN:** 
  - **Trigger:** KeyPress (Enter) on `P100_SEARCH` or hardware event listener.
  - **Action:** Execute PL/SQL / AJAX calling `PKG_POS_CORE.ADD_ORDER_LINE`.
- **DA_CART_QTY_CHANGE:** 
  - **Trigger:** Change event on quantity column in Interactive Grid.
  - **Action:** Recalculates line total and overall summary box totals instantly.
- **DA_KEYBOARD_SHORTCUTS:** 
  - **Trigger:** Global keydown listener.
  - **Action:** Maps F1-F12 keys to their respective POS actions via JavaScript routing.
- **DA_SETTLE_ORDER:** 
  - **Trigger:** Click on 'Settle' or mapped F12 key.
  - **Action:** Calls PL/SQL `SETTLE_ORDER`, triggers ESC/POS print command, kicks cash drawer open, and resets the cart for the next customer.

## 5. Client-Side JavaScript Integration Hooks
- **`window.POSSync`**: Manages pushing offline orders to the server when network is restored.
- **`window.IDBManager`**: IndexedDB interface for local product catalog, price lists, and customer cache.
- **`window.POSHardware`**: Interfaces with local WebSerial API for ESC/POS printer and cash drawer control.
