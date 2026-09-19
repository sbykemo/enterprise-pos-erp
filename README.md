# 🛒 Enterprise POS & ERP System
### Production-Grade Enterprise Point of Sale & ERP Solution
**Built on Oracle APEX 26.1 / Oracle Cloud Autonomous Database (OCI 19c/23ai)**

---

## 🚀 Overview
An enterprise-grade, multi-company, multi-branch POS and ERP system engineered with high reliability, accounting immutability, offline resilience, and robust multi-tenancy security.

---

## 🌟 Key Accomplishments & Modules

1. **POS Terminal & Shift Management (Pages 100, 101, 250):**
   - Barcode scanning, dynamic shopping cart, split payments (Cash, Cards, Multi-tender).
   - Real-time shift header bar with Cash In / Cash Out logging and Blind Cash Count drawer.
   - Shift Audit register with automatic over/short detection and thermal Z-Report receipt printing.
   - Supervisor shift reopen capabilities with audit trails.

2. **Master Data & Pricing (Pages 210, 220):**
   - Multi-level item master with variants (Size, Color, SKU, Barcode).
   - Priority-based price lists with multi-branch overriding and zero-failure pricing fallbacks.

3. **Inventory Management & Inter-Branch Transfers (Page 230):**
   - Live stock balances across all subinventories with automatic after-insert DB balance updates.
   - Stock receipts (Insert-only with mandatory reversal audit).
   - Full lifecycle stock transfers (Draft -> Approved -> Shipped -> Received) with security line locking.

4. **General Ledger & Financial Accounting (Page 240):**
   - Dynamic Chart of Accounts (COA) with live debit/credit balances.
   - GL journal entries with automatic balanced validation and compound triggers.
   - One-click posting (Post) and reversible adjustment journals (Reverse) with reason enforcement.

5. **Multi-Tenancy Security & Custom Authentication:**
   - Data isolation views (`POS_USER_PERMITTED_LE_V` & `POS_USER_PERMITTED_ORG_V`).
   - Secure custom authentication backed by `POS_APP_USERS` and application items session context.

---

## 📖 Documentation & Handover

For complete setup instructions and developer handover guide to continue on any other workstation, refer to:
- 📘 **[HANDOVER_AND_CONTINUATION_GUIDE.md](./HANDOVER_AND_CONTINUATION_GUIDE.md)**
- 📁 **Detailed Guides in [`docs/`](./docs/)**:
  - `page210_guide.md`
  - `page220_guide.md`
  - `page230_stock_receipt_complete.md`
  - `page230_transfers_complete.md`
  - `page240_detailed_guide.md`
  - `pages_240_250_guide.md`
  - `security_architecture.md`

---

## 🗄️ Database Architecture
- Core PL/SQL Engine: `packages/PKG_POS_CORE.pks` & `packages/PKG_POS_CORE.pkb`
- Cumulative Security & Trigger Patches: `ddl/10_security_triggers_and_patches.sql`
