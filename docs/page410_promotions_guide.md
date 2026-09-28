# دليل تنفيذ صفحة 410: العروض الترويجية والكوبونات

## 1. إعدادات الصفحة
- **رقم الصفحة:** 410
- **اسم الصفحة:** العروض الترويجية والكوبونات
- **نظام الصلاحيات:** `AUTH_NOT_CASHIER`

## 2. بنية الصفحة
3 علامات تبويب.

---

## 3. التبويب 1: العروض الترويجية (IG)
- **الاستعلام (SQL Query):**
```sql
SELECT 
    PROMO_ID, PROMO_CODE, PROMO_NAME, PROMO_TYPE, INV_ORG_ID, START_DATE, END_DATE, MIN_ORDER_AMOUNT, MAX_USES_TOTAL, MAX_USES_PER_CUSTOMER, CURRENT_USE_COUNT, DISCOUNT_PERCENT, DISCOUNT_AMOUNT, BUY_ITEM_ID, BUY_QTY, GET_ITEM_ID, GET_QTY, GET_DISCOUNT_PERCENT, THRESHOLD_AMOUNT, LOYALTY_POINTS_EARNED, IS_STACKABLE, IS_ACTIVE,
    CREATED_BY, CREATION_DATE
FROM POS_PROMOTIONS
WHERE INV_ORG_ID = NVL(:AI_ORG_LIST, INV_ORG_ID)
```
- **الإجراءات الديناميكية (Dynamic Actions):** إظهار/إخفاء الحقول (BUY_ITEM_ID, BUY_QTY, GET_ITEM_ID...) بناءً على اختيار نوع العرض (PROMO_TYPE).

---

## 4. التبويب 2: أصناف العروض (IG Detail)
- يعتمد على تحديد صف في التبويب 1 (Master-Detail).
- **الاستعلام (SQL Query):**
```sql
SELECT 
    PROMO_ITEM_ID, PROMO_ID, ITEM_ID, CATEGORY_ID, ITEM_ROLE
FROM POS_PROMO_ITEMS
WHERE PROMO_ID = :P410_SELECTED_PROMO_ID
```

---

## 5. التبويب 3: الكوبونات (IG)
- **الاستعلام (SQL Query):**
```sql
SELECT 
    COUPON_ID, COUPON_CODE, PROMO_ID, CUSTOMER_ID, MAX_USES, CURRENT_USES, EXPIRY_DATE, IS_ACTIVE
FROM POS_COUPONS
```
