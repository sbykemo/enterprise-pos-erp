# دليل تنفيذ صفحة 390: الجرد الدوري (Cycle Count)

## 1. إعدادات الصفحة (Page Creation)
- **رقم الصفحة (Page Number):** 390
- **اسم الصفحة (Page Name):** الجرد الدوري
- **نمط الصفحة (Page Mode):** Normal
- **نظام الصلاحيات (Authorization Scheme):** `AUTH_MANAGER_UP`

## 2. بنية الصفحة (Page Structure)
صفحة من نوع Master-Detail باستخدام Interactive Report للرئيسي (Headers) و Interactive Grid للتفاصيل (Lines).

---

## 3. المنطقة الرئيسية (Master IR - Cycle Count Headers)
- **العنوان:** حركات الجرد
- **الاستعلام (SQL Query):**
```sql
SELECT 
    CYCLE_COUNT_ID,
    COUNT_NO,
    INV_ORG_ID,
    SUBINV_ID,
    COUNT_TYPE,
    STATUS,
    PLANNED_DATE,
    ACTUAL_START_DATE,
    ACTUAL_END_DATE,
    NOTES,
    CREATED_BY, CREATION_DATE
FROM POS_CYCLE_COUNT_HEADERS
WHERE INV_ORG_ID = NVL(:AI_ORG_LIST, INV_ORG_ID)
```
- **ارتباط (Link):** إضافة رابط (Link) على `COUNT_NO` لتعيين `P390_CYCLE_COUNT_ID` وعمل Refresh لشبكة التفاصيل.

---

## 4. المنطقة التفصيلية (Detail IG - Cycle Count Lines)
- **العنوان:** بنود الجرد
- **الاستعلام (SQL Query):**
```sql
SELECT 
    COUNT_LINE_ID,
    CYCLE_COUNT_ID,
    ITEM_ID,
    VARIANT_ID,
    SUBINV_ID,
    SYSTEM_QTY,
    COUNTED_QTY,
    (NVL(COUNTED_QTY, 0) - NVL(SYSTEM_QTY, 0)) AS VARIANCE_QTY,
    UNIT_COST,
    ((NVL(COUNTED_QTY, 0) - NVL(SYSTEM_QTY, 0)) * NVL(UNIT_COST, 0)) AS VARIANCE_VALUE,
    STATUS,
    COUNTED_BY,
    COUNTED_DATE
FROM POS_CYCLE_COUNT_LINES
WHERE CYCLE_COUNT_ID = :P390_CYCLE_COUNT_ID
```
- **أعمدة محتسبة:** `VARIANCE_QTY` و `VARIANCE_VALUE` أعمدة Read-only (Display Only).
- **تمييز الألوان (Highlighting):** استخدام Conditional Formatting بالألوان (أحمر للسالب، أخضر للموجب) لعمود الفروقات.

---

## 5. الإجراءات (Actions & Processes)
- أزرار في شريط الأدوات (Toolbar):
  - **Start Count**: تغيير حالة الرئيسي إلى IN_PROGRESS.
  - **Complete Count**: تغيير حالة الرئيسي إلى COMPLETED وتحديث التفاصيل.
  - **Approve & Adjust Inventory**: الموافقة وإصدار تسويات المخزون (ينادي إجراء مخزن PL/SQL).
