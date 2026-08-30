# Enterprise POS & ERP System Specification & Chat Context

## 1. Objective & Requirements Overview
An enterprise-grade Point of Sale (POS) and integrated ERP suite built with Oracle APEX, modern PL/SQL, and client-side JavaScript / PWA capabilities following Oracle EBS / Fusion standards.

### Key Pillars:
1. **Multi-Tenant & Multi-Org Hierarchy (EBS Style)**:
   - `Legal Entity` -> `Operating Unit (HQ/Central Management)` -> `Inventory Organizations / Branches / Warehouses` -> `Subinventories / POS Terminals`.
   - Row-Level Security (VPD / APEX Contexts) with `POS_CTX`.
2. **Multi-Sector Hybrid Engine**:
   - Retail (Matrix Variants, Barcode scanning, Lot & Serial tracking).
   - Food & Beverage (F&B Table layout, KDS integration, Split billing).
   - Services (Time-based line items, custom charges).
3. **Supply Chain & Inventory Engine**:
   - Multi-valuation support: FIFO (`POS_FIFO_COST_LAYERS`), Moving Weighted Average, and Standard Costing.
   - Inter-org stock transfers with transit tracking and physical cycle counting.
4. **Subledger Accounting (SLA) & Financials Core**:
   - Chart of Accounts (COA) multi-segment flexfields (`POS_COA_SEGMENTS`, `POS_COA_ACCOUNTS`).
   - Automated posting rules (`POS_SLA_RULES`) generating GL Journals for sales, COGS, discounts, tax, and variance.
   - Accounts Receivable (AR) and Accounts Payable (AP) subledgers.
5. **Cash Management & Shifts**:
   - Shift opening float, mid-shift cash drops, paid-in/paid-out, blind close, reconciliation with Over/Short GL journals, X-Reports & Z-Reports.
6. **Dynamic Tax Engine & E-Invoicing**:
   - Multi-tier rule matrix for VAT, GST, compound taxes, exemptions.
   - Ready for TLV QR / digital signing and UBL 2.1 XML output.
7. **Offline PWA Architecture**:
   - IndexedDB local storage for caching and offline order queuing (`pos_offline_txns`).
   - Bidirectional JSON sync with idempotency keys.
8. **Hardware Integration**:
   - Direct ESC/POS thermal printing (Web Serial/USB/Network), cash drawer kick, and pole display.

---

## 2. Implementation Roadmap

- **Phase 1**: Database Architecture & Normalized Schema (66+ tables, Sequences, Constraints, Indexes, VPD Policies) -> `ddl/`
- **Phase 2**: PL/SQL Business Logic Packages (`PKG_POS_CORE`, `PKG_TAX_ENGINE`, `PKG_INV_ENGINE`, `PKG_ACCOUNTING_ENGINE`, `PKG_OFFLINE_SYNC`) -> `packages/`
- **Phase 3**: Offline PWA, IndexedDB & Hardware Web APIs (`sw.js`, `idb-manager.js`, `pos-sync.js`, `escpos.js`, `pos-hardware.js`) -> `js/`
- **Phase 4**: Oracle APEX UI/UX & Component Design (Terminal Page 100, Admin Grids, Keyboard Shortcuts F1-F12) -> `apex_specs/`