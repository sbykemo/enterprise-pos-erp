# 🧠 MEMORY.md — Project Architectural Decisions & Session Context

## Environment
- **Platform:** Oracle APEX 26.1 on OCI Autonomous Database (19c/23ai)
- **Workspace:** `dev` | **App ID:** `102` | **Schema:** `POS`
- **APEX URL:** `https://ga06096b0992795-adminkemo.adb.us-ashburn-1.oraclecloudapps.com/ords`
- **GitHub:** `https://github.com/sbykemo/enterprise-pos-erp.git` | **Branch:** `main`

---

## Architectural Decisions Log

### AD-001: POS_SHIFTS uses TIMESTAMP(6) not DATE
- `OPEN_DATETIME` and `CLOSE_DATETIME` are `TIMESTAMP(6)`.
- Must use `CAST(... AS DATE)` for arithmetic and `SYSTIMESTAMP` for NVL defaults.

### AD-002: Number formatting in APEX items
- APEX items with format masks include commas. Must clean with `REGEXP_REPLACE(val, '[^0-9\.]', '')` before `TO_NUMBER()`.

### AD-003: APEX 26.1 MLE restriction
- `Execute Server-Side Code` uses GraalJS on DB server.
- Use `Execute JavaScript Code` (client-side) for browser operations like `window.print()`.

### AD-004: Inline Dialog opening syntax
- Use `$('#static_id').dialog('open')` — NOT `apex.theme.closeRegion()`.

### AD-005: Submit Page triggers all validations
- Use `Defined by Dynamic Action` for dialog-opening buttons to avoid unintended validation triggers.

### AD-006: Multi-Tenant Data Isolation Pattern
- Use `INSTR(',' || :AI_ORG_LIST || ',', ',' || TO_CHAR(INV_ORG_ID) || ',') > 0` for branch filtering.
- Wrapping with commas prevents partial number matching (e.g., `10` matching inside `100`).

### AD-007: Master-Detail in Interactive Grid
- Use APEX native **Declarative Master-Detail** (set Master Region + Master Column on detail IG) instead of JavaScript/Dynamic Actions for linking grids. More reliable and auto-fills FK on new rows.

### AD-008: Lookup Tables over Static LOVs for shared reference data
- Created `POS_COUNTRIES`, `POS_CURRENCIES`, `POS_CITIES` as database lookup tables (not Static LOVs).
- Ensures referential integrity via FK, reuse across 12+ tables, admin self-service, and correct BI reporting.
- Cities support Cascading LOV filtered by `COUNTRY_CODE`.

### AD-009: IR + Modal Form pattern for data-heavy screens
- Pages with many columns (15+) use **Interactive Report (Page N)** + **Modal Dialog Form (Page N+1)** pattern instead of a single wide Interactive Grid.
- Examples: Page 320/321 (Customers), Page 330/331 (Suppliers).

### AD-010: Dialog Closed refresh pattern
- After Modal Dialog closes, parent page needs a **Dynamic Action** on `Dialog Closed` event (Selection Type: JavaScript Expression → `window`) to refresh the IR and KPI cards.
- APEX Wizard auto-creates this DA only when Report+Form are created together; must add manually when pages are created separately.

### AD-011: Show Processing on Modal save buttons
- Set **Show Processing = No** on Create/Save buttons in Modal Dialog pages to prevent the full-screen spinner overlay on save.

### AD-012: Virtual Generated Columns in POS_CYCLE_COUNT_LINES
- `VARIANCE_QTY` and `VARIANCE_VALUE` are computed virtual columns — cannot be inserted/updated directly.

---

## Security Architecture

### Authorization Schemes
| Scheme | Who Can Access |
|---|---|
| `AUTH_POS_USER` | Everyone (all roles) |
| `AUTH_NOT_CASHIER` | All except CASHIER |
| `AUTH_MANAGER_UP` | SYSADMIN, ORG_ADMIN, BRANCH_MANAGER |
| `AUTH_FINANCE_ONLY` | SYSADMIN, ORG_ADMIN (finance roles) |

### Page Authorization Matrix
| Pages | Authorization |
|---|---|
| 100, 101 | AUTH_POS_USER |
| 200, 210 | AUTH_NOT_CASHIER |
| 220, 250 | AUTH_MANAGER_UP |
| 230 | AUTH_NOT_CASHIER |
| 240 | AUTH_FINANCE_ONLY |
| 300, 310 | AUTH_MANAGER_UP |
| 320, 330 | AUTH_NOT_CASHIER |
| 340, 350, 360, 370, 380 | AUTH_FINANCE_ONLY |
| 390 | AUTH_MANAGER_UP |
| 400, 410 | AUTH_NOT_CASHIER |
| 420, 430 | AUTH_MANAGER_UP |

---

## Completed Pages
- **Page 100:** Cashier POS Terminal (barcode, cart, payments, shift bar)
- **Page 101:** Split Tender Modal
- **Page 200:** Executive Dashboard (KPIs)
- **Page 210:** Item Master & Variants
- **Page 220:** Pricing & Promotions
- **Page 230:** Inventory Management (receipts, transfers lifecycle)
- **Page 240:** GL Journals & Financials (COA tree, posting, reversal)
- **Page 250:** Shift Audit & Z-Report (thermal receipt, reopen shift)
- **Page 300:** Users & Access Control (Master-Detail IG, native linking)
- **Page 310:** Org Setup (4-tab: Legal Entities, OUs, Inv Orgs+Subinv, Terminals)
- **Page 320/321:** Customers (IR + Modal Dialog Form with KPI cards, cascading city LOV)
- **Page 330/331:** Suppliers & Purchase Orders (in progress)

## Database Objects
- **66 tables** across 8 DDL files + `11_lookup_tables_geo_currencies.sql`
- **5 PL/SQL packages:** PKG_POS_CORE, PKG_TAX_ENGINE, PKG_INV_ENGINE, PKG_ACCOUNTING_ENGINE, PKG_OFFLINE_SYNC
- **Lookup tables:** POS_COUNTRIES, POS_CURRENCIES, POS_CITIES
- **Key triggers:** POS_INV_TXN_AFTER_INSERT, POS_GL_JOURNAL_LINES_CMP_TRG

## Bug Resolutions
- **CASH_MOVEMENTS_COUNT fix (Page 250):** Button was showing invoice count instead of cash movement count. Fixed by querying POS_SHIFT_CASH_MOVEMENTS instead of POS_ORDERS.
- **REOPEN_SHIFT missing from source:** Procedure existed in live DB but was missing from PKG_POS_CORE source files. Synced and committed.
- **COA names inverted:** ACCOUNT_NAME_AR and ACCOUNT_NAME_EN were swapped in seed data. Fixed with UPDATE swap query.
- **Terminal Type LOV mismatch:** Static LOV had `POS` but DB stored `CASHIER`. Fixed to match CHECK constraint.

---

*Last updated: 2026-09-30*
