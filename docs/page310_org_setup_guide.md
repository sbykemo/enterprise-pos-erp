# دليل تنفيذ صفحة 310: إعدادات الشركة والهيكل التنظيمي (Organization Setup)

## 1. إعدادات الصفحة (Page Setup)
* **رقم الصفحة (Page Number):** 310
* **اسم الصفحة (Page Name):** إعدادات الشركة والهيكل التنظيمي
* **وضع الصفحة (Page Mode):** Normal
* **القالب (Template):** Standard
* **مخطط التفويض (Authorization Scheme):** AUTH_MANAGER_UP

---

## 2. عناصر الصفحة (Page Items)
* **اسم العنصر:** `P310_SELECTED_INV_ORG_ID`
  * **النوع:** Hidden
  * **الوصف:** للربط بين الفروع (Inventory Orgs) والمخازن الفرعية (Subinventories).

---

## 3. مناطق الصفحة (Regions & SQL Queries)

### منطقة الحاوية (Tab Container)
* **النوع:** Region Display Selector أو Tabs Container
* يحتوي على 4 مناطق فرعية (Sub Regions).

### التبويب 1: الكيانات القانونية (Legal Entities)
* **النوع:** Interactive Grid
* **مصدر البيانات (SQL Query):**
```sql
SELECT LEGAL_ENTITY_ID,
       LEGAL_ENTITY_CODE,
       LEGAL_ENTITY_NAME,
       COUNTRY_CODE,
       TAX_REGISTRATION_NO,
       CURRENCY_CODE,
       FISCAL_YEAR_START_MONTH,
       LOGO_URL,
       ADDRESS_LINE1,
       ADDRESS_LINE2,
       CITY,
       PHONE,
       EMAIL,
       IS_ACTIVE
  FROM POS_LEGAL_ENTITIES
```
* **خصائص الأعمدة:**
  * `LEGAL_ENTITY_ID`: Primary Key, Hidden.
  * `LEGAL_ENTITY_CODE`: Text, العنوان: كود الكيان.
  * `LEGAL_ENTITY_NAME`: Text, العنوان: اسم الكيان.
  * `CURRENCY_CODE`: Text (Default: USD), العنوان: العملة.
  * `IS_ACTIVE`: Switch, العنوان: فعال؟.

### التبويب 2: وحدات التشغيل (Operating Units)
* **النوع:** Interactive Grid
* **مصدر البيانات (SQL Query):**
```sql
SELECT ORG_UNIT_ID,
       ORG_UNIT_CODE,
       ORG_UNIT_NAME,
       LEGAL_ENTITY_ID,
       ORG_TYPE,
       DEFAULT_CURRENCY_CODE,
       REPORTING_CURRENCY_CODE,
       IS_ACTIVE
  FROM POS_OPERATING_UNITS
```
* **خصائص الأعمدة:**
  * `ORG_UNIT_ID`: Primary Key, Hidden.
  * `LEGAL_ENTITY_ID`: Select List, العنوان: الكيان القانوني. (LOV: `SELECT LEGAL_ENTITY_NAME d, LEGAL_ENTITY_ID r FROM POS_LEGAL_ENTITIES`)
  * `ORG_TYPE`: Select List, العنوان: نوع الوحدة. (Static: HQ, BRANCH, WAREHOUSE, FRANCHISE)

### التبويب 3: الفروع والمخازن (Inventory Orgs & Subinventories)
**يحتوي على شبكتين (Master-Detail):**

**الشبكة الرئيسية (Master): الفروع**
* **النوع:** Interactive Grid
* **مصدر البيانات:**
```sql
SELECT INV_ORG_ID,
       INV_ORG_CODE,
       INV_ORG_NAME,
       ORG_UNIT_ID,
       PARENT_INV_ORG_ID,
       ORG_CATEGORY,
       SECTOR_TYPE,
       ADDRESS_LINE1,
       CITY,
       COUNTRY_CODE,
       PHONE,
       MANAGER_USER_ID,
       COSTING_METHOD,
       IS_ACTIVE
  FROM POS_INVENTORY_ORGS
```

**الشبكة التفصيلية (Detail): المخازن الفرعية**
* **النوع:** Interactive Grid
* **مصدر البيانات:**
```sql
SELECT SUBINV_ID,
       SUBINV_CODE,
       SUBINV_NAME,
       INV_ORG_ID,
       SUBINV_TYPE,
       IS_RESERVABLE,
       IS_ASSET_VALUED,
       IS_ACTIVE
  FROM POS_SUBINVENTORIES
 WHERE INV_ORG_ID = :P310_SELECTED_INV_ORG_ID
```
* `INV_ORG_ID` Default Value -> `P310_SELECTED_INV_ORG_ID`.

### التبويب 4: أجهزة نقاط البيع (POS Terminals)
* **النوع:** Interactive Grid
* **مصدر البيانات:**
```sql
SELECT TERMINAL_ID,
       TERMINAL_CODE,
       TERMINAL_NAME,
       INV_ORG_ID,
       TERMINAL_TYPE,
       PRINTER_IP,
       PRINTER_PORT,
       CASH_DRAWER_ENABLED,
       POLE_DISPLAY_ENABLED,
       IS_ACTIVE
  FROM POS_POS_TERMINALS
```
* **خصائص الأعمدة:**
  * `INV_ORG_ID`: Select List, العنوان: الفرع. (LOV: `SELECT INV_ORG_NAME d, INV_ORG_ID r FROM POS_INVENTORY_ORGS`).

---

## 4. الإجراءات الديناميكية (Dynamic Actions)

### الربط في التبويب الثالث (Master-Detail for Inv Orgs)
* **الحدث:** Selection Change [Interactive Grid] (Inv Orgs)
* **الإجراءات:** Set Value -> `P310_SELECTED_INV_ORG_ID`, Execute Server-Side Code, Refresh (Subinventories). (نفس آلية صفحة 300).

---

## 5. عمليات المعالجة (Processes)
* إعداد عمليات حفظ قياسية (Interactive Grid - Automatic Row Processing) لكل الجداول.
* إضافة تدقيق للمستخدمين باستخدام PL/SQL لتحديث (CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE) إذا كانت الأعمدة موجودة في الجداول.
