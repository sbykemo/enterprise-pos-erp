# دليل تنفيذ صفحة 380: إعدادات الضرائب

## 1. إعدادات الصفحة (Page Creation)
- **رقم الصفحة (Page Number):** 380
- **اسم الصفحة (Page Name):** إعدادات الضرائب
- **نمط الصفحة (Page Mode):** Normal
- **قالب الصفحة (Page Template):** Theme Default
- **نظام الصلاحيات (Authorization Scheme):** `AUTH_FINANCE_ONLY`

## 2. بنية الصفحة (Page Structure)
استخدم (Tabs Container) يحتوي على 4 علامات تبويب:
1. أنظمة الضرائب (Tax Regimes)
2. أنواع ونسب الضرائب (Tax Types & Rates - Master-Detail)
3. قواعد الضرائب (Tax Rules)
4. الإعفاءات الضريبية (Tax Exemptions)

---

## 3. علامة التبويب 1: أنظمة الضرائب
### الشبكة التفاعلية (Interactive Grid)
- **العنوان:** أنظمة الضرائب
- **الاستعلام (SQL Query):**
```sql
SELECT 
    REGIME_ID, REGIME_CODE, REGIME_NAME, COUNTRY_CODE, TAX_AUTHORITY, IS_ACTIVE,
    CREATED_BY, CREATION_DATE, UPDATED_BY, UPDATE_DATE
FROM POS_TAX_REGIMES
```

---

## 4. علامة التبويب 2: أنواع ونسب الضرائب (Master-Detail)
### المنطقة الرئيسية (Master - Tax Types)
- **العنوان:** أنواع الضرائب
- **الاستعلام (SQL Query):**
```sql
SELECT 
    TAX_TYPE_ID, REGIME_ID, TAX_CODE, TAX_NAME_EN, TAX_NAME_AR, TAX_CLASS, COMPOUND_ON, IS_RECOVERABLE, IS_ACTIVE,
    CREATED_BY, CREATION_DATE, UPDATED_BY, UPDATE_DATE
FROM POS_TAX_TYPES
```
- **TAX_CLASS LOV:** VAT/GST/EXCISE/WITHHOLDING/COMPOUND/STAMP
- **REGIME_ID:** Popup LOV من `POS_TAX_REGIMES`

### المنطقة التفصيلية (Detail - Tax Rates)
- **العنوان:** نسب الضرائب
- **الربط (Master Detail):** اربط العمود `TAX_TYPE_ID` مع الشبكة الرئيسية.
- **الاستعلام (SQL Query):**
```sql
SELECT 
    TAX_RATE_ID, TAX_TYPE_ID, RATE_CODE, RATE_PERCENT, EFFECTIVE_FROM, EFFECTIVE_TO, IS_ZERO_RATED, IS_EXEMPT, IS_ACTIVE,
    CREATED_BY, CREATION_DATE, UPDATED_BY, UPDATE_DATE
FROM POS_TAX_RATES
```

---

## 5. علامة التبويب 3: قواعد الضرائب (Tax Rules)
### الشبكة التفاعلية (Interactive Grid)
- **العنوان:** قواعد الضرائب
- **الاستعلام (SQL Query):**
```sql
SELECT 
    RULE_ID, TAX_RATE_ID, RULE_NAME, PRIORITY, LEGAL_ENTITY_ID, INV_ORG_ID, CATEGORY_ID, ITEM_ID, CUSTOMER_TYPE, CUSTOMER_ID, IS_EXEMPT, EXEMPT_REASON, IS_ACTIVE,
    CREATED_BY, CREATION_DATE, UPDATED_BY, UPDATE_DATE
FROM POS_TAX_RULES
ORDER BY PRIORITY ASC
```

---

## 6. علامة التبويب 4: الإعفاءات الضريبية (Tax Exemptions)
### الشبكة التفاعلية (Interactive Grid)
- **العنوان:** الإعفاءات الضريبية
- **الاستعلام (SQL Query):**
```sql
SELECT 
    EXEMPTION_ID, EXEMPTION_NO, CUSTOMER_ID, ITEM_ID, CATEGORY_ID, TAX_TYPE_ID, EXEMPTION_PERCENT, VALID_FROM, VALID_TO, EXEMPTION_REASON, IS_ACTIVE,
    CREATED_BY, CREATION_DATE, UPDATED_BY, UPDATE_DATE
FROM POS_TAX_EXEMPTIONS
```
