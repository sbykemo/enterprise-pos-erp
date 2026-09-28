# دليل تنفيذ صفحة 360: دليل الحسابات والفترات المالية (COA & GL Periods)

## 1. إعدادات الصفحة (Page Creation)
- **رقم الصفحة (Page Number):** 360
- **اسم الصفحة (Page Name):** دليل الحسابات والفترات المالية
- **نمط الصفحة (Page Mode):** Normal
- **قالب الصفحة (Page Template):** Theme Default
- **نظام الصلاحيات (Authorization Scheme):** `AUTH_FINANCE_ONLY`

## 2. بنية الصفحة (Page Structure)
استخدم (Tabs Container) يحتوي على 3 علامات تبويب:
1. دليل الحسابات (COA Accounts)
2. قطاعات الحسابات (COA Segments)
3. الفترات المالية (GL Periods)

---

## 3. علامة التبويب 1: دليل الحسابات (COA Accounts)
نظام رئيسي وتفصيلي في نفس الصفحة باستخدام شجرة (Tree) على اليمين وشبكة تفاعلية (Interactive Grid) على اليسار.

### أ. الشجرة (Tree Region)
- **العنوان:** هيكل الحسابات
- **النوع:** Tree
- **الاستعلام (SQL Query):**
```sql
SELECT 
    ACCOUNT_ID AS id,
    PARENT_ACCOUNT_ID AS pid,
    ACCOUNT_NAME_AR || ' - ' || ACCOUNT_CODE AS title,
    CASE 
        WHEN IS_CONTROL = 'Y' THEN 'fa fa-folder'
        ELSE 'fa fa-file-text-o'
    END AS icon,
    ACCOUNT_ID AS value
FROM POS_COA_ACCOUNTS
WHERE LEGAL_ENTITY_ID = NVL(:AI_LE_LIST, LEGAL_ENTITY_ID)
```
- **إعدادات:** تعيين قيمة الحساب المختار في عنصر مخفي عند النقر (Node Click).

### ب. الشبكة التفاعلية للحسابات (Interactive Grid)
- **العنوان:** تفاصيل الحسابات
- **الاستعلام (SQL Query):**
```sql
SELECT 
    ACCOUNT_ID,
    ACCOUNT_CODE,
    SEG1_VALUE, SEG2_VALUE, SEG3_VALUE, SEG4_VALUE,
    ACCOUNT_NAME_EN,
    ACCOUNT_NAME_AR,
    ACCOUNT_TYPE,
    NORMAL_BALANCE,
    PARENT_ACCOUNT_ID,
    ACCOUNT_LEVEL,
    IS_DETAIL,
    IS_CONTROL,
    IS_RECONCILABLE,
    IS_ACTIVE,
    LEGAL_ENTITY_ID,
    CREATED_BY, CREATION_DATE, UPDATED_BY, UPDATE_DATE
FROM POS_COA_ACCOUNTS
WHERE PARENT_ACCOUNT_ID = :P360_SELECTED_ACCOUNT_ID 
   OR ACCOUNT_ID = :P360_SELECTED_ACCOUNT_ID
```
- **أعمدة (Page Items):**
  - `ACCOUNT_TYPE`: LOV (أصول، خصوم، حقوق ملكية، إيرادات، مصروفات، مقابل) - ASSET/LIABILITY/EQUITY/REVENUE/EXPENSE/CONTRA
  - `NORMAL_BALANCE`: LOV (مدين، دائن) - DEBIT/CREDIT
  - `IS_DETAIL`, `IS_CONTROL`, `IS_RECONCILABLE`, `IS_ACTIVE`: Switch (Y/N)
  - أعمدة التدقيق مخفية (Hidden).

---

## 4. علامة التبويب 2: قطاعات الحسابات (COA Segments)
### الشبكة التفاعلية (Interactive Grid)
- **العنوان:** إعدادات القطاعات
- **الاستعلام (SQL Query):**
```sql
SELECT 
    SEGMENT_ID,
    SEGMENT_NUM,
    SEGMENT_CODE,
    SEGMENT_NAME_EN,
    SEGMENT_NAME_AR,
    SEGMENT_TYPE,
    MAX_LENGTH,
    IS_REQUIRED,
    IS_ACTIVE,
    CREATED_BY, CREATION_DATE, UPDATED_BY, UPDATE_DATE
FROM POS_COA_SEGMENTS
```
- **أعمدة (Page Items):**
  - `SEGMENT_TYPE`: LOV (COMPANY/COST_CENTER/ACCOUNT/PRODUCT/INTERCOMPANY/FUTURE)
  - `IS_REQUIRED`, `IS_ACTIVE`: Switch (Y/N)

---

## 5. علامة التبويب 3: الفترات المالية (GL Periods)
### الشبكة التفاعلية (Interactive Grid)
- **العنوان:** الفترات المالية
- **الاستعلام (SQL Query):**
```sql
SELECT 
    PERIOD_ID,
    LEGAL_ENTITY_ID,
    PERIOD_NAME,
    PERIOD_YEAR,
    PERIOD_NUM,
    START_DATE,
    END_DATE,
    CLOSE_STATUS,
    CREATED_BY, CREATION_DATE, UPDATED_BY, UPDATE_DATE
FROM POS_GL_PERIODS
WHERE LEGAL_ENTITY_ID = NVL(:AI_LE_LIST, LEGAL_ENTITY_ID)
```
- **أعمدة (Page Items):**
  - `CLOSE_STATUS`: Status Badge (مفتوحة OPEN / مغلقة CLOSED / مغلقة نهائياً PERMANENTLY_CLOSED / مستقبلية FUTURE).
  - زر **إغلاق الفترة (Close Period)** في الـ Grid Action Menu.

### الإجراءات (Processes & Ajax Callbacks)
- **إغلاق الفترة (Ajax Callback):**
```plsql
BEGIN
    UPDATE POS_GL_PERIODS
    SET CLOSE_STATUS = 'CLOSED',
        UPDATED_BY = :AI_USER_NAME,
        UPDATE_DATE = SYSDATE
    WHERE PERIOD_ID = APEX_APPLICATION.G_X01;
    COMMIT;
END;
```

---

## 6. إجراءات الحفظ التلقائية (Automatic DML)
لكل شبكة تفاعلية، أضف عملية `Interactive Grid - Automatic Row Processing (DML)` وتأكد من تحديث بيانات التدقيق `CREATED_BY`، `CREATION_DATE` وغيرها في الـ PL/SQL Code أو الـ Triggers.
