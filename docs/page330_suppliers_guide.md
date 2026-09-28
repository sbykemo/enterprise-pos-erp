# دليل تنفيذ صفحة 330: إدارة الموردين (Suppliers)

## 1. إعدادات الصفحة (Page Creation)
- **رقم الصفحة:** 330
- **اسم الصفحة:** إدارة الموردين (Suppliers)
- **نمط الصفحة (Mode):** Normal
- **القالب (Template):** Standard - Tabs Container
- **نظام الصلاحيات (Authorization Scheme):** `AUTH_NOT_CASHIER`

## 2. استعلامات SQL (SQL Queries)

### التبويب الأول: الموردين (POS_SUPPLIERS)
- **النوع:** Interactive Grid
- **العنوان:** الموردين
- **الاستعلام:**
```sql
SELECT 
    SUPPLIER_ID, SUPPLIER_CODE, SUPPLIER_NAME_EN, SUPPLIER_NAME_AR,
    SUPPLIER_TYPE, TAX_REGISTRATION_NO, PAYMENT_TERMS, CREDIT_DAYS,
    CURRENCY_CODE, BANK_NAME, BANK_ACCOUNT_NO, IBAN,
    CONTACT_NAME, EMAIL, PHONE, ADDRESS_LINE1, ADDRESS_LINE2, COUNTRY_CODE,
    IS_ACTIVE,
    CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE
FROM POS_SUPPLIERS
```

### التبويب الثاني: أوامر الشراء (POS_PURCHASE_ORDERS - Master)
- **النوع:** Interactive Grid
- **العنوان:** أوامر الشراء
- **الاستعلام:**
```sql
SELECT 
    PO_ID, PO_NO, SUPPLIER_ID, INV_ORG_ID, PO_DATE, EXPECTED_DATE,
    PO_STATUS, CURRENCY_CODE, EXCHANGE_RATE, SUBTOTAL, TAX_AMOUNT, TOTAL_AMOUNT,
    APPROVED_BY, APPROVED_DATE, NOTES,
    CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE
FROM POS_PURCHASE_ORDERS
WHERE INV_ORG_ID IN (SELECT TO_NUMBER(COLUMN_VALUE) FROM TABLE(APEX_STRING.SPLIT(:AI_ORG_LIST, ',')))
```

### التبويب الثاني: تفاصيل أمر الشراء (POS_PO_LINES - Detail)
- **النوع:** Interactive Grid
- **العنوان:** تفاصيل أمر الشراء
- **الاستعلام:**
```sql
SELECT 
    PO_LINE_ID, PO_ID, LINE_NO, ITEM_ID, VARIANT_ID, UOM_CODE,
    ORDERED_QTY, RECEIVED_QTY, UNIT_PRICE, 
    (ORDERED_QTY * UNIT_PRICE) AS LINE_AMOUNT,
    TAX_RATE, TAX_AMOUNT, LINE_TOTAL, STATUS,
    CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE
FROM POS_PO_LINES
WHERE PO_ID = :P330_PO_ID
```
*(ربط الماستر والتفاصيل عن طريق Ajax Callback `SET_SHIFT_SESSION` لتعيين P330_PO_ID)*

## 3. عناصر الصفحة والقوائم (Page Items & LOVs)

### قوائم القيم (LOVs):
1. **الموردين - نوع المورد (SUPPLIER_TYPE):** بضائع (GOODS), خدمات (SERVICE), كلاهما (BOTH)
2. **أوامر الشراء - المورد (SUPPLIER_ID):** 
   - `SELECT SUPPLIER_NAME_AR, SUPPLIER_ID FROM POS_SUPPLIERS WHERE IS_ACTIVE = 'Y'`
3. **تفاصيل الأمر - الصنف (ITEM_ID):** 
   - `SELECT ITEM_NAME_AR, ITEM_ID FROM POS_ITEMS`

### إعدادات الأعمدة:
- **STATUS (PO & Lines):** للقراءة فقط، تُدار عبر الأزرار (Draft, Submitted, Approved...).
- **LINE_AMOUNT:** حقل محسوب للقراءة فقط (Display Only).

## 4. العمليات ومعالجة البيانات (Processes / Ajax Callbacks)

### Ajax Callback (Master-Detail Linking)
- **الاسم:** `SET_PO_ID`
- **PL/SQL:**
```plsql
BEGIN
    APEX_UTIL.SET_SESSION_STATE('P330_PO_ID', APEX_APPLICATION.G_X01);
END;
```

### معالجة حفظ البيانات (DML)
- يتم تفعيل Automatic Row Processing لجميع الشبكات التفاعلية مع تعيين حقول `CREATED_BY`، `LAST_UPDATED_BY` وغيرها في حدث التهيئة كما في بقية الصفحات.

## 5. الإجراءات الديناميكية (Dynamic Actions)

### ربط الماستر بالتفاصيل:
- **الحدث:** Selection Change [Interactive Grid] لأوامر الشراء.
- **Action 1:** Execute JavaScript Code:
```javascript
var model = this.data.model;
var record = this.data.selectedRecords[0];
if (record) {
    var poId = model.getValue(record, "PO_ID");
    apex.server.process("SET_PO_ID", { x01: poId }, {
        success: function() {
            apex.region("po_lines_ig").refresh();
        }
    });
}
```

### سير العمل (Workflow Buttons):
- أزرار (إرسال، اعتماد، استلام) كـ Row Actions تقوم بتغيير الـ STATUS الخاص بأمر الشراء.
