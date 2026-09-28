# دليل تنفيذ صفحة 320: إدارة العملاء (Customers)

## 1. إعدادات الصفحة (Page Creation)
- **رقم الصفحة:** 320
- **اسم الصفحة:** إدارة العملاء (Customers)
- **نمط الصفحة (Mode):** Normal
- **القالب (Template):** Standard
- **نظام الصلاحيات (Authorization Scheme):** `AUTH_NOT_CASHIER`

## 2. استعلامات SQL (SQL Queries)

### منطقة 1: شبكة العملاء التفاعلية (Interactive Grid - Customers)
- **النوع:** Interactive Grid
- **العنوان:** بيانات العملاء
- **الاستعلام:**
```sql
SELECT 
    CUSTOMER_ID,
    CUSTOMER_CODE,
    CUSTOMER_NAME_AR,
    CUSTOMER_NAME_EN,
    CUSTOMER_TYPE,
    TAX_REGISTRATION_NO,
    NATIONAL_ID,
    EMAIL,
    PHONE,
    ALT_PHONE,
    ADDRESS_LINE1,
    ADDRESS_LINE2,
    CITY,
    COUNTRY_CODE,
    CREDIT_LIMIT,
    CREDIT_USED,
    (NVL(CREDIT_LIMIT, 0) - NVL(CREDIT_USED, 0)) AS CREDIT_AVAILABLE,
    PAYMENT_TERMS,
    INV_ORG_ID,
    IS_ACTIVE,
    CREATED_BY,
    CREATION_DATE,
    LAST_UPDATED_BY,
    LAST_UPDATE_DATE
FROM POS_CUSTOMERS
WHERE INV_ORG_ID IN (SELECT TO_NUMBER(COLUMN_VALUE) FROM TABLE(APEX_STRING.SPLIT(:AI_ORG_LIST, ',')))
```

## 3. عناصر الصفحة والقوائم (Page Items & LOVs)

### قوائم القيم (LOVs) للشبكة التفاعلية:
1. **نوع العميل (CUSTOMER_TYPE):**
   - **النوع:** Static
   - **القيم:** فرد (INDIVIDUAL), شركة (COMPANY), حكومي (GOVERNMENT), عميل عابر (WALK_IN)
2. **شروط الدفع (PAYMENT_TERMS):**
   - **النوع:** Static
   - **القيم:** نقدي (CASH), 15 يوم (NET_15), 30 يوم (NET_30), 60 يوم (NET_60), 90 يوم (NET_90)
3. **فرع المخزون (INV_ORG_ID):**
   - **النوع:** Shared Component (Dynamic)
   - **الاستعلام:** `SELECT ORG_NAME_AR, INV_ORG_ID FROM POS_INVENTORY_ORGS WHERE INV_ORG_ID IN (SELECT TO_NUMBER(COLUMN_VALUE) FROM TABLE(APEX_STRING.SPLIT(:AI_ORG_LIST, ',')))`

### إعدادات الأعمدة:
- **CREDIT_AVAILABLE:** نوعه (Display Only).
- **IS_ACTIVE:** نوعه (Switch)، القيم (Y/N).
- **أعمدة التدقيق (Audit):** مخفية (Hidden)، (CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE).

## 4. العمليات ومعالجة البيانات (Processes / Ajax Callbacks)

### معالجة حفظ العملاء (Save Interactive Grid Data)
- **النوع:** Interactive Grid - Automatic Row Processing (DML)
- **Target Type:** POS_CUSTOMERS
- **PL/SQL لمعالجة الحفظ التلقائي (لأعمدة التدقيق):**
```plsql
BEGIN
    IF :APEX$ROW_STATUS = 'C' THEN
        :CREATED_BY := :AI_USER_NAME;
        :CREATION_DATE := SYSTIMESTAMP;
        :LAST_UPDATED_BY := :AI_USER_NAME;
        :LAST_UPDATE_DATE := SYSTIMESTAMP;
        
        IF :CUSTOMER_ID IS NULL THEN
            :CUSTOMER_ID := POS_CUSTOMERS_SEQ.NEXTVAL;
        END IF;
    ELSIF :APEX$ROW_STATUS = 'U' THEN
        :LAST_UPDATED_BY := :AI_USER_NAME;
        :LAST_UPDATE_DATE := SYSTIMESTAMP;
    END IF;
END;
```

## 5. الإجراءات الديناميكية (Dynamic Actions)

- **الزر:** `BTN_ORDER_HISTORY` (سجل طلبات العميل)
  - **النوع:** زر داخل الشبكة أو كإجراء (Row Action) للشبكة التفاعلية.
  - **Dynamic Action:** توجيه للصفحة الخاصة بطلبات العملاء (مثلاً صفحة 325) مع تمرير قيمة `CUSTOMER_ID`.
