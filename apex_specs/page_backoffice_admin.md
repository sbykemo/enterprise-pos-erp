# Back-Office Administration Pages Specification

## 1. Page 200: Executive & Store Operations Dashboard
- **Region Type:** Cards Region & Charts
- **Metrics Displayed:** 
  - Today's Sales
  - Open Shifts
  - Low Stock Alerts
  - Tax Collected
- **Visualizations:** Chart of Sales by Hour & Category (Bar/Line charts).

## 2. Page 210: Item Master & Matrix Variant Interactive Grid
- **Layout:** Tree + Interactive Grid (IG)
- **Features:** 
  - Hierarchical tree for Categories.
  - IG for Items and Matrix Variants.
  - Manage Size/Color attributes.
  - UOM (Unit of Measure) conversion rules.
  - Lot/Serial tracking flags toggle.

## 3. Page 220: Price List & Promotion Rule Builder
- **Layout:** Master-Detail Interactive Grid
- **Master:** Price Lists (Name, Currency, Start/End Dates).
- **Detail:** Price Lines (Item, UOM, Unit Price).
- **Promotion Wizard:** Guided flow for setting up complex promotions:
  - BXGY (Buy X Get Y)
  - Bundle discounts
  - Threshold-based discounts (Spend $X, get $Y off).

## 4. Page 230: Subledger Accounting (SLA) & GL Rules Configurator
- **Flexfield Mapping:** Interface for mapping POS events to Chart of Accounts (COA) segments.
- **SLA Rule Engine:** Priority-based rule definition grid for deriving GL accounts.
- **Journal Review IG:** Interactive Grid displaying generated accounting entries with drill-down capability directly to the source POS order.

## 5. Page 240: Inventory Control & Inter-Org Stock Transfer
- **Stock Balances View:** Real-time on-hand quantities by Org and Subinventory.
- **Transfer Workflow:** Forms and Grids for Request, Ship, and Receive processes.
- **Cycle Count Grid:** Interactive Grid for physical inventory counts with virtual column calculations for variance amount and percentage.

## 6. Page 250: Shift Reconciliation & Cash Management
- **Shift Audit Report:** Detailed view of all shift activities.
- **Reconciliation:** Blind close reconciliation entry forms.
- **Cash Management:** Cash drops ledger for recording safe deposits.
- **Reporting:** X/Z report viewer with export capabilities.
