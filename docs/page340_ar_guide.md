# دليل تنفيذ صفحة 340: حسابات العملاء — الذمم المدينة (AR)

## 1. إعدادات الصفحة (Page Creation)
- **رقم الصفحة:** 340
- **اسم الصفحة:** الذمم المدينة (Accounts Receivable)
- **نمط الصفحة (Mode):** Normal
- **القالب (Template):** Standard - Tabs
- **نظام الصلاحيات (Authorization Scheme):** `AUTH_FINANCE_ONLY`

## 2. استعلامات SQL (SQL Queries)

### التبويب 1: فواتير العملاء (Interactive Report - AR Invoices)
- **الاستعلام:**
```sql
SELECT 
    I.AR_INVOICE_ID, I.INVOICE_NO, C.CUSTOMER_NAME_AR AS CUSTOMER_NAME,
    I.INVOICE_DATE, I.DUE_DATE, I.INVOICE_TYPE,
    I.INVOICE_AMOUNT, I.TAX_AMOUNT, I.TOTAL_AMOUNT,
    I.AMOUNT_APPLIED, I.AMOUNT_DUE, I.STATUS, I.PAYMENT_TERMS
FROM POS_AR_INVOICES I
JOIN POS_CUSTOMERS C ON I.CUSTOMER_ID = C.CUSTOMER_ID
WHERE I.INV_ORG_ID IN (SELECT TO_NUMBER(COLUMN_VALUE) FROM TABLE(APEX_STRING.SPLIT(:AI_ORG_LIST, ',')))
```
*(إضافة HTML Expression لعمود STATUS لإظهار Badges ولون مختلف للمبالغ المستحقة).*

### التبويب 2: المقبوضات (Interactive Grid - AR Receipts)
- **الاستعلام:**
```sql
SELECT 
    R.RECEIPT_ID, R.RECEIPT_NO, R.CUSTOMER_ID, R.RECEIPT_DATE, 
    R.PAYMENT_METHOD_ID, R.AMOUNT, R.APPLIED_AMOUNT, R.UNAPPLIED_AMOUNT, R.STATUS,
    R.CREATED_BY, R.CREATION_DATE
FROM POS_AR_RECEIPTS R
WHERE R.INV_ORG_ID IN (SELECT TO_NUMBER(COLUMN_VALUE) FROM TABLE(APEX_STRING.SPLIT(:AI_ORG_LIST, ',')))
```

### التبويب 3: تسوية المقبوضات (Interactive Grid - Receipt Applications)
- **الاستعلام:**
```sql
SELECT 
    A.APPLICATION_ID, A.RECEIPT_ID, A.AR_INVOICE_ID, A.APPLIED_AMOUNT, A.APPLICATION_DATE
FROM POS_AR_RECEIPT_APPLICATIONS A
WHERE A.RECEIPT_ID = :P340_RECEIPT_ID
```

### التبويب 4: تقرير أعمار الديون (Aging Report)
- **النوع:** Classic Report / Cards
- **الاستعلام:**
```sql
SELECT 
    C.CUSTOMER_NAME_AR,
    SUM(CASE WHEN TRUNC(SYSDATE) <= I.DUE_DATE THEN I.AMOUNT_DUE ELSE 0 END) AS CURRENT_BAL,
    SUM(CASE WHEN TRUNC(SYSDATE) - I.DUE_DATE BETWEEN 1 AND 30 THEN I.AMOUNT_DUE ELSE 0 END) AS DAYS_1_30,
    SUM(CASE WHEN TRUNC(SYSDATE) - I.DUE_DATE BETWEEN 31 AND 60 THEN I.AMOUNT_DUE ELSE 0 END) AS DAYS_31_60,
    SUM(CASE WHEN TRUNC(SYSDATE) - I.DUE_DATE BETWEEN 61 AND 90 THEN I.AMOUNT_DUE ELSE 0 END) AS DAYS_61_90,
    SUM(CASE WHEN TRUNC(SYSDATE) - I.DUE_DATE > 90 THEN I.AMOUNT_DUE ELSE 0 END) AS DAYS_OVER_90,
    SUM(I.AMOUNT_DUE) AS TOTAL_DUE
FROM POS_AR_INVOICES I
JOIN POS_CUSTOMERS C ON I.CUSTOMER_ID = C.CUSTOMER_ID
WHERE I.AMOUNT_DUE > 0
GROUP BY C.CUSTOMER_NAME_AR
```

## 3. عناصر الصفحة والقوائم (Page Items & LOVs)
- **حقل P340_RECEIPT_ID:** حقل مخفي لربط تفاصيل التسويات.
- **LOV للعميل:** `SELECT CUSTOMER_NAME_AR, CUSTOMER_ID FROM POS_CUSTOMERS`
- **LOV للفاتورة والتسوية:** `SELECT INVOICE_NO, AR_INVOICE_ID FROM POS_AR_INVOICES WHERE AMOUNT_DUE > 0 AND CUSTOMER_ID = :CUSTOMER_ID`

## 4. العمليات ومعالجة البيانات (Processes / Ajax Callbacks)
- **تحديث المبالغ عند التسوية:** يجب عمل Trigger أو PL/SQL Process عند حفظ Application لتحديث `UNAPPLIED_AMOUNT` في الإيصال و `AMOUNT_DUE` و `AMOUNT_APPLIED` في الفاتورة.

## 5. الإجراءات الديناميكية (Dynamic Actions)
- ربط Master-Detail لشبكة التسويات (Receipt Applications) مع الإيصالات (AR Receipts) بنفس آلية `SET_SHIFT_SESSION` المشروحة في صفحة 330.
