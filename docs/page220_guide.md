# 💰 Page 220: إدارة قوائم الأسعار والعروض الترويجية (Pricing & Promotions)

---

## 🗺️ ما الذي سنبنيه في هذه الشاشة؟

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│  [Section A]  📋 قوائم الأسعار (Price Lists)                                    │
│  Interactive Grid: STANDARD / SEASONAL / BRANCH_SPECIFIC / PROMOTIONAL / VIP   │
│  [الكود] [الاسم] [النوع] [العملة] [الفرع] [القائمة الأم] [من-إلى] [نشط] [أسعار]│
├─────────────────────────────────────────────────────────────────────────────────┤
│  [Section B]  💲 أسعار الأصناف في القائمة المحددة (Price List Lines)            │
│  Interactive Grid: يظهر عند اختيار قائمة في Section A                          │
│  [الصنف] [المتغير] [الوحدة] [سعر البيع] [السعر الأدنى] [السعر الأقصى] [حالة]  │
├─────────────────────────────────────────────────────────────────────────────────┤
│  [Section C]  🎁 العروض والخصومات الترويجية (Promotions & Campaigns)           │
│  Interactive Grid: إدارة العروض الترويجية وقواعدها                              │
│  [كود العرض] [النوع] [٪ خصم] [من-إلى] [الحد الأدنى] [قابل للتكديس؟] [نشط]   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 🔗 ما الذي تتحكم فيه هذه الشاشة؟
- **سعر البيع الفعلي في الكاشير** = `POS_PRICE_LIST_LINES.LIST_PRICE` ← هذه الشاشة هي التي تتحكم فيه!
- **الحد الأدنى للسعر** = `POS_ITEMS.MIN_SALE_PRICE` ← تُحدَّد في Page 210
- **العروض الترويجية** = `POS_PROMOTIONS` ← تُطبَّق تلقائياً في الكاشير عند استيفاء الشروط

---

## ⚙️ المرحلة 0: إنشاء الـ Triggers المطلوبة قبل البناء

> [!IMPORTANT]
> شغّل هذا الكود **أولاً** في SQL Workshop ➔ SQL Commands قبل أي خطوة أخرى:

```sql
-- Trigger لـ POS_PRICE_LISTS (توليد PK تلقائياً)
CREATE OR REPLACE TRIGGER POS_PRICE_LISTS_BIR
BEFORE INSERT ON POS_PRICE_LISTS
FOR EACH ROW
BEGIN
    IF :NEW.PRICE_LIST_ID IS NULL THEN
        SELECT NVL(MAX(PRICE_LIST_ID), 1000000) + 1
          INTO :NEW.PRICE_LIST_ID
          FROM POS_PRICE_LISTS;
    END IF;
    IF :NEW.CREATION_DATE IS NULL THEN :NEW.CREATION_DATE := SYSDATE; END IF;
    :NEW.LAST_UPDATE_DATE := SYSDATE;
END;
/

-- Trigger لـ POS_PRICE_LIST_LINES (توليد PK تلقائياً)
CREATE OR REPLACE TRIGGER POS_PRICE_LIST_LINES_BIR
BEFORE INSERT ON POS_PRICE_LIST_LINES
FOR EACH ROW
BEGIN
    IF :NEW.PRICE_LINE_ID IS NULL THEN
        SELECT NVL(MAX(PRICE_LINE_ID), 1000000) + 1
          INTO :NEW.PRICE_LINE_ID
          FROM POS_PRICE_LIST_LINES;
    END IF;
    IF :NEW.CREATION_DATE IS NULL THEN :NEW.CREATION_DATE := SYSDATE; END IF;
    :NEW.LAST_UPDATE_DATE := SYSDATE;
END;
/

-- Trigger لـ POS_PROMOTIONS (توليد PK تلقائياً)
CREATE OR REPLACE TRIGGER POS_PROMOTIONS_BIR
BEFORE INSERT ON POS_PROMOTIONS
FOR EACH ROW
BEGIN
    IF :NEW.PROMO_ID IS NULL THEN
        SELECT NVL(MAX(PROMO_ID), 1000000) + 1
          INTO :NEW.PROMO_ID
          FROM POS_PROMOTIONS;
    END IF;
    IF :NEW.CREATION_DATE IS NULL THEN :NEW.CREATION_DATE := SYSDATE; END IF;
    :NEW.LAST_UPDATE_DATE := SYSDATE;
END;
/

-- التحقق من نجاح الإنشاء
SELECT TRIGGER_NAME, STATUS
FROM USER_TRIGGERS
WHERE TABLE_NAME IN ('POS_PRICE_LISTS','POS_PRICE_LIST_LINES','POS_PROMOTIONS')
ORDER BY TABLE_NAME;
```

**النتيجة المتوقعة:**
| TRIGGER_NAME | STATUS |
|---|---|
| POS_PRICE_LIST_LINES_BIR | ENABLED |
| POS_PRICE_LISTS_BIR | ENABLED |
| POS_PROMOTIONS_BIR | ENABLED |

---

## 🏗️ المرحلة 1: إنشاء الصفحة 220

1. اضغط على أيقونة **`+`** (Create) في الشريط العلوي في App Builder.
2. اختر **`Page`**.
3. اختر **`Blank Page`**.
4. في معالج الصفحة، اضبط:
   - **Page Number:** `220`
   - **Name:** `Pricing & Promotions`
   - **Page Mode:** `Normal`
   - **Navigation Menu Entry:** ✅ (لإضافتها في القائمة الجانبية)
5. اضغط **`Create Page`**.

---

## 🎨 المرحلة 2: إضافة CSS مخصص للصفحة

1. في شجرة اليسار، اضغط على **`Page 220: Pricing & Promotions`** (أعلى الشجرة تماماً).
2. في لوحة الخصائص باليمين، اضغط على قسم **`CSS`**.
3. في حقل **`Inline`**، انسخ والصق هذا الكود:

```css
/* ===== PAGE 220: PRICING & PROMOTIONS ===== */
.pos-price-section-header {
    background: linear-gradient(135deg, #0f172a, #1e3a5f);
    color: white; padding: 10px 18px; border-radius: 8px;
    font-weight: 700; font-size: 1rem; margin-bottom: 10px;
    display: flex; align-items: center; gap: 8px;
}
.pos-badge-standard    { background:#0284c7; color:white; padding:2px 10px; border-radius:12px; font-size:0.78rem; font-weight:600; }
.pos-badge-seasonal    { background:#d97706; color:white; padding:2px 10px; border-radius:12px; font-size:0.78rem; font-weight:600; }
.pos-badge-vip         { background:#7c3aed; color:white; padding:2px 10px; border-radius:12px; font-size:0.78rem; font-weight:600; }
.pos-badge-promo       { background:#dc2626; color:white; padding:2px 10px; border-radius:12px; font-size:0.78rem; font-weight:600; }
.pos-badge-branch      { background:#059669; color:white; padding:2px 10px; border-radius:12px; font-size:0.78rem; font-weight:600; }
.pos-price-tag         { color:#0284c7; font-weight:800; font-size:1.1rem; }
.pos-promo-active      { color:#059669; font-weight:700; }
.pos-promo-expired     { color:#dc2626; font-weight:700; }
```

---

## 🏗️ المرحلة 3: Page Item خفي للقائمة المحددة

> [!IMPORTANT]
> هذا الـ Item هو العنصر الرابط بين قائمة الأسعار (Section A) وأسعار الأصناف (Section B).
> بدونه لن تعمل العلاقة بين الجريدين.

1. في شجرة اليسار، اضغط بزر الأيمن على **`Body`** ➔ **`Create Page Item`**:
   - **Name:** `P220_SELECTED_PRICE_LIST_ID`
   - **Type:** `Hidden`
   - **Value Protected:** `No` *(مهم: لأن الجافاسكريبت سيعدله)*

---

## 🏗️ المرحلة 4: Section A - جريد قوائم الأسعار (Price Lists Grid)

### 4-أ: إنشاء المنطقة:
1. اضغط بزر الأيمن على **`Body`** ➔ **`Create Region`**:
   - **Title:** `📋 قوائم الأسعار (Price Lists)`
   - **Type:** `Interactive Grid`
   - **Static ID:** `price_lists_reg`

### 4-ب: الـ SQL Query:
في **`Source ➔ SQL Query`**، انسخ والصق:

```sql
SELECT
    pl.PRICE_LIST_ID,
    pl.PRICE_LIST_CODE,
    pl.PRICE_LIST_NAME,
    pl.PRICE_LIST_TYPE,
    pl.CURRENCY_CODE,
    pl.INV_ORG_ID,
    io.INV_ORG_NAME AS ORG_NAME,
    pl.PARENT_PRICE_LIST_ID,
    pp.PRICE_LIST_NAME AS PARENT_LIST_NAME,
    pl.PRIORITY,
    pl.START_DATE,
    pl.END_DATE,
    pl.IS_ACTIVE,
    -- عدد الأصناف المسعرة في هذه القائمة
    (SELECT COUNT(*) FROM POS_PRICE_LIST_LINES l WHERE l.PRICE_LIST_ID = pl.PRICE_LIST_ID) AS LINES_COUNT
FROM POS_PRICE_LISTS pl
LEFT JOIN POS_INVENTORY_ORGS io ON io.INV_ORG_ID = pl.INV_ORG_ID
LEFT JOIN POS_PRICE_LISTS pp ON pp.PRICE_LIST_ID = pl.PARENT_PRICE_LIST_ID
ORDER BY pl.PRIORITY, pl.PRICE_LIST_ID
```

- **Primary Key Column:** `PRICE_LIST_ID`

### 4-ج: ضبط الأعمدة:

| اسم العمود | Label | النوع | ملاحظات وإعدادات |
|---|---|---|---|
| `PRICE_LIST_ID` | - | `Hidden` | Primary Key ✅ |
| `PRICE_LIST_CODE` | **كود القائمة** | `Text Field` | Required |
| `PRICE_LIST_NAME` | **اسم القائمة** | `Text Field` | Required |
| `PRICE_LIST_TYPE` | **نوع القائمة** | `Select List` | Static Values: `قياسية;STANDARD`, `موسمية;SEASONAL`, `خاصة بالفرع;BRANCH_SPECIFIC`, `ترويجية;PROMOTIONAL`, `عملاء مميزون;CUSTOMER_TIER` |
| `CURRENCY_CODE` | **العملة** | `Text Field` | Required, Placeholder: `USD/SAR/EGP/AED` |
| `INV_ORG_ID` | **الفرع** | `Select List` | LOV: `SELECT INV_ORG_NAME D, INV_ORG_ID R FROM POS_INVENTORY_ORGS WHERE IS_ACTIVE='Y'` / Display Null: `✅ جميع الفروع` |
| `ORG_NAME` | - | `Hidden` | Read Only |
| `PARENT_PRICE_LIST_ID` | **ترث أسعارها من** | `Select List` | LOV: `SELECT PRICE_LIST_NAME D, PRICE_LIST_ID R FROM POS_PRICE_LISTS WHERE IS_ACTIVE='Y'` / Display Null: `لا يوجد قائمة أم` |
| `PARENT_LIST_NAME` | - | `Hidden` | Read Only |
| `PRIORITY` | **الأولوية** | `Number Field` | Default: `100` (رقم أصغر = أولوية أعلى) |
| `START_DATE` | **تاريخ البداية** | `Date Picker` | Format: `DD/MM/YYYY` |
| `END_DATE` | **تاريخ الانتهاء** | `Date Picker` | Format: `DD/MM/YYYY` |
| `IS_ACTIVE` | **نشط؟** | `Select List` | Static: `نشط;Y`, `متوقف;N` |
| `LINES_COUNT` | **عدد الأصناف المسعرة** | `Plain Text` | Read Only = Yes |

### 4-د: إعدادات Toolbar:

في **Attributes ➔ Toolbar**:
- **Edit Enabled:** `Yes` ✅
- **Add Row:** `Yes` ✅
- **Save:** `Yes` ✅
- **Delete Allowed:** `Yes` ✅

### 4-هـ: إضافة زر "عرض أسعار الأصناف" في عمود الإجراءات:

أضف عموداً جديداً:
- **Type:** `HTML Expression`
- **Label:** `إجراءات`
- **HTML Expression:**
```html
<button type="button"
        class="t-Button t-Button--small t-Button--primary"
        onclick="showPriceListLines(&PRICE_LIST_ID., '&PRICE_LIST_NAME.');"
        title="عرض وتعديل أسعار الأصناف">
  💲 أسعار الأصناف (&LINES_COUNT.)
</button>
```

---

## 🏗️ المرحلة 5: Section B - جريد أسعار الأصناف (Price List Lines)

### 5-أ: إنشاء المنطقة:
1. اضغط بزر الأيمن على **`Body`** ➔ **`Create Region`**:
   - **Title:** `💲 أسعار الأصناف في القائمة المحددة (Price List Lines)`
   - **Type:** `Interactive Grid`
   - **Static ID:** `price_lines_reg`

### 5-ب: الـ SQL Query:

```sql
SELECT
    l.PRICE_LINE_ID,
    l.PRICE_LIST_ID,
    l.ITEM_ID,
    i.ITEM_NAME_AR  AS ITEM_NAME,
    i.ITEM_CODE,
    l.VARIANT_ID,
    v.SKU_CODE      AS VARIANT_SKU,
    v.VARIANT_NAME_EN AS VARIANT_NAME,
    l.UOM_CODE,
    l.LIST_PRICE,
    l.MIN_PRICE,
    l.MAX_PRICE,
    i.COST_PRICE,
    -- هامش الربح (٪)
    CASE WHEN NVL(i.COST_PRICE, 0) = 0 THEN NULL
         ELSE ROUND((l.LIST_PRICE - i.COST_PRICE) / l.LIST_PRICE * 100, 1)
    END AS MARGIN_PCT,
    l.START_DATE,
    l.END_DATE,
    l.IS_ACTIVE
FROM POS_PRICE_LIST_LINES l
JOIN POS_ITEMS i ON i.ITEM_ID = l.ITEM_ID
LEFT JOIN POS_ITEM_VARIANTS v ON v.VARIANT_ID = l.VARIANT_ID
WHERE l.PRICE_LIST_ID = NVL(:P220_SELECTED_PRICE_LIST_ID, -1)
ORDER BY i.ITEM_ID, l.VARIANT_ID
```

- **Primary Key Column:** `PRICE_LINE_ID`
- **Page Items to Submit:** `P220_SELECTED_PRICE_LIST_ID`

### 5-ج: ضبط الأعمدة:

| اسم العمود | Label | النوع | ملاحظات |
|---|---|---|---|
| `PRICE_LINE_ID` | - | `Hidden` | Primary Key ✅ |
| `PRICE_LIST_ID` | - | `Hidden` | Default Type: `Item`, Default Item: `P220_SELECTED_PRICE_LIST_ID` |
| `ITEM_ID` | **الصنف** | `Select List` | LOV: `SELECT ITEM_NAME_AR \|\| ' - ' \|\| ITEM_CODE D, ITEM_ID R FROM POS_ITEMS WHERE IS_ACTIVE='Y' ORDER BY ITEM_NAME_AR` |
| `ITEM_NAME` | **اسم الصنف** | `Plain Text` | Read Only = Yes |
| `ITEM_CODE` | - | `Hidden` | Read Only |
| `VARIANT_ID` | **المتغير (المقاس/اللون)** | `Select List` | LOV: `SELECT SKU_CODE \|\| ' - ' \|\| VARIANT_NAME_EN D, VARIANT_ID R FROM POS_ITEM_VARIANTS WHERE ITEM_ID = :ITEM_ID ORDER BY SKU_CODE` / Display Null: `بدون متغير (الصنف كاملاً)` |
| `VARIANT_SKU` | **SKU المتغير** | `Plain Text` | Read Only = Yes |
| `VARIANT_NAME` | - | `Hidden` | Read Only |
| `UOM_CODE` | **الوحدة** | `Select List` | LOV: `SELECT UOM_NAME_EN D, UOM_CODE R FROM POS_UNITS_OF_MEASURE WHERE IS_ACTIVE='Y'` |
| `LIST_PRICE` | **💲 سعر البيع** | `Number Field` | Format: `999,990.00` / Required |
| `MIN_PRICE` | **السعر الأدنى المسموح** | `Number Field` | Format: `999,990.00` |
| `MAX_PRICE` | **السعر الأقصى** | `Number Field` | Format: `999,990.00` |
| `COST_PRICE` | **سعر التكلفة** | `Plain Text` | Read Only = Yes |
| `MARGIN_PCT` | **هامش الربح ٪** | `Plain Text` | Read Only = Yes |
| `START_DATE` | **صالح من** | `Date Picker` | |
| `END_DATE` | **صالح حتى** | `Date Picker` | |
| `IS_ACTIVE` | **نشط؟** | `Select List` | Static: `نشط;Y`, `متوقف;N` |

### 5-د: Toolbar لـ Section B:
- **Edit Enabled:** `Yes` ✅
- **Add Row:** `Yes` ✅
- **Save:** `Yes` ✅
- **Delete Allowed:** `Yes` ✅

---

## 🏗️ المرحلة 6: Section C - جريد العروض الترويجية (Promotions)

### 6-أ: إنشاء المنطقة:
1. اضغط بزر الأيمن على **`Body`** ➔ **`Create Region`**:
   - **Title:** `🎁 العروض والخصومات الترويجية (Promotions)`
   - **Type:** `Interactive Grid`
   - **Static ID:** `promotions_reg`

### 6-ب: الـ SQL Query:

```sql
SELECT
    p.PROMO_ID,
    p.PROMO_CODE,
    p.PROMO_NAME,
    p.PROMO_TYPE,
    p.START_DATE,
    p.END_DATE,
    p.MIN_ORDER_AMOUNT,
    p.DISCOUNT_PERCENT,
    p.DISCOUNT_AMOUNT,
    p.MAX_USES_TOTAL,
    p.CURRENT_USE_COUNT,
    p.IS_STACKABLE,
    p.IS_ACTIVE,
    -- حالة العرض: نشط/منتهي/مجدول
    CASE
        WHEN p.IS_ACTIVE = 'N' THEN 'متوقف'
        WHEN p.END_DATE < SYSDATE THEN 'منتهي الصلاحية'
        WHEN p.START_DATE > SYSDATE THEN 'مجدول مستقبلاً'
        ELSE 'نشط الآن'
    END AS PROMO_STATUS,
    -- نسبة الاستخدام
    CASE WHEN NVL(p.MAX_USES_TOTAL,0) = 0 THEN NULL
         ELSE ROUND(p.CURRENT_USE_COUNT / p.MAX_USES_TOTAL * 100, 1)
    END AS USAGE_PCT
FROM POS_PROMOTIONS p
ORDER BY p.START_DATE DESC, p.PROMO_ID DESC
```

- **Primary Key Column:** `PROMO_ID`

### 6-ج: ضبط الأعمدة:

| اسم العمود | Label | النوع | ملاحظات |
|---|---|---|---|
| `PROMO_ID` | - | `Hidden` | Primary Key ✅ |
| `PROMO_CODE` | **كود العرض** | `Text Field` | Unique, Required |
| `PROMO_NAME` | **اسم العرض** | `Text Field` | Required |
| `PROMO_TYPE` | **نوع العرض** | `Select List` | Static: `خصم ٪;PERCENT_DISCOUNT`, `خصم ثابت;FIXED_DISCOUNT`, `اشترِ X واحصل على Y;BXGY`, `باقة;BUNDLE`, `حسب الحد الأدنى;THRESHOLD`, `صنف مجاني;FREE_ITEM` |
| `START_DATE` | **تاريخ البداية** | `Date Picker` | Required |
| `END_DATE` | **تاريخ الانتهاء** | `Date Picker` | Required |
| `MIN_ORDER_AMOUNT` | **حد أدنى للفاتورة** | `Number Field` | يعني العرض لا يُطبَّق إلا إذا تجاوزت الفاتورة هذا المبلغ |
| `DISCOUNT_PERCENT` | **نسبة الخصم ٪** | `Number Field` | Format: `990.00` |
| `DISCOUNT_AMOUNT` | **مبلغ الخصم الثابت** | `Number Field` | Format: `999,990.00` |
| `MAX_USES_TOTAL` | **أقصى عدد استخدام** | `Number Field` | فارغ = غير محدود |
| `CURRENT_USE_COUNT` | **استُخدم** | `Plain Text` | Read Only = Yes |
| `USAGE_PCT` | **٪ الاستخدام** | `Plain Text` | Read Only = Yes |
| `IS_STACKABLE` | **يتكدس مع عروض أخرى؟** | `Select List` | Static: `نعم;Y`, `لا;N` |
| `IS_ACTIVE` | **نشط؟** | `Select List` | Static: `نشط;Y`, `متوقف;N` |
| `PROMO_STATUS` | **الحالة الحالية** | `Plain Text` | Read Only = Yes |

---

## 🏗️ المرحلة 7: Dynamic Action لعرض أسعار القائمة المحددة

### 7-أ: إنشاء الـ Dynamic Action:
1. في شجرة اليسار، اضغط على تبويب **`Dynamic Actions`** (أيقونة الصاعقة ⚡).
2. اضغط بزر الأيمن على **`Events`** ➔ **`Create Dynamic Action`**:
   - **Name:** `DA_SHOW_PRICE_LIST_LINES`
   - **When ➔ Event:** `Custom`
   - **When ➔ Custom Event:** `pos-show-price-lines`
   - **When ➔ Selection Type:** `JavaScript Expression`
   - **When ➔ JavaScript Expression:** `document`

### 7-ب: إجراء True:
- **Action:** `Execute Server-side Code (PL/SQL)`
- **PL/SQL Code:**
```sql
BEGIN
    :P220_SELECTED_PRICE_LIST_ID := apex_application.g_x01;
END;
```
- **Items to Submit:** *(فارغ)*
- **Items to Return:** `P220_SELECTED_PRICE_LIST_ID`

### 7-ج: إجراء True ثانٍ (Refresh):
- **Action:** `Refresh`
- **Selection Type:** `Region`
- **Region:** `price_lines_reg`

---

## 🏗️ المرحلة 8: JavaScript لربط الزر بالـ Dynamic Action

1. في شجرة اليسار، اضغط على **`Page 220`** (أعلى الشجرة).
2. في لوحة الخصائص ➔ **`JavaScript ➔ Execute when Page Loads`**:

```javascript
// ==========================================================
// PAGE 220 - PRICING CONTROLLER
// ==========================================================

// دالة عرض أسعار الأصناف لقائمة أسعار محددة
window.showPriceListLines = function(priceListId, priceListName) {
    // تحديث الـ Item الخفي
    apex.item('P220_SELECTED_PRICE_LIST_ID').setValue(priceListId);
    
    // تحديث عنوان Section B ليُظهر اسم القائمة المحددة
    var titleEl = document.querySelector('#price_lines_reg .t-IRR-title, #price_lines_reg h2');
    if (titleEl) {
        titleEl.textContent = '💲 أسعار الأصناف في: ' + priceListName;
    }
    
    // تشغيل الـ Dynamic Action لتحديث الجريد
    apex.event.trigger(document, 'pos-show-price-lines', {
        priceListId: priceListId,
        priceListName: priceListName
    });
    
    // Call Server directly via apex.server.process
    apex.server.process('SET_PRICE_LIST_SESSION', {
        x01: priceListId
    }, {
        success: function() {
            // تحديث جريد الأسعار
            var linesRegion = document.getElementById('price_lines_reg');
            if (linesRegion) {
                $(linesRegion).trigger('apexrefresh');
            }
            // النزول لقسم الأسعار
            if (linesRegion) {
                linesRegion.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }
    });
};
```

---

## 🏗️ المرحلة 9: Ajax Callback لحفظ الـ Session State

1. في شجرة اليسار، اضغط على تبويب **`Processing`** (أيقونة الترس ⚙️).
2. اضغط بزر الأيمن على **`Ajax Callback`** ➔ **`Create Process`**:
   - **Name:** `SET_PRICE_LIST_SESSION`
   - **Type:** `Execute Code`
   - **Source ➔ PL/SQL Code:**
```sql
BEGIN
    :P220_SELECTED_PRICE_LIST_ID := apex_application.g_x01;
END;
```
   - **Items to Return:** `P220_SELECTED_PRICE_LIST_ID`

---

## 🧪 دليل الاختبار الكامل (Test Plan)

---

### ✅ اختبار 1: التحقق من عرض قوائم الأسعار

**الهدف:** التأكد من ظهور قائمة الأسعار الموجودة.

**الخطوات:**
1. افتح **Page 220**.
2. تحقق من ظهور قائمة `Standard Retail Price List SAR` في Section A.
3. اضغط على زر **`💲 أسعار الأصناف (5)`**.

**النتيجة المتوقعة:**
- ✔️ تنزل الصفحة لـ Section B وتُظهر الأصناف الخمسة المسعرة.
- ✔️ يظهر سعر القهوة `16.00` والقميص `89.00` والسماعات `299.00`.

---

### ✅ اختبار 2: إضافة قائمة أسعار موسمية جديدة

**الهدف:** إنشاء قائمة أسعار موسمية للصيف.

**الخطوات:**
1. في Section A، اضغط **`✚ Add Row`**.
2. أدخل البيانات:
   - **كود القائمة:** `SUMMER_SALE_2025`
   - **اسم القائمة:** `تخفيضات الصيف 2025`
   - **نوع القائمة:** `موسمية (SEASONAL)`
   - **العملة:** `SAR` (أو العملة التي تعمل بها)
   - **الأولوية:** `50` *(أعلى أولوية من الـ Standard)*
   - **تاريخ البداية:** `01/06/2025`
   - **تاريخ الانتهاء:** `31/08/2025`
   - **نشط؟:** `Y`
3. اضغط **`💾 Save`**.

**النتيجة المتوقعة:**
- ✔️ تُحفظ القائمة الجديدة وتظهر في الجريد.

---

### ✅ اختبار 3: إضافة سعر مخفّض لصنف في القائمة الموسمية

**الهدف:** إضافة سعر تخفيض 20% على القميص في قائمة الصيف.

**الخطوات:**
1. اضغط على **`💲 أسعار الأصناف`** لقائمة `SUMMER_SALE_2025`.
2. في Section B، اضغط **`✚ Add Row`**.
3. أدخل البيانات:
   - **الصنف:** `قميص بولو قطني كلاسيك`
   - **المتغير:** `بدون متغير (الصنف كاملاً)`
   - **الوحدة:** `EA`
   - **💲 سعر البيع:** `71.20` *(89 × 0.80 = تخفيض 20%)*
   - **السعر الأدنى:** `70.00`
   - **نشط؟:** `Y`
4. اضغط **`💾 Save`**.

**النتيجة المتوقعة:**
- ✔️ يُحفظ السعر الجديد في قائمة الصيف.
- ✔️ **ملاحظة:** هذا السعر لن يُفعَّل في الكاشير تلقائياً إلا عند ربط هذه القائمة بالفاتورة!

---

### ✅ اختبار 4: تعديل سعر صنف في القائمة الرئيسية وأثره الفوري على الكاشير

**الهدف:** تغيير سعر القهوة من 16 ريال إلى 18 ريال.

**الخطوات:**
1. في Section A، اضغط على **`💲 أسعار الأصناف (5)`** لقائمة `STANDARD_RETAIL_SAR`.
2. في Section B، اضغط مرتين على سطر `كافيه لاتيه كلاسيك`.
3. غيّر **`💲 سعر البيع`** من `16.00` إلى `18.00`.
4. اضغط **`💾 Save`**.
5. افتح **Page 100 (الكاشير)**.

**النتيجة المتوقعة:**
- ✔️ يظهر في كارت القهوة السعر الجديد `18.00 SAR`.
- ✔️ عند إضافة القهوة للسلة، يُحسب السعر بـ 18 ريال.

---

### ✅ اختبار 5: إنشاء عرض ترويجي (خصم 10% على الفواتير فوق 200 ريال)

**الهدف:** إنشاء عرض ترويجي "اشترِ بـ 200 ريال أو أكثر واحصل على خصم 10%".

**الخطوات:**
1. في Section C، اضغط **`✚ Add Row`**.
2. أدخل البيانات:
   - **كود العرض:** `ORDER200_10PCT`
   - **اسم العرض:** `خصم 10% على الفواتير فوق 200 ريال`
   - **نوع العرض:** `حسب الحد الأدنى (THRESHOLD)`
   - **تاريخ البداية:** اليوم
   - **تاريخ الانتهاء:** `31/12/2025`
   - **حد أدنى للفاتورة:** `200`
   - **نسبة الخصم ٪:** `10`
   - **يتكدس مع عروض أخرى؟:** `N`
   - **نشط؟:** `Y`
3. اضغط **`💾 Save`**.

**النتيجة المتوقعة:**
- ✔️ يُحفظ العرض ويظهر في الجريد بالحالة `نشط الآن`.

---

## ⚠️ مفاهيم مهمة يجب فهمها

> [!IMPORTANT]
> **أولوية قوائم الأسعار (Priority):** الأرقام الصغيرة = أولوية أعلى. القائمة الموسمية (أولوية 50) تسبق القائمة القياسية (أولوية 100). الكاشير سيتحقق من القائمة الأعلى أولوية أولاً.

> [!NOTE]
> **وراثة الأسعار (Price Inheritance):** إذا لم يجد الكاشير سعراً للصنف في القائمة الحالية، ينتقل تلقائياً لـ `PARENT_PRICE_LIST_ID` وهكذا حتى يجد سعراً. هذا هو مبدأ **الـ Cascading Price Lookup** في النظام.

> [!WARNING]
> **العروض الترويجية لا تُطبَّق تلقائياً في الكاشير بعد.** سنبرمج محرك تطبيق العروض في مرحلة لاحقة عند بناء **Page 101 (Split Tender)** وإضافة زر "تطبيق كوبون/عرض".
