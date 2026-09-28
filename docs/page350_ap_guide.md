# دليل تنفيذ صفحة 350: حسابات الموردين — الذمم الدائنة (AP)

## 1. إعدادات الصفحة (Page Creation)
- **رقم الصفحة:** 350
- **اسم الصفحة:** الذمم الدائنة (Accounts Payable)
- **نمط الصفحة (Mode):** Normal
- **القالب (Template):** Standard - Tabs
- **نظام الصلاحيات (Authorization Scheme):** `AUTH_FINANCE_ONLY`

## 2. استعلامات SQL (SQL Queries)

### التبويب 1: فواتير الموردين (Interactive Report - AP Invoices)
- **الاستعلام:**
```sql
SELECT 
    I.AP_INVOICE_ID, I.INVOICE_NO, S.SUPPLIER_NAME_AR AS SUPPLIER_NAME,
    I.INVOICE_DATE, I.DUE_DATE, I.TOTAL_AMOUNT, I.AMOUNT_PAID, 
    (I.TOTAL_AMOUNT - I.AMOUNT_PAID) AS AMOUNT_REMAINING,
    I.STATUS, I.HOLD_REASON, I.THREE_WAY_MATCH_STATUS
FROM POS_AP_INVOICES I
JOIN POS_SUPPLIERS S ON I.SUPPLIER_ID = S.SUPPLIER_ID
WHERE I.INV_ORG_ID IN (SELECT TO_NUMBER(COLUMN_VALUE) FROM TABLE(APEX_STRING.SPLIT(:AI_ORG_LIST, ',')))
```
*(إضافة HTML Expression للأعمدة: Status و Three-Way Match لإظهار Badges).*

### التبويب 2: المدفوعات (Interactive Grid - AP Payments)
- **الاستعلام:**
```sql
SELECT 
    P.AP_PAYMENT_ID, P.PAYMENT_NO, P.SUPPLIER_ID, P.AP_INVOICE_ID, 
    P.PAYMENT_DATE, P.PAYMENT_METHOD, P.AMOUNT, P.REFERENCE, P.STATUS,
    P.CREATED_BY, P.CREATION_DATE
FROM POS_AP_PAYMENTS P
WHERE P.INV_ORG_ID IN (SELECT TO_NUMBER(COLUMN_VALUE) FROM TABLE(APEX_STRING.SPLIT(:AI_ORG_LIST, ',')))
```

### التبويب 3: تقرير أعمار ذمم الموردين (Payment Aging Report)
- **النوع:** Classic Report / Cards
- **الاستعلام:**
```sql
SELECT 
    S.SUPPLIER_NAME_AR,
    SUM(CASE WHEN TRUNC(SYSDATE) <= I.DUE_DATE THEN (I.TOTAL_AMOUNT - I.AMOUNT_PAID) ELSE 0 END) AS CURRENT_BAL,
    SUM(CASE WHEN TRUNC(SYSDATE) - I.DUE_DATE BETWEEN 1 AND 30 THEN (I.TOTAL_AMOUNT - I.AMOUNT_PAID) ELSE 0 END) AS DAYS_1_30,
    SUM(CASE WHEN TRUNC(SYSDATE) - I.DUE_DATE > 30 THEN (I.TOTAL_AMOUNT - I.AMOUNT_PAID) ELSE 0 END) AS DAYS_OVER_30,
    SUM(I.TOTAL_AMOUNT - I.AMOUNT_PAID) AS TOTAL_DUE
FROM POS_AP_INVOICES I
JOIN POS_SUPPLIERS S ON I.SUPPLIER_ID = S.SUPPLIER_ID
WHERE (I.TOTAL_AMOUNT - I.AMOUNT_PAID) > 0
GROUP BY S.SUPPLIER_NAME_AR
```

## 3. عناصر الصفحة والقوائم (Page Items & LOVs)
- **المورد:** `SELECT SUPPLIER_NAME_AR, SUPPLIER_ID FROM POS_SUPPLIERS`
- **الفاتورة:** `SELECT INVOICE_NO, AP_INVOICE_ID FROM POS_AP_INVOICES WHERE SUPPLIER_ID = :SUPPLIER_ID`

## 4. العمليات ومعالجة البيانات (Processes / Ajax Callbacks)
- **معالجة الأزرار (Hold/Release/Approve):**
  - إنشاء PL/SQL Process لتحديث حالة الفاتورة (STATUS) بناءً على الإجراء المتخذ من تقرير الفواتير.

## 5. الإجراءات الديناميكية (Dynamic Actions)
- **زر تعليق (Hold):** إظهار Region/Modal يطلب إدخال سبب التعليق (HOLD_REASON) ثم تشغيل عملية PL/SQL لتحديث الحالة إلى `ON_HOLD`.
- **زر الاعتماد (Approve):** تغيير الحالة إلى `APPROVED` بعد التحقق من حالة المطابقة الثلاثية (`THREE_WAY_MATCH_STATUS`).
