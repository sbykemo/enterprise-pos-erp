# 🏗️ Page 240 — دليل البناء التفصيلي خطوة بخطوة
## GL Journals & Financials

---

# 🔷 الخطوة 0: تجهيز قاعدة البيانات أولاً

## 0-أ: Seed Data (بيانات أساسية)

افتح **SQL Workshop ➔ SQL Commands** وشغّل هذا الكود:

```sql
-- الكيان القانوني
INSERT INTO POS_LEGAL_ENTITIES (
    LEGAL_ENTITY_ID, LEGAL_ENTITY_CODE, LEGAL_ENTITY_NAME,
    COUNTRY_CODE, CURRENCY_CODE, IS_ACTIVE,
    CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE
) VALUES (
    1000001, 'LE-KSA-001', 'شركة المتجر المتحدة',
    'SA', 'SAR', 'Y', 1, SYSDATE, 1, SYSDATE
);

-- الفترة المحاسبية الحالية
INSERT INTO POS_GL_PERIODS (
    PERIOD_ID, LEGAL_ENTITY_ID, PERIOD_NAME,
    PERIOD_YEAR, PERIOD_NUM,
    START_DATE, END_DATE, CLOSE_STATUS,
    CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE
) VALUES (
    1000001, 1000001, 'SEP-2026',
    2026, 9,
    DATE '2026-09-01', DATE '2026-09-30', 'OPEN',
    1, SYSDATE, 1, SYSDATE
);

-- دليل الحسابات (بدون SEQUENCE — نُدخل PK يدوياً)
INSERT INTO POS_COA_ACCOUNTS (ACCOUNT_ID,ACCOUNT_CODE,ACCOUNT_NAME_AR,ACCOUNT_NAME_EN,ACCOUNT_TYPE,NORMAL_BALANCE,ACCOUNT_LEVEL,IS_DETAIL,IS_CONTROL,IS_RECONCILABLE,IS_ACTIVE,LEGAL_ENTITY_ID,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE)
VALUES (1000001,'1-0000-000','الأصول','Assets','ASSET','DEBIT',1,'N','N','N','Y',1000001,1,SYSDATE,1,SYSDATE);
INSERT INTO POS_COA_ACCOUNTS (ACCOUNT_ID,ACCOUNT_CODE,ACCOUNT_NAME_AR,ACCOUNT_NAME_EN,ACCOUNT_TYPE,NORMAL_BALANCE,PARENT_ACCOUNT_ID,ACCOUNT_LEVEL,IS_DETAIL,IS_CONTROL,IS_RECONCILABLE,IS_ACTIVE,LEGAL_ENTITY_ID,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE)
VALUES (1000002,'1-1100-000','النقدية','Cash','ASSET','DEBIT',1000001,2,'Y','Y','Y','Y',1000001,1,SYSDATE,1,SYSDATE);
INSERT INTO POS_COA_ACCOUNTS (ACCOUNT_ID,ACCOUNT_CODE,ACCOUNT_NAME_AR,ACCOUNT_NAME_EN,ACCOUNT_TYPE,NORMAL_BALANCE,PARENT_ACCOUNT_ID,ACCOUNT_LEVEL,IS_DETAIL,IS_CONTROL,IS_RECONCILABLE,IS_ACTIVE,LEGAL_ENTITY_ID,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE)
VALUES (1000003,'1-1200-000','العملاء','Accounts Receivable','ASSET','DEBIT',1000001,2,'Y','N','Y','Y',1000001,1,SYSDATE,1,SYSDATE);
INSERT INTO POS_COA_ACCOUNTS (ACCOUNT_ID,ACCOUNT_CODE,ACCOUNT_NAME_AR,ACCOUNT_NAME_EN,ACCOUNT_TYPE,NORMAL_BALANCE,PARENT_ACCOUNT_ID,ACCOUNT_LEVEL,IS_DETAIL,IS_CONTROL,IS_RECONCILABLE,IS_ACTIVE,LEGAL_ENTITY_ID,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE)
VALUES (1000004,'1-2000-000','المخزون','Inventory','ASSET','DEBIT',1000001,2,'Y','N','N','Y',1000001,1,SYSDATE,1,SYSDATE);

INSERT INTO POS_COA_ACCOUNTS (ACCOUNT_ID,ACCOUNT_CODE,ACCOUNT_NAME_AR,ACCOUNT_NAME_EN,ACCOUNT_TYPE,NORMAL_BALANCE,ACCOUNT_LEVEL,IS_DETAIL,IS_CONTROL,IS_RECONCILABLE,IS_ACTIVE,LEGAL_ENTITY_ID,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE)
VALUES (1000005,'2-0000-000','الالتزامات','Liabilities','LIABILITY','CREDIT',1,'N','N','N','Y',1000001,1,SYSDATE,1,SYSDATE);
INSERT INTO POS_COA_ACCOUNTS (ACCOUNT_ID,ACCOUNT_CODE,ACCOUNT_NAME_AR,ACCOUNT_NAME_EN,ACCOUNT_TYPE,NORMAL_BALANCE,PARENT_ACCOUNT_ID,ACCOUNT_LEVEL,IS_DETAIL,IS_CONTROL,IS_RECONCILABLE,IS_ACTIVE,LEGAL_ENTITY_ID,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE)
VALUES (1000006,'2-1000-000','الموردون','Accounts Payable','LIABILITY','CREDIT',1000005,2,'Y','Y','Y','Y',1000001,1,SYSDATE,1,SYSDATE);
INSERT INTO POS_COA_ACCOUNTS (ACCOUNT_ID,ACCOUNT_CODE,ACCOUNT_NAME_AR,ACCOUNT_NAME_EN,ACCOUNT_TYPE,NORMAL_BALANCE,PARENT_ACCOUNT_ID,ACCOUNT_LEVEL,IS_DETAIL,IS_CONTROL,IS_RECONCILABLE,IS_ACTIVE,LEGAL_ENTITY_ID,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE)
VALUES (1000007,'2-2000-000','ضريبة القيمة المضافة','VAT Payable','LIABILITY','CREDIT',1000005,2,'Y','N','N','Y',1000001,1,SYSDATE,1,SYSDATE);

INSERT INTO POS_COA_ACCOUNTS (ACCOUNT_ID,ACCOUNT_CODE,ACCOUNT_NAME_AR,ACCOUNT_NAME_EN,ACCOUNT_TYPE,NORMAL_BALANCE,ACCOUNT_LEVEL,IS_DETAIL,IS_CONTROL,IS_RECONCILABLE,IS_ACTIVE,LEGAL_ENTITY_ID,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE)
VALUES (1000008,'4-0000-000','الإيرادات','Revenue','REVENUE','CREDIT',1,'N','N','N','Y',1000001,1,SYSDATE,1,SYSDATE);
INSERT INTO POS_COA_ACCOUNTS (ACCOUNT_ID,ACCOUNT_CODE,ACCOUNT_NAME_AR,ACCOUNT_NAME_EN,ACCOUNT_TYPE,NORMAL_BALANCE,PARENT_ACCOUNT_ID,ACCOUNT_LEVEL,IS_DETAIL,IS_CONTROL,IS_RECONCILABLE,IS_ACTIVE,LEGAL_ENTITY_ID,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE)
VALUES (1000009,'4-1000-000','إيرادات المبيعات','Sales Revenue','REVENUE','CREDIT',1000008,2,'Y','N','N','Y',1000001,1,SYSDATE,1,SYSDATE);

INSERT INTO POS_COA_ACCOUNTS (ACCOUNT_ID,ACCOUNT_CODE,ACCOUNT_NAME_AR,ACCOUNT_NAME_EN,ACCOUNT_TYPE,NORMAL_BALANCE,ACCOUNT_LEVEL,IS_DETAIL,IS_CONTROL,IS_RECONCILABLE,IS_ACTIVE,LEGAL_ENTITY_ID,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE)
VALUES (1000010,'5-0000-000','المصاريف','Expenses','EXPENSE','DEBIT',1,'N','N','N','Y',1000001,1,SYSDATE,1,SYSDATE);
INSERT INTO POS_COA_ACCOUNTS (ACCOUNT_ID,ACCOUNT_CODE,ACCOUNT_NAME_AR,ACCOUNT_NAME_EN,ACCOUNT_TYPE,NORMAL_BALANCE,PARENT_ACCOUNT_ID,ACCOUNT_LEVEL,IS_DETAIL,IS_CONTROL,IS_RECONCILABLE,IS_ACTIVE,LEGAL_ENTITY_ID,CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE)
VALUES (1000011,'5-1000-000','تكلفة البضاعة المباعة','Cost of Goods Sold','EXPENSE','DEBIT',1000010,2,'Y','N','N','Y',1000001,1,SYSDATE,1,SYSDATE);

COMMIT;

-- تأكيد النجاح
SELECT COUNT(*) AS "عدد الحسابات" FROM POS_COA_ACCOUNTS;
SELECT COUNT(*) AS "عدد الفترات" FROM POS_GL_PERIODS;
```

---

## 0-ب: Triggers في قاعدة البيانات

شغّل كل كتلة منفردة:

```sql
-- Trigger 1: PK + رقم القيد التلقائي
CREATE OR REPLACE TRIGGER POS_GL_JOURNALS_BIR
BEFORE INSERT ON POS_GL_JOURNALS
FOR EACH ROW
BEGIN
    IF :NEW.JOURNAL_ID IS NULL THEN
        SELECT NVL(MAX(JOURNAL_ID),1000000)+1 INTO :NEW.JOURNAL_ID FROM POS_GL_JOURNALS;
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
```

```sql
-- Trigger 2: PK + رقم سطر القيد التلقائي
CREATE OR REPLACE TRIGGER POS_GL_JNL_LINES_BIR
BEFORE INSERT ON POS_GL_JOURNAL_LINES
FOR EACH ROW
DECLARE
    v_line NUMBER;
BEGIN
    IF :NEW.JOURNAL_LINE_ID IS NULL THEN
        SELECT NVL(MAX(JOURNAL_LINE_ID),1000000)+1 INTO :NEW.JOURNAL_LINE_ID FROM POS_GL_JOURNAL_LINES;
    END IF;
    IF :NEW.LINE_NO IS NULL THEN
        SELECT NVL(MAX(LINE_NO),0)+1 INTO v_line
          FROM POS_GL_JOURNAL_LINES WHERE JOURNAL_ID = :NEW.JOURNAL_ID;
        :NEW.LINE_NO := v_line;
    END IF;
    IF :NEW.DEBIT_AMOUNT IS NULL  THEN :NEW.DEBIT_AMOUNT  := 0; END IF;
    IF :NEW.CREDIT_AMOUNT IS NULL THEN :NEW.CREDIT_AMOUNT := 0; END IF;
    IF :NEW.CREATION_DATE IS NULL THEN :NEW.CREATION_DATE := SYSDATE; END IF;
    :NEW.LAST_UPDATE_DATE := SYSDATE;
END;
/
```

```sql
-- تأكيد الـ Triggers
SELECT TRIGGER_NAME, STATUS FROM USER_TRIGGERS
WHERE TABLE_NAME IN ('POS_GL_JOURNALS','POS_GL_JOURNAL_LINES')
ORDER BY TRIGGER_NAME;
```

---

# 🔷 الخطوة 1: إنشاء الصفحة الجديدة (Page 240)

1. في أيبكس، اذهب لـ **App Builder ➔ Application 102**.
2. اضغط على زر **`Create Page`** (الزر الأزرق في أعلى القائمة).
3. في الـ Wizard اختر: **`Blank Page`**.
4. أدخل البيانات التالية:
   * **Page Number:** `240`
   * **Name:** `GL Journals & Financials`
   * **Page Mode:** `Normal`
   * **Breadcrumb:** `Breadcrumb` (اختر الموجود)
5. اضغط **`Create Page`**.

---

# 🔷 الخطوة 2: إضافة Page Items (حقول الفلترة)

> [!IMPORTANT]
> **أين تُضاف Page Items؟**
> في **شجرة اليسار** في Page Designer، اضغط بزر الأيمن على **`Body`** ➔ اختر **`Create Page Item`**.
> الـ Page Items في أيبكس تُوضع داخل **منطقة (Region)** — لذلك سنُنشئ أولاً منطقة للفلاتر، ثم نضع الـ Items بداخلها.

---

## الخطوة 2-أ: إنشاء منطقة الفلاتر

في شجرة اليسار، اضغط بزر الأيمن على **`Body`** ➔ **`Create Region`**:
* **Title:** `🔍 فلاتر البحث`
* **Type:** `Static Content`
* **Template:** `Standard`
* **Template Options ➔ Header:** `Hidden but accessible`
* **Grid ➔ Column:** `1` / **Grid ➔ Column Span:** `12`

---

## الخطوة 2-ب: إضافة الـ Page Items داخل منطقة الفلاتر

اضغط بزر الأيمن على منطقة **`🔍 فلاتر البحث`** ➔ **`Create Page Item`**:

### Item 1: `P240_LE_FILTER`
* **Name:** `P240_LE_FILTER`
* **Type:** `Select List`
* **Label:** `🏢 الكيان القانوني`
* **Region:** `🔍 فلاتر البحث`
* **Grid ➔ Column:** `1` | **Column Span:** `3`
* **List of Values ➔ Type:** `SQL Query`
* **SQL:**
```sql
SELECT LEGAL_ENTITY_NAME D, LEGAL_ENTITY_ID R
FROM POS_LEGAL_ENTITIES WHERE IS_ACTIVE = 'Y'
ORDER BY LEGAL_ENTITY_NAME
```
* **Display Null Value:** `ON` | **Null Display Value:** `— الكل —`

---

### Item 2: `P240_PERIOD_FILTER`
اضغط بزر الأيمن على نفس المنطقة ➔ **`Create Page Item`**:
* **Name:** `P240_PERIOD_FILTER`
* **Type:** `Select List`
* **Label:** `📅 الفترة المحاسبية`
* **Region:** `🔍 فلاتر البحث`
* **Grid ➔ Column:** `4` | **Column Span:** `3`
* **List of Values ➔ SQL:**
```sql
SELECT PERIOD_NAME || ' (' || CLOSE_STATUS || ')' D, PERIOD_ID R
FROM POS_GL_PERIODS
ORDER BY PERIOD_YEAR DESC, PERIOD_NUM DESC
```
* **Display Null:** `ON` | **Null Value:** `— الكل —`

---

### Item 3: `P240_STATUS_FILTER`
اضغط بزر الأيمن على نفس المنطقة ➔ **`Create Page Item`**:
* **Name:** `P240_STATUS_FILTER`
* **Type:** `Select List`
* **Label:** `📊 حالة القيد`
* **Region:** `🔍 فلاتر البحث`
* **Grid ➔ Column:** `7` | **Column Span:** `3`
* **List of Values ➔ SQL:**
```sql
SELECT D, R FROM (
    SELECT '— الكل —' D, NULL R, 0 S FROM DUAL UNION ALL
    SELECT '📝 مسودة'   D, 'DRAFT'    R, 1 S FROM DUAL UNION ALL
    SELECT '✅ مُرحَّل'  D, 'POSTED'   R, 2 S FROM DUAL UNION ALL
    SELECT '🔄 معكوس'   D, 'REVERSED' R, 3 S FROM DUAL UNION ALL
    SELECT '❌ خطأ'     D, 'ERROR'    R, 4 S FROM DUAL
) ORDER BY S
```
* **Display Null:** `OFF` (الـ NULL موجود في الاستعلام نفسه)

---

### Item 4: `P240_SELECTED_JOURNAL_ID` (Hidden)
اضغط بزر الأيمن على نفس المنطقة ➔ **`Create Page Item`**:
* **Name:** `P240_SELECTED_JOURNAL_ID`
* **Type:** `Hidden`
* **Value Protected:** `OFF`

---

## الخطوة 2-ج: إضافة زر البحث

اضغط بزر الأيمن على منطقة **`🔍 فلاتر البحث`** ➔ **`Create Button`**:
* **Button Name:** `BTN_SEARCH`
* **Label:** `🔍 بحث`
* **Region:** `🔍 فلاتر البحث`
* **Position:** `Next` (بجانب الفلاتر)
* **Button CSS Classes:** `t-Button--primary`
* **Action:** `Submit Page`

---

# 🔷 الخطوة 3: إنشاء Section A — دليل الحسابات

اضغط بزر الأيمن على **`Body`** ➔ **`Create Region`**:
* **Title:** `📊 دليل الحسابات (Chart of Accounts)`
* **Type:** `Interactive Report`
* **Static ID:** `coa_reg`
* **Template:** `Standard`
* **Source ➔ SQL Query:**

```sql
SELECT
    a.ACCOUNT_ID,
    LPAD(' ', (NVL(a.ACCOUNT_LEVEL,1) - 1) * 4, ' ') || a.ACCOUNT_CODE AS ACCOUNT_CODE_INDENTED,
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
    CASE a.NORMAL_BALANCE WHEN 'DEBIT' THEN 'مدين' ELSE 'دائن' END AS NORMAL_BALANCE_AR,
    CASE a.IS_DETAIL WHEN 'Y' THEN '✅ تفصيلي' ELSE '📁 مجمّع' END AS ACCOUNT_NATURE,
    NVL((
        SELECT SUM(l.DEBIT_AMOUNT - l.CREDIT_AMOUNT)
        FROM POS_GL_JOURNAL_LINES l
        JOIN POS_GL_JOURNALS j ON j.JOURNAL_ID = l.JOURNAL_ID
        WHERE l.ACCOUNT_ID = a.ACCOUNT_ID
          AND j.STATUS = 'POSTED'
    ), 0) AS CURRENT_BALANCE
FROM POS_COA_ACCOUNTS a
WHERE a.IS_ACTIVE = 'Y'
  AND a.LEGAL_ENTITY_ID = NVL(:P240_LE_FILTER, a.LEGAL_ENTITY_ID)
ORDER BY a.ACCOUNT_CODE
```

* **Page Items to Submit:** `P240_LE_FILTER`

---

# 🔷 الخطوة 4: إنشاء Section B — جريد قيود اليومية

اضغط بزر الأيمن على **`Body`** ➔ **`Create Region`**:
* **Title:** `📒 قيود اليومية (GL Journals)`
* **Type:** `Interactive Grid`
* **Static ID:** `journals_reg`
* **Template:** `Standard`
* **Source ➔ SQL Query:**

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
        WHEN 'POS_SALE'   THEN '🛒 مبيعات POS'
        WHEN 'POS_RETURN' THEN '↩️ مرتجعات'
        WHEN 'POS_SHIFT'  THEN '🕐 وردية'
        WHEN 'INVENTORY'  THEN '📦 مخزون'
        WHEN 'AP'         THEN '💸 موردون'
        WHEN 'AR'         THEN '💰 عملاء'
        WHEN 'MANUAL'     THEN '✏️ يدوي'
        ELSE j.SOURCE
    END AS SOURCE_LABEL,
    j.DESCRIPTION,
    j.CURRENCY_CODE,
    NVL(j.TOTAL_DEBIT,0)  AS TOTAL_DEBIT,
    NVL(j.TOTAL_CREDIT,0) AS TOTAL_CREDIT,
    j.STATUS,
    CASE j.STATUS
        WHEN 'DRAFT'    THEN '📝 مسودة'
        WHEN 'POSTED'   THEN '✅ مُرحَّل'
        WHEN 'REVERSED' THEN '🔄 معكوس'
        WHEN 'ERROR'    THEN '❌ خطأ'
    END AS STATUS_LABEL,
    j.POSTED_DATE,
    (SELECT COUNT(*) FROM POS_GL_JOURNAL_LINES l
      WHERE l.JOURNAL_ID = j.JOURNAL_ID) AS LINES_COUNT,
    CASE WHEN NVL(j.TOTAL_DEBIT,0) = NVL(j.TOTAL_CREDIT,0)
         THEN '✅ متوازن'
         ELSE '⚠️ غير متوازن'
    END AS BALANCE_STATUS,
    CASE WHEN j.STATUS = 'DRAFT'
          AND NVL(j.TOTAL_DEBIT,0) = NVL(j.TOTAL_CREDIT,0)
          AND NVL(j.TOTAL_DEBIT,0) > 0
         THEN 'inline-block' ELSE 'none'
    END AS SHOW_POST,
    CASE WHEN j.STATUS = 'POSTED'
         THEN 'inline-block' ELSE 'none'
    END AS SHOW_REVERSE
FROM POS_GL_JOURNALS j
JOIN POS_LEGAL_ENTITIES le ON le.LEGAL_ENTITY_ID = j.LEGAL_ENTITY_ID
JOIN POS_GL_PERIODS p      ON p.PERIOD_ID        = j.PERIOD_ID
WHERE j.LEGAL_ENTITY_ID = NVL(:P240_LE_FILTER,    j.LEGAL_ENTITY_ID)
  AND j.PERIOD_ID       = NVL(:P240_PERIOD_FILTER, j.PERIOD_ID)
  AND j.STATUS          = NVL(:P240_STATUS_FILTER, j.STATUS)
ORDER BY j.JOURNAL_DATE DESC, j.JOURNAL_ID DESC
```

* **Primary Key Column:** `JOURNAL_ID`
* **Page Items to Submit:** `P240_LE_FILTER,P240_PERIOD_FILTER,P240_STATUS_FILTER`

---

## الخطوة 4-أ: ضبط أعمدة جريد اليومية

اضغط على كل عمود من شجرة **`Columns`** في اليسار وأدخل الإعدادات:

### عمود `JOURNAL_ID`:
* **Type:** `Hidden`
* **Primary Key:** `ON` ✅

---

### عمود `JOURNAL_NO`:
* **Type:** `Plain Text`
* **Heading:** `رقم القيد`
* **Source ➔ Query Only:** `ON` ✅
* **Validation ➔ Value Required:** `OFF` ❌

---

### عمود `LEGAL_ENTITY_ID`:
* **Type:** `Select List`
* **Heading:** `الكيان القانوني`
* **List of Values ➔ SQL:**
```sql
SELECT LEGAL_ENTITY_NAME D, LEGAL_ENTITY_ID R
FROM POS_LEGAL_ENTITIES WHERE IS_ACTIVE = 'Y'
```
* **Source ➔ Query Only:** `OFF` ❌
* **Validation ➔ Value Required:** `ON` ✅

---

### عمود `LEGAL_ENTITY_NAME`:
* **Type:** `Plain Text`
* **Heading:** `الكيان`
* **Source ➔ Query Only:** `ON` ✅

---

### عمود `PERIOD_ID`:
* **Type:** `Select List`
* **Heading:** `الفترة`
* **List of Values ➔ SQL:**
```sql
SELECT PERIOD_NAME D, PERIOD_ID R
FROM POS_GL_PERIODS ORDER BY PERIOD_YEAR DESC, PERIOD_NUM DESC
```
* **Source ➔ Query Only:** `OFF` ❌
* **Validation ➔ Value Required:** `ON` ✅

---

### عمود `PERIOD_NAME`:
* **Type:** `Plain Text`
* **Heading:** `الفترة`
* **Source ➔ Query Only:** `ON` ✅

---

### عمود `JOURNAL_DATE`:
* **Type:** `Date Picker`
* **Heading:** `تاريخ القيد`
* **Default ➔ Type:** `Expression`
* **Default ➔ PL/SQL Expression:** `SYSDATE`
* **Validation ➔ Value Required:** `ON` ✅

---

### عمود `SOURCE`:
* **Type:** `Select List`
* **Heading:** `المصدر`
* **List of Values ➔ SQL:**
```sql
SELECT D, R FROM (
    SELECT '✏️ يدوي'       D, 'MANUAL'    R, 1 S FROM DUAL UNION ALL
    SELECT '🛒 مبيعات POS' D, 'POS_SALE'  R, 2 S FROM DUAL UNION ALL
    SELECT '↩️ مرتجعات'   D, 'POS_RETURN' R, 3 S FROM DUAL UNION ALL
    SELECT '📦 مخزون'      D, 'INVENTORY' R, 4 S FROM DUAL UNION ALL
    SELECT '💸 موردون'     D, 'AP'        R, 5 S FROM DUAL UNION ALL
    SELECT '💰 عملاء'      D, 'AR'        R, 6 S FROM DUAL UNION ALL
    SELECT '🕐 وردية'      D, 'POS_SHIFT' R, 7 S FROM DUAL
) ORDER BY S
```
* **Source ➔ Query Only:** `OFF` ❌
* **Default ➔ Static Value:** `MANUAL`

---

### عمود `SOURCE_LABEL`:
* **Type:** `Hidden`
* **Source ➔ Query Only:** `ON` ✅

---

### عمود `DESCRIPTION`:
* **Type:** `Text Field`
* **Heading:** `الوصف`
* **Width:** `300`

---

### عمود `CURRENCY_CODE`:
* **Type:** `Text Field`
* **Heading:** `العملة`
* **Default ➔ Static Value:** `SAR`
* **Width:** `60`

---

### عمود `TOTAL_DEBIT`:
* **Type:** `Plain Text`
* **Heading:** `إجمالي المدين`
* **Source ➔ Query Only:** `ON` ✅
* **Column Formatting ➔ Number Format:** `999,990.00`

---

### عمود `TOTAL_CREDIT`:
* **Type:** `Plain Text`
* **Heading:** `إجمالي الدائن`
* **Source ➔ Query Only:** `ON` ✅
* **Column Formatting ➔ Number Format:** `999,990.00`

---

### عمود `STATUS`:
* **Type:** `Hidden`
* **Source ➔ Query Only:** `ON` ✅
* **Default ➔ Static Value:** `DRAFT`

---

### عمود `STATUS_LABEL`:
* **Type:** `Plain Text`
* **Heading:** `الحالة`
* **Source ➔ Query Only:** `ON` ✅

---

### عمود `POSTED_DATE`:
* **Type:** `Plain Text`
* **Heading:** `تاريخ الترحيل`
* **Source ➔ Query Only:** `ON` ✅

---

### عمود `LINES_COUNT`:
* **Type:** `Plain Text`
* **Heading:** `بنود`
* **Source ➔ Query Only:** `ON` ✅

---

### عمود `BALANCE_STATUS`:
* **Type:** `Plain Text`
* **Heading:** `توازن القيد`
* **Source ➔ Query Only:** `ON` ✅

---

### عمودا `SHOW_POST` و `SHOW_REVERSE`:
لكل منهما:
* **Type:** `Hidden`
* **Source ➔ Query Only:** `ON` ✅

---

### عمود `إجراءات` (جديد — يدوي):
اضغط بزر الأيمن على **`Columns`** ➔ **`Create Column`**:
* **Heading:** `إجراءات`
* **Type:** `HTML Expression`
* **Source ➔ Query Only:** `ON` ✅
* **HTML Expression:**

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

---

## الخطوة 4-ب: إعدادات Edit الجريد

في **journals_reg ➔ Attributes ➔ Edit**:

| الخاصية | القيمة | السبب |
|---|---|---|
| **Enabled** | `ON` | لتفعيل وضع الإدخال |
| **Add Row** | `ON` ✅ | إنشاء قيود جديدة |
| **Update Row** | `OFF` ❌ | التحديث عبر الأزرار فقط |
| **Delete Row** | `OFF` ❌ | لا حذف |
| **Save Button Label** | `💾 حفظ القيد` | |

---

# 🔷 الخطوة 5: إنشاء Section B-2 — جريد بنود القيد

اضغط بزر الأيمن على **`Body`** ➔ **`Create Region`**:
* **Title:** `📋 بنود القيد المحدد (Journal Lines)`
* **Type:** `Interactive Grid`
* **Static ID:** `journal_lines_reg`
* **Template:** `Standard`
* **Source ➔ SQL Query:**

```sql
SELECT
    l.JOURNAL_LINE_ID,
    l.JOURNAL_ID,
    l.LINE_NO,
    l.ACCOUNT_ID,
    a.ACCOUNT_CODE,
    a.ACCOUNT_NAME_AR,
    l.DESCRIPTION,
    NVL(l.DEBIT_AMOUNT, 0)  AS DEBIT_AMOUNT,
    NVL(l.CREDIT_AMOUNT, 0) AS CREDIT_AMOUNT,
    l.INV_ORG_ID,
    io.INV_ORG_NAME,
    l.REFERENCE1,
    (SELECT j.STATUS FROM POS_GL_JOURNALS j
      WHERE j.JOURNAL_ID = l.JOURNAL_ID) AS JOURNAL_STATUS,
    CASE
        WHEN (SELECT j.STATUS FROM POS_GL_JOURNALS j
               WHERE j.JOURNAL_ID = l.JOURNAL_ID) = 'DRAFT'
        THEN 'Y' ELSE 'N'
    END AS IS_EDITABLE
FROM POS_GL_JOURNAL_LINES l
JOIN POS_COA_ACCOUNTS a    ON a.ACCOUNT_ID  = l.ACCOUNT_ID
LEFT JOIN POS_INVENTORY_ORGS io ON io.INV_ORG_ID = l.INV_ORG_ID
WHERE l.JOURNAL_ID = NVL(:P240_SELECTED_JOURNAL_ID, -1)
ORDER BY l.LINE_NO
```

* **Primary Key:** `JOURNAL_LINE_ID`
* **Page Items to Submit:** `P240_SELECTED_JOURNAL_ID`

---

## الخطوة 5-أ: ضبط أعمدة جريد البنود

### عمود `JOURNAL_LINE_ID`: `Hidden` / PK ✅
### عمود `JOURNAL_ID`:
* **Type:** `Hidden`
* **Source ➔ Query Only:** `OFF` ❌ *(مهم جداً!)*
* **Default ➔ Type:** `Item`
* **Default ➔ Item:** `P240_SELECTED_JOURNAL_ID`

### عمود `LINE_NO`:
* **Type:** `Plain Text`
* **Heading:** `#`
* **Source ➔ Query Only:** `ON` ✅
* **Validation ➔ Value Required:** `OFF` ❌

### عمود `ACCOUNT_ID`:
* **Type:** `Select List`
* **Heading:** `الحساب`
* **Validation ➔ Value Required:** `ON` ✅
* **List of Values ➔ SQL:**
```sql
SELECT ACCOUNT_CODE || ' — ' || ACCOUNT_NAME_AR D, ACCOUNT_ID R
FROM POS_COA_ACCOUNTS
WHERE IS_ACTIVE = 'Y' AND IS_DETAIL = 'Y'
ORDER BY ACCOUNT_CODE
```

### عمود `ACCOUNT_CODE`: `Plain Text` / Query Only: `ON` ✅
### عمود `ACCOUNT_NAME_AR`:
* **Heading:** `اسم الحساب`
* **Type:** `Plain Text`
* **Source ➔ Query Only:** `ON` ✅

### عمود `DESCRIPTION`:
* **Type:** `Text Field`
* **Heading:** `البيان`

### عمود `DEBIT_AMOUNT`:
* **Type:** `Number Field`
* **Heading:** `المدين`
* **Default ➔ Static Value:** `0`
* **Column Formatting ➔ Number Format:** `999,990.00`

### عمود `CREDIT_AMOUNT`:
* **Type:** `Number Field`
* **Heading:** `الدائن`
* **Default ➔ Static Value:** `0`
* **Column Formatting ➔ Number Format:** `999,990.00`

### عمود `INV_ORG_ID`:
* **Type:** `Select List`
* **Heading:** `الفرع`
* **Display Null:** `ON` / **Null Label:** `— بدون —`
* **List of Values ➔ SQL:**
```sql
SELECT INV_ORG_NAME D, INV_ORG_ID R
FROM POS_INVENTORY_ORGS WHERE IS_ACTIVE = 'Y'
```

### عمود `INV_ORG_NAME`: `Plain Text` / Query Only: `ON` ✅
### عمود `REFERENCE1`: `Text Field` / **Heading:** `مرجع`
### عمود `JOURNAL_STATUS`: `Hidden` / Query Only: `ON` ✅
### عمود `IS_EDITABLE`: `Hidden` / Query Only: `ON` ✅

---

## الخطوة 5-ب: إعدادات Edit جريد البنود

في **journal_lines_reg ➔ Attributes ➔ Edit**:

| الخاصية | القيمة |
|---|---|
| **Enabled** | `ON` |
| **Add Row** | `ON` ✅ |
| **Update Row** | `ON` ✅ |
| **Delete Row** | `ON` ✅ |
| **Allowed Row Operations Column** | `IS_EDITABLE` ← القفل الأمني! |

---

# 🔷 الخطوة 6: Ajax Callbacks

في **Processing ➔ Ajax Callbacks** ➔ اضغط بزر الأيمن ➔ **`Create Process`**:

### Callback 1: `SET_JOURNAL_SESSION`
```sql
BEGIN
    APEX_UTIL.SET_SESSION_STATE('P240_SELECTED_JOURNAL_ID', APEX_APPLICATION.G_X01);
    APEX_JSON.OPEN_OBJECT;
    APEX_JSON.WRITE('success', TRUE);
    APEX_JSON.CLOSE_OBJECT;
END;
```

---

### Callback 2: `PROCESS_JOURNAL_ACTION`
*(الكود الكامل موجود في الدليل السابق — POST + REVERSE)*

---

# 🔷 الخطوة 7: JavaScript في الصفحة

في **Page 240 ➔ JavaScript ➔ Function and Global Variable Declaration**:

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

    apex.server.process('SET_JOURNAL_SESSION', {
        x01: String(journalId)
    }, {
        dataType: 'json',
        success: function() {
            var el = document.getElementById('journal_lines_reg');
            if (el) {
                $(el).trigger('apexrefresh');
                setTimeout(function() {
                    el.scrollIntoView({ behavior: 'smooth', block: 'start' });
                }, 300);
            }
        }
    });
};

// ترحيل أو عكس القيد
window.doJournalAction = function(pBtn, journalId, action) {
    var reason = '';

    if (action === 'POST') {
        if (!confirm('✅ هل تريد ترحيل هذا القيد؟\nلن يمكن تعديله أو حذفه بعد الترحيل!')) return;
    } else if (action === 'REVERSE') {
        reason = prompt('🔄 عكس القيد رقم ' + journalId + '\n\nيرجى إدخال سبب العكس (إلزامي):', '');
        if (reason === null) return;
        if (!reason.trim()) {
            apex.message.showErrors([{
                type: 'error', location: 'page',
                message: '⛔ يجب إدخال سبب العكس!'
            }]);
            return;
        }
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
                ['journals_reg', 'journal_lines_reg', 'coa_reg'].forEach(function(id) {
                    var el = document.getElementById(id);
                    if (el) $(el).trigger('apexrefresh');
                });
            } else {
                apex.message.showErrors([{
                    type: 'error', location: 'page',
                    message: pData ? pData.message : '⛔ خطأ غير متوقع!'
                }]);
            }
        },
        error: function(xhr) {
            apex.message.showErrors([{
                type: 'error', location: 'page',
                message: '⛔ فشل الاتصال: ' + xhr.statusText
            }]);
        }
    });
};
```

---

# 🔷 الخطوة 8: Save + Run + اختبار

1. اضغط **`Save`** ثم ▶️ **`Run Page`**.
2. **اختبار 1 - دليل الحسابات:** تأكد من ظهور الـ 11 حساب مصنفة.
3. **اختبار 2 - إنشاء قيد يدوي:**
   * في جريد اليومية، اضغط **`Add Row`**.
   * أدخل: الكيان القانوني + الفترة (SEP-2026) + التاريخ + Source (✏️ يدوي) + الوصف.
   * اضغط **`💾 حفظ القيد`**.
   * تحقق: رقم القيد `JNL-202609-000001` تولّد تلقائياً.
4. **اختبار 3 - إضافة بنود:**
   * اضغط **`📋 بنود (0)`** على القيد.
   * أضف سطرين: **مدين:** `1-1100-000 (النقدية)` بمبلغ `1000` / **دائن:** `4-1000-000 (إيرادات المبيعات)` بمبلغ `1000`.
   * اضغط **`Save`**.
5. **اختبار 4 - الترحيل:**
   * اضغط **`✅ ترحيل`**.
   * تأكد: الحالة تغيرت لـ `✅ مُرحَّل` وزر الترحيل اختفى وظهر زر `🔄 عكس`.
