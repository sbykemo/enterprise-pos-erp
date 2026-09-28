# دليل تنفيذ صفحة 370: قواعد الترحيل المحاسبي (SLA Rules)

## 1. إعدادات الصفحة (Page Creation)
- **رقم الصفحة (Page Number):** 370
- **اسم الصفحة (Page Name):** قواعد الترحيل المحاسبي
- **نمط الصفحة (Page Mode):** Normal
- **قالب الصفحة (Page Template):** Theme Default
- **نظام الصلاحيات (Authorization Scheme):** `AUTH_FINANCE_ONLY`

## 2. بنية الصفحة (Page Structure)
تحتوي الصفحة على منطقة واحدة من نوع شبكة تفاعلية (Interactive Grid) لجدول `POS_SLA_RULES`.

---

## 3. الشبكة التفاعلية (Interactive Grid)
- **العنوان:** قواعد الترحيل (SLA Rules)
- **الاستعلام (SQL Query):**
```sql
SELECT 
    RULE_ID,
    RULE_CODE,
    RULE_NAME,
    SOURCE,
    TXN_TYPE,
    LINE_TYPE,
    DEBIT_ACCOUNT_ID,
    CREDIT_ACCOUNT_ID,
    AMOUNT_TYPE,
    IS_ACTIVE,
    PRIORITY,
    CREATED_BY, CREATION_DATE, UPDATED_BY, UPDATE_DATE
FROM POS_SLA_RULES
ORDER BY PRIORITY ASC
```

### إعدادات الأعمدة (Columns Settings)
- **`DEBIT_ACCOUNT_ID` و `CREDIT_ACCOUNT_ID`:** 
  - نوع العنصر: Popup LOV
  - استعلام LOV:
    ```sql
    SELECT ACCOUNT_NAME_AR || ' - ' || ACCOUNT_CODE AS d, ACCOUNT_ID AS r
    FROM POS_COA_ACCOUNTS
    WHERE IS_DETAIL = 'Y' AND IS_ACTIVE = 'Y'
    ```
- **`SOURCE`:**
  - نوع العنصر: Select List
  - يعتمد على القيم المسموحة في `POS_GL_JOURNALS.SOURCE`.
- **`AMOUNT_TYPE`:**
  - نوع العنصر: Select List
  - القيم: (إجمالي فرعي SUBTOTAL / ضريبة TAX / خصم DISCOUNT / تكلفة COST / إجمالي TOTAL / تقريب ROUNDING).
- **`IS_ACTIVE`:** Switch (Y/N).
- **`PRIORITY`:** Editable Number Field.
- أعمدة التدقيق `CREATED_BY`, `CREATION_DATE`, `UPDATED_BY`, `UPDATE_DATE` يتم إخفاؤها.

---

## 4. الإجراءات (Processes)
- أضف عملية `Interactive Grid - Automatic Row Processing (DML)`.
- تأكد من تعيين أعمدة التدقيق `CREATED_BY` و `CREATION_DATE` إما عن طريق `Default Value` للإدراج، أو من خلال مشغلات قاعدة البيانات (Triggers).
