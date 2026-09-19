# 🏗️ دليل البناء: Page 240 + Page 250
## المحاسبة والدفاتر + تقرير الوردية Z-Report

---

## 🗺️ الخريطة الكاملة للصفحتين

```
Page 240 - GL & Financials
├── Section A: دليل الحسابات (Chart of Accounts)
├── Section B: قيود اليومية (GL Journals)
│   └── Sub: بنود القيد (Journal Lines)
├── Section C: فواتير العملاء (AR Invoices)
└── Section D: أوامر الشراء (Purchase Orders)
    └── Sub: بنود الأمر (PO Lines)

Page 250 - Shift Audit & Z-Report
├── Section A: سجل الورديات (Shifts Register)
├── Section B: حركات النقدية (Cash Movements)
└── Section C: تقرير Z الكامل (Z-Report مطبوع)
```

---

# ═══════════════════════════════════════
# PAGE 240: GL Journals & Financials
# ═══════════════════════════════════════

## ⚙️ المرحلة 0: Seed Data لدليل الحسابات (SQL Commands)

```sql
-- ===== الكيان القانوني =====
INSERT INTO POS_LEGAL_ENTITIES (
    LEGAL_ENTITY_ID, LEGAL_ENTITY_CODE, LEGAL_ENTITY_NAME,
    COUNTRY_CODE, CURRENCY_CODE, IS_ACTIVE
) VALUES (
    1000001, 'LE-KSA-001', 'شركة المتجر المتحدة',
    'SA', 'SAR', 'Y'
);

-- ===== الفترة المحاسبية الحالية =====
INSERT INTO POS_GL_PERIODS (
    PERIOD_ID, LEGAL_ENTITY_ID, PERIOD_NAME,
    PERIOD_YEAR, PERIOD_NUM,
    START_DATE, END_DATE, CLOSE_STATUS
) VALUES (
    1000001, 1000001, 'SEP-2026',
    2026, 9,
    DATE '2026-09-01', DATE '2026-09-30', 'OPEN'
);

-- ===== دليل الحسابات الأساسي =====
-- حسابات الأصول
INSERT INTO POS_COA_ACCOUNTS VALUES (1000001,'1-0000-000',NULL,NULL,NULL,NULL,'الأصول','Assets','ASSET','DEBIT',NULL,1,'N','N','N','Y',1000001,1,SYSDATE,1,SYSDATE);
INSERT INTO POS_COA_ACCOUNTS VALUES (1000002,'1-1100-000',NULL,NULL,NULL,NULL,'النقدية','Cash','ASSET','DEBIT',1000001,2,'Y','Y','Y','Y',1000001,1,SYSDATE,1,SYSDATE);
INSERT INTO POS_COA_ACCOUNTS VALUES (1000003,'1-1200-000',NULL,NULL,NULL,NULL,'العملاء','Accounts Receivable','ASSET','DEBIT',1000001,2,'Y','N','Y','Y',1000001,1,SYSDATE,1,SYSDATE);
INSERT INTO POS_COA_ACCOUNTS VALUES (1000004,'1-2000-000',NULL,NULL,NULL,NULL,'المخزون','Inventory','ASSET','DEBIT',1000001,2,'Y','N','Y','Y',1000001,1,SYSDATE,1,SYSDATE);

-- حسابات الالتزامات
INSERT INTO POS_COA_ACCOUNTS VALUES (1000005,'2-0000-000',NULL,NULL,NULL,NULL,'الالتزامات','Liabilities','LIABILITY','CREDIT',NULL,1,'N','N','N','Y',1000001,1,SYSDATE,1,SYSDATE);
INSERT INTO POS_COA_ACCOUNTS VALUES (1000006,'2-1000-000',NULL,NULL,NULL,NULL,'الموردون','Accounts Payable','LIABILITY','CREDIT',1000005,2,'Y','Y','Y','Y',1000001,1,SYSDATE,1,SYSDATE);
INSERT INTO POS_COA_ACCOUNTS VALUES (1000007,'2-2000-000',NULL,NULL,NULL,NULL,'ضريبة القيمة المضافة','VAT Payable','LIABILITY','CREDIT',1000005,2,'Y','N','Y','Y',1000001,1,SYSDATE,1,SYSDATE);

-- حسابات الإيرادات
INSERT INTO POS_COA_ACCOUNTS VALUES (1000008,'4-0000-000',NULL,NULL,NULL,NULL,'الإيرادات','Revenue','REVENUE','CREDIT',NULL,1,'N','N','N','Y',1000001,1,SYSDATE,1,SYSDATE);
INSERT INTO POS_COA_ACCOUNTS VALUES (1000009,'4-1000-000',NULL,NULL,NULL,NULL,'إيرادات المبيعات','Sales Revenue','REVENUE','CREDIT',1000008,2,'Y','N','N','Y',1000001,1,SYSDATE,1,SYSDATE);

-- حسابات المصاريف
INSERT INTO POS_COA_ACCOUNTS VALUES (1000010,'5-0000-000',NULL,NULL,NULL,NULL,'المصاريف','Expenses','EXPENSE','DEBIT',NULL,1,'N','N','N','Y',1000001,1,SYSDATE,1,SYSDATE);
INSERT INTO POS_COA_ACCOUNTS VALUES (1000011,'5-1000-000',NULL,NULL,NULL,NULL,'تكلفة البضاعة المباعة','Cost of Goods Sold','EXPENSE','DEBIT',1000010,2,'Y','N','N','Y',1000001,1,SYSDATE,1,SYSDATE);

COMMIT;
```

---

## 🏗️ المرحلة 1: Page 240 — الإعدادات العامة

* **Page Number:** `240`
* **Name:** `GL Journals & Financials`
* **Page Mode:** `Normal`
* **Template:** `Left Side Column`

### Page Items:

| الاسم | النوع | Label |
|---|---|---|
| `P240_SELECTED_JOURNAL_ID` | `Hidden` | — |
| `P240_SELECTED_PO_ID` | `Hidden` | — |
| `P240_LE_FILTER` | `Select List` | **الكيان القانوني** |
| `P240_PERIOD_FILTER` | `Select List` | **الفترة المحاسبية** |
| `P240_STATUS_FILTER` | `Select List` | **حالة القيد** |

**LOV لـ `P240_LE_FILTER`:**
```sql
SELECT LEGAL_ENTITY_NAME D, LEGAL_ENTITY_ID R
FROM POS_LEGAL_ENTITIES WHERE IS_ACTIVE = 'Y'
```

**LOV لـ `P240_PERIOD_FILTER`:**
```sql
SELECT PERIOD_NAME || ' (' || CLOSE_STATUS || ')' D, PERIOD_ID R
FROM POS_GL_PERIODS
WHERE LEGAL_ENTITY_ID = NVL(:P240_LE_FILTER, LEGAL_ENTITY_ID)
ORDER BY PERIOD_YEAR DESC, PERIOD_NUM DESC
```

**LOV لـ `P240_STATUS_FILTER`:**
```sql
SELECT D, R FROM (
    SELECT 'الكل' D, NULL R, 0 S FROM DUAL UNION ALL
    SELECT '📝 مسودة' D, 'DRAFT' R, 1 S FROM DUAL UNION ALL
    SELECT '✅ مُرحَّل' D, 'POSTED' R, 2 S FROM DUAL UNION ALL
    SELECT '🔄 معكوس' D, 'REVERSED' R, 3 S FROM DUAL
) ORDER BY S
```

---

## 🏗️ المرحلة 2: Section A — دليل الحسابات

### منطقة `coa_reg`:
* **Title:** `📊 دليل الحسابات (Chart of Accounts)`
* **Type:** `Interactive Report`
* **Static ID:** `coa_reg`

```sql
SELECT
    a.ACCOUNT_ID,
    LPAD(' ', (a.ACCOUNT_LEVEL - 1) * 4, ' ') || a.ACCOUNT_CODE AS ACCOUNT_CODE_INDENTED,
    a.ACCOUNT_NAME_AR,
    a.ACCOUNT_NAME_EN,
    CASE a.ACCOUNT_TYPE
        WHEN 'ASSET'     THEN '🏦 أصول'
        WHEN 'LIABILITY' THEN '📋 التزامات'
        WHEN 'EQUITY'    THEN '💰 حقوق ملكية'
        WHEN 'REVENUE'   THEN '📈 إيرادات'
        WHEN 'EXPENSE'   THEN '📉 مصاريف'
        WHEN 'CONTRA'    THEN '🔄 مقابل'
    END AS ACCOUNT_TYPE_LABEL,
    a.NORMAL_BALANCE,
    a.ACCOUNT_LEVEL,
    CASE a.IS_DETAIL WHEN 'Y' THEN '✅' ELSE '—' END AS IS_DETAIL_ICON,
    -- الرصيد الجاري = المدين - الدائن من بنود اليومية المرحّلة
    NVL((
        SELECT SUM(l.DEBIT_AMOUNT - l.CREDIT_AMOUNT)
        FROM POS_GL_JOURNAL_LINES l
        JOIN POS_GL_JOURNALS j ON j.JOURNAL_ID = l.JOURNAL_ID
        WHERE l.ACCOUNT_ID = a.ACCOUNT_ID
          AND j.STATUS = 'POSTED'
          AND j.LEGAL_ENTITY_ID = a.LEGAL_ENTITY_ID
    ), 0) AS CURRENT_BALANCE
FROM POS_COA_ACCOUNTS a
WHERE a.LEGAL_ENTITY_ID = NVL(:P240_LE_FILTER, a.LEGAL_ENTITY_ID)
  AND a.IS_ACTIVE = 'Y'
ORDER BY a.ACCOUNT_CODE
```

---

## 🏗️ المرحلة 3: Section B — قيود اليومية

### منطقة `journals_reg`:
* **Title:** `📒 قيود اليومية (GL Journals)`
* **Type:** `Interactive Grid`
* **Static ID:** `journals_reg`

```sql
SELECT
    j.JOURNAL_ID,
    j.JOURNAL_NO,
    j.LEGAL_ENTITY_ID,
    le.LEGAL_ENTITY_NAME,
    j.PERIOD_ID,
    p.PERIOD_NAME,
    j.JOURNAL_DATE,
    j.SOURCE,
    CASE j.SOURCE
        WHEN 'POS_SALE'    THEN '🛒 مبيعات POS'
        WHEN 'POS_RETURN'  THEN '↩️ مرتجعات'
        WHEN 'POS_SHIFT'   THEN '🕐 وردية'
        WHEN 'INVENTORY'   THEN '📦 مخزون'
        WHEN 'AP'          THEN '💸 موردون'
        WHEN 'AR'          THEN '💰 عملاء'
        WHEN 'MANUAL'      THEN '✏️ يدوي'
    END AS SOURCE_LABEL,
    j.DESCRIPTION,
    j.CURRENCY_CODE,
    j.TOTAL_DEBIT,
    j.TOTAL_CREDIT,
    j.STATUS,
    CASE j.STATUS
        WHEN 'DRAFT'    THEN '📝 مسودة'
        WHEN 'POSTED'   THEN '✅ مُرحَّل'
        WHEN 'REVERSED' THEN '🔄 معكوس'
        WHEN 'ERROR'    THEN '❌ خطأ'
    END AS STATUS_LABEL,
    j.POSTED_DATE,
    -- عدد بنود القيد
    (SELECT COUNT(*) FROM POS_GL_JOURNAL_LINES l WHERE l.JOURNAL_ID = j.JOURNAL_ID) AS LINES_COUNT,
    -- توازن القيد (المدين = الدائن)
    CASE WHEN NVL(j.TOTAL_DEBIT,0) = NVL(j.TOTAL_CREDIT,0) THEN '✅ متوازن'
         ELSE '⚠️ غير متوازن (' || TO_CHAR(ABS(NVL(j.TOTAL_DEBIT,0) - NVL(j.TOTAL_CREDIT,0)),'999,990.00') || ')'
    END AS BALANCE_STATUS,
    -- هل القيد قابل للترحيل؟
    CASE WHEN j.STATUS = 'DRAFT' AND NVL(j.TOTAL_DEBIT,0) = NVL(j.TOTAL_CREDIT,0) THEN 'Y' ELSE 'N' END AS CAN_POST,
    -- هل القيد قابل للعكس؟
    CASE WHEN j.STATUS = 'POSTED' THEN 'Y' ELSE 'N' END AS CAN_REVERSE,
    -- أزرار إظهار/إخفاء
    CASE WHEN j.STATUS = 'DRAFT' AND NVL(j.TOTAL_DEBIT,0) = NVL(j.TOTAL_CREDIT,0) THEN 'inline-block' ELSE 'none' END AS SHOW_POST,
    CASE WHEN j.STATUS = 'POSTED' THEN 'inline-block' ELSE 'none' END AS SHOW_REVERSE
FROM POS_GL_JOURNALS j
JOIN POS_LEGAL_ENTITIES le ON le.LEGAL_ENTITY_ID = j.LEGAL_ENTITY_ID
JOIN POS_GL_PERIODS p ON p.PERIOD_ID = j.PERIOD_ID
WHERE j.LEGAL_ENTITY_ID = NVL(:P240_LE_FILTER, j.LEGAL_ENTITY_ID)
  AND j.PERIOD_ID        = NVL(:P240_PERIOD_FILTER, j.PERIOD_ID)
  AND j.STATUS           = NVL(:P240_STATUS_FILTER, j.STATUS)
ORDER BY j.JOURNAL_DATE DESC, j.JOURNAL_ID DESC
```

### إعدادات الأعمدة المهمة:

| العمود | النوع | إعدادات |
|---|---|---|
| `JOURNAL_ID` | Hidden | PK |
| `JOURNAL_NO` | Plain Text | Query Only: **ON** |
| `LEGAL_ENTITY_ID` | Select List | LOV: POS_LEGAL_ENTITIES |
| `PERIOD_ID` | Select List | LOV: POS_GL_PERIODS |
| `JOURNAL_DATE` | Date Picker | Default: Today |
| `SOURCE` | Select List | LOV: Static (POS_SALE, MANUAL, INVENTORY...) |
| `SOURCE_LABEL` | Hidden | Query Only: **ON** |
| `DESCRIPTION` | Text Field | Max Length: 500 |
| `CURRENCY_CODE` | Text Field | Default: `SAR` |
| `TOTAL_DEBIT` | Plain Text | Query Only: **ON** |
| `TOTAL_CREDIT` | Plain Text | Query Only: **ON** |
| `STATUS` | Hidden | Query Only: **ON** / Default: `DRAFT` |
| `STATUS_LABEL` | Plain Text | Query Only: **ON** |
| `LINES_COUNT` | Plain Text | Query Only: **ON** |
| `BALANCE_STATUS` | Plain Text | Query Only: **ON** |
| `CAN_POST` | Hidden | Query Only: **ON** |
| `CAN_REVERSE` | Hidden | Query Only: **ON** |
| `SHOW_POST` | Hidden | Query Only: **ON** |
| `SHOW_REVERSE` | Hidden | Query Only: **ON** |
| `إجراءات` | HTML Expression | *(كود الأزرار أدناه)* |

**HTML Expression لعمود الإجراءات:**
```html
<div style="display:flex;gap:4px;flex-wrap:wrap;">
  <button type="button" class="t-Button t-Button--small t-Button--primary"
    onclick="showJournalLines(this,&JOURNAL_ID.,'&JOURNAL_NO.');">
    📋 بنود (&LINES_COUNT.)
  </button>
  <button type="button" class="t-Button t-Button--small t-Button--success"
    onclick="doJournalAction(this,&JOURNAL_ID.,'POST');"
    style="display:&SHOW_POST.;">
    ✅ ترحيل
  </button>
  <button type="button" class="t-Button t-Button--small t-Button--danger"
    onclick="doJournalAction(this,&JOURNAL_ID.,'REVERSE');"
    style="display:&SHOW_REVERSE.;">
    🔄 عكس
  </button>
</div>
```

### إعدادات Edit:
| الخاصية | القيمة |
|---|---|
| **Add Row** | ✅ Yes |
| **Update Row** | ❌ No (التحديث عبر أزرار الإجراءات فقط) |
| **Delete Row** | ❌ No |

---

## 🏗️ المرحلة 4: Section B-2 — بنود القيد

### منطقة `journal_lines_reg`:
* **Title:** `📋 بنود القيد المحدد (Journal Lines)`
* **Type:** `Interactive Grid`
* **Static ID:** `journal_lines_reg`

```sql
SELECT
    l.JOURNAL_LINE_ID,
    l.JOURNAL_ID,
    l.LINE_NO,
    l.ACCOUNT_ID,
    a.ACCOUNT_CODE,
    a.ACCOUNT_NAME_AR,
    a.ACCOUNT_TYPE,
    l.DESCRIPTION,
    l.DEBIT_AMOUNT,
    l.CREDIT_AMOUNT,
    l.INV_ORG_ID,
    io.INV_ORG_NAME,
    l.REFERENCE1,
    -- حالة الترحيل (مورثة من رأس القيد)
    (SELECT j.STATUS FROM POS_GL_JOURNALS j WHERE j.JOURNAL_ID = l.JOURNAL_ID) AS JOURNAL_STATUS,
    CASE WHEN (SELECT j.STATUS FROM POS_GL_JOURNALS j WHERE j.JOURNAL_ID = l.JOURNAL_ID) = 'DRAFT'
         THEN 'Y' ELSE 'N' END AS IS_EDITABLE
FROM POS_GL_JOURNAL_LINES l
JOIN POS_COA_ACCOUNTS a ON a.ACCOUNT_ID = l.ACCOUNT_ID
LEFT JOIN POS_INVENTORY_ORGS io ON io.INV_ORG_ID = l.INV_ORG_ID
WHERE l.JOURNAL_ID = NVL(:P240_SELECTED_JOURNAL_ID, -1)
ORDER BY l.LINE_NO
```

### إعدادات الأعمدة:

| العمود | النوع | إعدادات |
|---|---|---|
| `JOURNAL_LINE_ID` | Hidden | PK |
| `JOURNAL_ID` | Hidden | Default: `Item = P240_SELECTED_JOURNAL_ID` / Query Only: **OFF** |
| `LINE_NO` | Plain Text | Query Only: **ON** |
| `ACCOUNT_ID` | Select List | LOV: `SELECT ACCOUNT_CODE \|\| ' - ' \|\| ACCOUNT_NAME_AR D, ACCOUNT_ID R FROM POS_COA_ACCOUNTS WHERE IS_ACTIVE='Y' AND IS_DETAIL='Y' ORDER BY ACCOUNT_CODE` |
| `ACCOUNT_CODE` | Plain Text | Query Only: **ON** |
| `ACCOUNT_NAME_AR` | Plain Text | Query Only: **ON** |
| `DESCRIPTION` | Text Field | |
| `DEBIT_AMOUNT` | Number Field | Format: `999,990.00` / Default: `0` |
| `CREDIT_AMOUNT` | Number Field | Format: `999,990.00` / Default: `0` |
| `INV_ORG_ID` | Select List | LOV: POS_INVENTORY_ORGS |
| `INV_ORG_NAME` | Plain Text | Query Only: **ON** |
| `REFERENCE1` | Text Field | |
| `JOURNAL_STATUS` | Hidden | Query Only: **ON** |
| `IS_EDITABLE` | Hidden | Query Only: **ON** |

**Allowed Row Operations Column:** `IS_EDITABLE`

---

## 🏗️ المرحلة 5: Ajax Callbacks لـ Page 240

### Callback 1: `SET_JOURNAL_SESSION`
```sql
BEGIN
    apex_util.set_session_state('P240_SELECTED_JOURNAL_ID', apex_application.g_x01);
    apex_json.open_object;
    apex_json.write('success', true);
    apex_json.close_object;
END;
```

---

### Callback 2: `PROCESS_JOURNAL_ACTION` (POST / REVERSE)

```sql
DECLARE
    v_journal_id NUMBER       := TO_NUMBER(apex_application.g_x01);
    v_action     VARCHAR2(10) := apex_application.g_x02;
    v_reason     VARCHAR2(500):= apex_application.g_x03;
    v_journal    POS_GL_JOURNALS%ROWTYPE;
    v_new_jnl_id NUMBER;
    v_total_dr   NUMBER;
    v_total_cr   NUMBER;
    v_period_id  NUMBER;
BEGIN
    SELECT * INTO v_journal FROM POS_GL_JOURNALS WHERE JOURNAL_ID = v_journal_id FOR UPDATE;

    -- =====================
    -- POST: ترحيل القيد
    -- =====================
    IF v_action = 'POST' THEN
        IF v_journal.STATUS != 'DRAFT' THEN
            apex_json.open_object;
            apex_json.write('success', false);
            apex_json.write('message', '⚠️ لا يمكن ترحيل قيد بحالة: ' || v_journal.STATUS);
            apex_json.close_object;
            RETURN;
        END IF;

        -- التحقق من التوازن
        SELECT NVL(SUM(DEBIT_AMOUNT),0), NVL(SUM(CREDIT_AMOUNT),0)
          INTO v_total_dr, v_total_cr
          FROM POS_GL_JOURNAL_LINES
         WHERE JOURNAL_ID = v_journal_id;

        IF v_total_dr != v_total_cr THEN
            apex_json.open_object;
            apex_json.write('success', false);
            apex_json.write('message', '⚠️ القيد غير متوازن! المدين: ' || v_total_dr || ' / الدائن: ' || v_total_cr);
            apex_json.close_object;
            RETURN;
        END IF;

        IF v_total_dr = 0 THEN
            apex_json.open_object;
            apex_json.write('success', false);
            apex_json.write('message', '⚠️ لا يمكن ترحيل قيد بمبلغ صفر!');
            apex_json.close_object;
            RETURN;
        END IF;

        UPDATE POS_GL_JOURNALS
           SET STATUS       = 'POSTED',
               TOTAL_DEBIT  = v_total_dr,
               TOTAL_CREDIT = v_total_cr,
               POSTED_BY    = TO_NUMBER(NVL(V('APP_USER_ID'), 1)),
               POSTED_DATE  = SYSDATE,
               LAST_UPDATE_DATE = SYSDATE
         WHERE JOURNAL_ID = v_journal_id;

        COMMIT;
        apex_json.open_object;
        apex_json.write('success', true);
        apex_json.write('message', '✅ تم ترحيل القيد رقم ' || v_journal.JOURNAL_NO || ' بنجاح!');
        apex_json.close_object;

    -- =====================
    -- REVERSE: عكس القيد
    -- =====================
    ELSIF v_action = 'REVERSE' THEN
        IF v_journal.STATUS != 'POSTED' THEN
            apex_json.open_object;
            apex_json.write('success', false);
            apex_json.write('message', '⚠️ لا يمكن عكس قيد غير مُرحَّل!');
            apex_json.close_object;
            RETURN;
        END IF;

        -- إيجاد الفترة الحالية المفتوحة
        SELECT PERIOD_ID INTO v_period_id
          FROM POS_GL_PERIODS
         WHERE LEGAL_ENTITY_ID = v_journal.LEGAL_ENTITY_ID
           AND CLOSE_STATUS = 'OPEN'
           AND SYSDATE BETWEEN START_DATE AND END_DATE
           AND ROWNUM = 1;

        -- إنشاء قيد الستورنو (Reversing Entry)
        INSERT INTO POS_GL_JOURNALS (
            JOURNAL_NO, LEGAL_ENTITY_ID, PERIOD_ID, JOURNAL_DATE,
            SOURCE, CATEGORY, DESCRIPTION, CURRENCY_CODE,
            EXCHANGE_RATE, STATUS, REFERENCE_TYPE, REFERENCE_ID,
            REVERSAL_JOURNAL_ID
        ) VALUES (
            'REV-' || v_journal.JOURNAL_NO,
            v_journal.LEGAL_ENTITY_ID,
            v_period_id,
            SYSDATE,
            v_journal.SOURCE, v_journal.CATEGORY,
            'عكس القيد: ' || v_journal.JOURNAL_NO || ' | ' || NVL(v_reason, '—'),
            v_journal.CURRENCY_CODE,
            NVL(v_journal.EXCHANGE_RATE, 1),
            'DRAFT', 'GL_REVERSAL', v_journal_id,
            v_journal_id
        ) RETURNING JOURNAL_ID INTO v_new_jnl_id;

        -- نسخ البنود مع عكس المدين والدائن
        INSERT INTO POS_GL_JOURNAL_LINES (
            JOURNAL_ID, LINE_NO, ACCOUNT_ID,
            DEBIT_AMOUNT, CREDIT_AMOUNT,
            DESCRIPTION, INV_ORG_ID, REFERENCE1
        )
        SELECT v_new_jnl_id, LINE_NO, ACCOUNT_ID,
               CREDIT_AMOUNT,  -- الدائن يصبح مديناً
               DEBIT_AMOUNT,   -- المدين يصبح دائناً
               'عكس: ' || DESCRIPTION,
               INV_ORG_ID, REFERENCE1
          FROM POS_GL_JOURNAL_LINES
         WHERE JOURNAL_ID = v_journal_id;

        -- تأشير القيد الأصلي كمعكوس
        UPDATE POS_GL_JOURNALS
           SET STATUS = 'REVERSED', LAST_UPDATE_DATE = SYSDATE
         WHERE JOURNAL_ID = v_journal_id;

        COMMIT;
        apex_json.open_object;
        apex_json.write('success', true);
        apex_json.write('newJournalId', v_new_jnl_id);
        apex_json.write('message', '🔄 تم إنشاء قيد عكسي جديد. يمكن مراجعته وترحيله من القائمة.');
        apex_json.close_object;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        apex_json.open_object;
        apex_json.write('success', false);
        apex_json.write('message', 'خطأ: ' || SQLERRM);
        apex_json.close_object;
END;
```

---

### Callback 3: `JOURNAL_BIR_TRIGGER` في قاعدة البيانات:

```sql
CREATE OR REPLACE TRIGGER POS_GL_JOURNALS_BIR
BEFORE INSERT ON POS_GL_JOURNALS
FOR EACH ROW
BEGIN
    IF :NEW.JOURNAL_ID IS NULL THEN
        SELECT NVL(MAX(JOURNAL_ID), 1000000)+1 INTO :NEW.JOURNAL_ID FROM POS_GL_JOURNALS;
    END IF;
    IF :NEW.JOURNAL_NO IS NULL THEN
        :NEW.JOURNAL_NO := 'JNL-' || TO_CHAR(SYSDATE,'YYYYMM') || '-' ||
                           LPAD(:NEW.JOURNAL_ID - 1000000, 6, '0');
    END IF;
    IF :NEW.STATUS IS NULL THEN :NEW.STATUS := 'DRAFT'; END IF;
    IF :NEW.CREATION_DATE IS NULL THEN :NEW.CREATION_DATE := SYSDATE; END IF;
    :NEW.LAST_UPDATE_DATE := SYSDATE;
END;
/

CREATE OR REPLACE TRIGGER POS_GL_JNL_LINES_BIR
BEFORE INSERT ON POS_GL_JOURNAL_LINES
FOR EACH ROW
DECLARE v_line NUMBER;
BEGIN
    IF :NEW.JOURNAL_LINE_ID IS NULL THEN
        SELECT NVL(MAX(JOURNAL_LINE_ID),1000000)+1 INTO :NEW.JOURNAL_LINE_ID FROM POS_GL_JOURNAL_LINES;
    END IF;
    IF :NEW.LINE_NO IS NULL THEN
        SELECT NVL(MAX(LINE_NO),0)+1 INTO v_line FROM POS_GL_JOURNAL_LINES WHERE JOURNAL_ID = :NEW.JOURNAL_ID;
        :NEW.LINE_NO := v_line;
    END IF;
    IF :NEW.DEBIT_AMOUNT IS NULL THEN :NEW.DEBIT_AMOUNT := 0; END IF;
    IF :NEW.CREDIT_AMOUNT IS NULL THEN :NEW.CREDIT_AMOUNT := 0; END IF;
    IF :NEW.CREATION_DATE IS NULL THEN :NEW.CREATION_DATE := SYSDATE; END IF;
    :NEW.LAST_UPDATE_DATE := SYSDATE;
END;
/
```

---

## 🏗️ المرحلة 6: JavaScript لـ Page 240

```javascript
// ==========================================================
// PAGE 240 — GL JOURNALS CONTROLLER (ERP Standard)
// ==========================================================

// عرض بنود القيد
window.showJournalLines = function(pBtn, journalId, journalNo) {
    if (pBtn) {
        var $tr = $(pBtn).closest('tr');
        $tr.siblings().removeClass('is-selected');
        $tr.addClass('is-selected');
    }
    apex.item('P240_SELECTED_JOURNAL_ID').setValue(journalId);
    apex.server.process('SET_JOURNAL_SESSION', { x01: String(journalId) }, {
        dataType: 'json',
        success: function() {
            var el = document.getElementById('journal_lines_reg');
            if (el) {
                $(el).trigger('apexrefresh');
                setTimeout(function() { el.scrollIntoView({ behavior: 'smooth' }); }, 300);
            }
        }
    });
};

// ترحيل أو عكس القيد
window.doJournalAction = function(pBtn, journalId, action) {
    var reason = '';
    if (action === 'REVERSE') {
        reason = prompt('🔄 عكس القيد\nيرجى إدخال سبب العكس (إلزامي):', '');
        if (reason === null) return;
        if (!reason.trim()) {
            apex.message.showErrors([{ type:'error', location:'page', message:'⛔ يجب إدخال سبب العكس!' }]);
            return;
        }
    } else if (action === 'POST') {
        if (!confirm('✅ هل تريد ترحيل هذا القيد؟\nلن يمكن تعديله بعد الترحيل!')) return;
    }

    apex.server.process('PROCESS_JOURNAL_ACTION', {
        x01: String(journalId),
        x02: action,
        x03: reason.trim()
    }, {
        dataType: 'json',
        loadingIndicator: '#journals_reg',
        success: function(pData) {
            if (pData && pData.success) {
                apex.message.showPageSuccess(pData.message);
                ['journals_reg','journal_lines_reg','coa_reg'].forEach(function(id) {
                    var el = document.getElementById(id);
                    if (el) $(el).trigger('apexrefresh');
                });
            } else {
                apex.message.showErrors([{ type:'error', location:'page', message: pData ? pData.message : 'خطأ!' }]);
            }
        }
    });
};
```

---

# ═══════════════════════════════════════
# PAGE 250: Shift Audit & Z-Report
# ═══════════════════════════════════════

## 🏗️ Page 250 — الإعدادات العامة

* **Page Number:** `250`
* **Name:** `Shift Audit & Z-Report`
* **Template:** `Minimal (No Navigation Column)`

### Page Items:

| الاسم | النوع | Label |
|---|---|---|
| `P250_SELECTED_SHIFT_ID` | Hidden | — |
| `P250_ORG_FILTER` | Select List | **الفرع** |
| `P250_DATE_FROM` | Date Picker | **من تاريخ** |
| `P250_DATE_TO` | Date Picker | **إلى تاريخ** |
| `P250_STATUS_FILTER` | Select List | **حالة الوردية** |

---

## 🏗️ المرحلة 7: Section A — سجل الورديات

### منطقة `shifts_reg`:
* **Title:** `🕐 سجل الورديات (Shifts Register)`
* **Type:** `Interactive Grid`
* **Static ID:** `shifts_reg`

```sql
SELECT
    s.SHIFT_ID,
    s.SHIFT_NO,
    s.TERMINAL_ID,
    t.TERMINAL_NAME,
    s.INV_ORG_ID,
    io.INV_ORG_NAME,
    s.CASHIER_USER_ID,
    u.FULL_NAME_AR AS CASHIER_NAME,
    s.SHIFT_STATUS,
    CASE s.SHIFT_STATUS
        WHEN 'OPEN'        THEN '🟢 مفتوحة'
        WHEN 'SUSPENDED'   THEN '⏸️ موقوفة'
        WHEN 'CLOSED'      THEN '🔴 مغلقة'
        WHEN 'RECONCILED'  THEN '✅ مُسوَّاة'
    END AS STATUS_LABEL,
    s.OPEN_DATETIME,
    s.CLOSE_DATETIME,
    ROUND((CAST(NVL(s.CLOSE_DATETIME, SYSTIMESTAMP) AS DATE) - CAST(s.OPEN_DATETIME AS DATE)) * 24, 2) AS DURATION_HOURS,
    s.OPENING_FLOAT,
    s.TOTAL_SALES,
    s.TOTAL_REFUNDS,
    s.TOTAL_DISCOUNTS,
    s.TOTAL_TAX,
    s.TOTAL_CASH_IN,
    s.TOTAL_CASH_OUT,
    s.EXPECTED_CASH,
    s.DECLARED_CASH,
    NVL(s.DECLARED_CASH, 0) - NVL(s.EXPECTED_CASH, 0) AS OVER_SHORT,
    CASE
        WHEN s.SHIFT_STATUS IN ('OPEN','SUSPENDED') THEN 'وردية جارية'
        WHEN NVL(s.DECLARED_CASH,0) = NVL(s.EXPECTED_CASH,0) THEN '✅ مطابقة'
        WHEN NVL(s.DECLARED_CASH,0) > NVL(s.EXPECTED_CASH,0)  THEN '🟢 زائد ' || TO_CHAR(ABS(NVL(s.DECLARED_CASH,0)-NVL(s.EXPECTED_CASH,0)),'999,990.00')
        ELSE '🔴 عجز ' || TO_CHAR(ABS(NVL(s.DECLARED_CASH,0)-NVL(s.EXPECTED_CASH,0)),'999,990.00')
    END AS CASH_RECONCILE_LABEL,
    s.Z_REPORT_PRINTED,
    -- عدد الأوامر في الوردية
    (SELECT COUNT(*) FROM POS_ORDERS o WHERE o.SHIFT_ID = s.SHIFT_ID) AS ORDERS_COUNT,
    s.CLOSE_NOTES,
    -- للتحكم في الأزرار
    CASE WHEN s.SHIFT_STATUS = 'CLOSED' AND NVL(s.Z_REPORT_PRINTED,'N') = 'N' THEN 'inline-block' ELSE 'none' END AS SHOW_ZREPORT,
    CASE WHEN s.SHIFT_STATUS = 'CLOSED' THEN 'inline-block' ELSE 'none' END AS SHOW_RECONCILE
FROM POS_SHIFTS s
JOIN POS_POS_TERMINALS t ON t.TERMINAL_ID = s.TERMINAL_ID
JOIN POS_INVENTORY_ORGS io ON io.INV_ORG_ID = s.INV_ORG_ID
JOIN POS_APP_USERS u ON u.APP_USER_ID = s.CASHIER_USER_ID
WHERE s.INV_ORG_ID = NVL(:P250_ORG_FILTER, s.INV_ORG_ID)
  AND CAST(s.OPEN_DATETIME AS DATE) BETWEEN NVL(:P250_DATE_FROM, TRUNC(SYSDATE)-30) AND NVL(:P250_DATE_TO, TRUNC(SYSDATE)+1)
  AND s.SHIFT_STATUS = NVL(:P250_STATUS_FILTER, s.SHIFT_STATUS)
ORDER BY s.OPEN_DATETIME DESC
```

### عمود الإجراءات (HTML Expression):
```html
<div style="display:flex;gap:4px;flex-wrap:wrap;">
  <button type="button" class="t-Button t-Button--small t-Button--primary"
    onclick="showShiftDetails(this,&SHIFT_ID.);">
    📋 تفاصيل (&ORDERS_COUNT. أمر)
  </button>
  <button type="button" class="t-Button t-Button--small t-Button--warning"
    onclick="printZReport(&SHIFT_ID.,'&SHIFT_NO.');"
    style="display:&SHOW_ZREPORT.;">
    🖨️ Z-Report
  </button>
</div>
```

---

## 🏗️ المرحلة 8: Section B — حركات النقدية

### منطقة `cash_movements_reg`:
* **Title:** `💵 حركات النقدية في الوردية`
* **Type:** `Interactive Report`
* **Static ID:** `cash_movements_reg`

```sql
SELECT
    m.MOVEMENT_ID,
    m.SHIFT_ID,
    CASE m.MOVEMENT_TYPE
        WHEN 'CASH_IN'  THEN '⬆️ إيداع نقدي'
        WHEN 'CASH_OUT' THEN '⬇️ سحب نقدي'
        WHEN 'FLOAT'    THEN '💼 رصيد افتتاحي'
    END AS MOVEMENT_TYPE_LABEL,
    m.AMOUNT,
    m.NOTES,
    m.MOVEMENT_DATE,
    u.FULL_NAME_AR AS AUTHORIZED_BY
FROM POS_SHIFT_CASH_MOVEMENTS m
JOIN POS_APP_USERS u ON u.APP_USER_ID = m.AUTHORIZED_BY
WHERE m.SHIFT_ID = NVL(:P250_SELECTED_SHIFT_ID, -1)
ORDER BY m.MOVEMENT_DATE
```

---

## 🏗️ المرحلة 9: Section C — تقرير Z (Dynamic Content)

### منطقة `zreport_region`:
* **Title:** `📊 تقرير إغلاق الوردية (Z-Report)`
* **Type:** `PL/SQL Dynamic Content`
* **Static ID:** `zreport_region`

```sql
DECLARE
    v_shift_id NUMBER := NVL(:P250_SELECTED_SHIFT_ID, -1);
    v_shift    POS_SHIFTS%ROWTYPE;
    l_html     CLOB := '';
BEGIN
    IF v_shift_id = -1 THEN
        HTP.P('<div style="text-align:center;padding:40px;color:#6b7280;">
            👆 اختر وردية من القائمة أعلاه لعرض تقرير Z
        </div>');
        RETURN;
    END IF;

    SELECT * INTO v_shift FROM POS_SHIFTS WHERE SHIFT_ID = v_shift_id;

    HTP.P('
    <div style="max-width:400px;margin:0 auto;font-family:monospace;background:#fff;
                border:2px solid #000;padding:20px;direction:rtl;">
        <!-- رأس التقرير -->
        <div style="text-align:center;border-bottom:2px dashed #000;padding-bottom:10px;margin-bottom:10px;">
            <h2 style="margin:0;font-size:18px;">تقرير إغلاق الوردية</h2>
            <h3 style="margin:5px 0;font-size:14px;">Z-Report</h3>
            <p style="margin:2px 0;font-size:12px;">رقم الوردية: ' || v_shift.SHIFT_NO || '</p>
        </div>

        <!-- بيانات الوردية -->
        <table style="width:100%;font-size:12px;border-collapse:collapse;">
            <tr><td>الكاشير</td><td style="text-align:left;">
                ' || (SELECT FULL_NAME_AR FROM POS_APP_USERS WHERE APP_USER_ID = v_shift.CASHIER_USER_ID) || '
            </td></tr>
            <tr><td>الفرع</td><td style="text-align:left;">
                ' || (SELECT INV_ORG_NAME FROM POS_INVENTORY_ORGS WHERE INV_ORG_ID = v_shift.INV_ORG_ID) || '
            </td></tr>
            <tr><td>بدء الوردية</td><td style="text-align:left;">' || TO_CHAR(v_shift.OPEN_DATETIME, 'DD/MM/YYYY HH24:MI') || '</td></tr>
            <tr><td>إغلاق الوردية</td><td style="text-align:left;">' || TO_CHAR(v_shift.CLOSE_DATETIME, 'DD/MM/YYYY HH24:MI') || '</td></tr>
        </table>

        <div style="border-top:1px dashed #000;margin:10px 0;"></div>

        <!-- المبيعات -->
        <table style="width:100%;font-size:13px;font-weight:bold;">
            <tr><td>إجمالي المبيعات</td>
                <td style="text-align:left;">' || TO_CHAR(NVL(v_shift.TOTAL_SALES,0),'999,990.00') || ' ر.س</td></tr>
            <tr><td>المرتجعات</td>
                <td style="text-align:left;color:red;">(' || TO_CHAR(NVL(v_shift.TOTAL_REFUNDS,0),'999,990.00') || ') ر.س</td></tr>
            <tr><td>الخصومات</td>
                <td style="text-align:left;color:orange;">(' || TO_CHAR(NVL(v_shift.TOTAL_DISCOUNTS,0),'999,990.00') || ') ر.س</td></tr>
            <tr><td>ضريبة القيمة المضافة (15%)</td>
                <td style="text-align:left;">' || TO_CHAR(NVL(v_shift.TOTAL_TAX,0),'999,990.00') || ' ر.س</td></tr>
        </table>

        <div style="border-top:2px solid #000;margin:10px 0;"></div>

        <!-- النقدية -->
        <table style="width:100%;font-size:13px;">
            <tr><td>رصيد بداية الوردية</td>
                <td style="text-align:left;">' || TO_CHAR(NVL(v_shift.OPENING_FLOAT,0),'999,990.00') || ' ر.س</td></tr>
            <tr><td>إيداعات نقدية</td>
                <td style="text-align:left;">' || TO_CHAR(NVL(v_shift.TOTAL_CASH_IN,0),'999,990.00') || ' ر.س</td></tr>
            <tr><td>سحب نقدي</td>
                <td style="text-align:left;">(' || TO_CHAR(NVL(v_shift.TOTAL_CASH_OUT,0),'999,990.00') || ') ر.س</td></tr>
            <tr style="font-weight:bold;font-size:14px;">
                <td>النقدية المتوقعة</td>
                <td style="text-align:left;">' || TO_CHAR(NVL(v_shift.EXPECTED_CASH,0),'999,990.00') || ' ر.س</td></tr>
            <tr style="font-weight:bold;font-size:14px;">
                <td>النقدية المُعلَنة</td>
                <td style="text-align:left;">' || TO_CHAR(NVL(v_shift.DECLARED_CASH,0),'999,990.00') || ' ر.س</td></tr>
            <tr style="font-weight:bold;color:' ||
                CASE WHEN NVL(v_shift.DECLARED_CASH,0) >= NVL(v_shift.EXPECTED_CASH,0)
                     THEN 'green' ELSE 'red' END || ';">
                <td>الفرق (عجز/زيادة)</td>
                <td style="text-align:left;">' ||
                    TO_CHAR(NVL(v_shift.DECLARED_CASH,0) - NVL(v_shift.EXPECTED_CASH,0),'S999,990.00') ||
                ' ر.س</td></tr>
        </table>

        <!-- عدد الأوامر -->
        <div style="border-top:2px dashed #000;margin:10px 0;padding-top:10px;text-align:center;font-size:12px;">
            عدد الأوامر: ' ||
            (SELECT COUNT(*) FROM POS_ORDERS WHERE SHIFT_ID = v_shift_id) ||
            ' أمر
            <br>طُبع بتاريخ: ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI') || '
        </div>
    </div>');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        HTP.P('<div style="text-align:center;padding:20px;color:red;">⚠️ الوردية غير موجودة!</div>');
    WHEN OTHERS THEN
        HTP.P('<div style="color:red;">خطأ: ' || SQLERRM || '</div>');
END;
```
