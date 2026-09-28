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
  - `page210_guide.md` (Item Master & Matrix Variants)
  - `page220_guide.md` (Pricing & Promotions)
  - `page230_stock_receipt_complete.md` & `page230_transfers_complete.md` (Inventory & Transfers)
  - `page240_detailed_guide.md` & `pages_240_250_guide.md` (GL Journals & Shift Audit)
  - `page300_users_access_guide.md` (Users & Security Access)
  - `page310_org_setup_guide.md` (Multi-Org Hierarchy & Terminals)
  - `page320_customers_guide.md` (Customers CRM & Credit Control)
  - `page330_suppliers_guide.md` (Suppliers & Purchase Orders)
  - `page340_ar_guide.md` (Accounts Receivable & Aging)
  - `page350_ap_guide.md` (Accounts Payable & 3-Way Match)
  - `page360_coa_periods_guide.md` (COA Tree, Segments & Fiscal Periods)
  - `page370_sla_rules_guide.md` (Subledger Accounting Rules Engine)
  - `page380_tax_config_guide.md` (Tax Regimes, Rates & Rules)
  - `page390_cycle_count_guide.md` (Cycle Count & Variance Audit)
  - `page400_loyalty_guide.md` (Loyalty Programs & Point Ledgers)
  - `page410_promotions_guide.md` (Promotion Builder & Coupons)
  - `page420_430_settings_audit_guide.md` (App Settings, ESC/POS Templates, Audit Log & Offline Sync)
  - `security_architecture.md` (Multi-Tenancy Security Matrix)

---

## 🗄️ Database Architecture
- Core PL/SQL Engine: `packages/PKG_POS_CORE.pks` & `packages/PKG_POS_CORE.pkb`
- Cumulative Security & Trigger Patches: `ddl/10_security_triggers_and_patches.sql`
