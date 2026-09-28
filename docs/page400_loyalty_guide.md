# دليل تنفيذ صفحة 400: برامج الولاء (Loyalty Programs)

## 1. إعدادات الصفحة
- **رقم الصفحة:** 400
- **اسم الصفحة:** برامج الولاء
- **نظام الصلاحيات:** `AUTH_NOT_CASHIER`

## 2. بنية الصفحة
تحتوي الصفحة على 3 علامات تبويب.

---

## 3. التبويب 1: برامج الولاء (IG)
- **الاستعلام (SQL Query):**
```sql
SELECT 
    PROGRAM_ID, PROGRAM_CODE, PROGRAM_NAME, POINTS_PER_CURRENCY_UNIT, CURRENCY_PER_POINT, MIN_REDEEM_POINTS, MAX_REDEEM_PERCENT, EXPIRY_MONTHS, IS_ACTIVE,
    CREATED_BY, CREATION_DATE, UPDATED_BY, UPDATE_DATE
FROM POS_LOYALTY_PROGRAMS
```

---

## 4. التبويب 2: حسابات الولاء (IG)
- **الاستعلام (SQL Query):**
```sql
SELECT 
    LOYALTY_ACCOUNT_ID, CUSTOMER_ID, PROGRAM_ID, POINTS_BALANCE, LIFETIME_POINTS_EARNED, LIFETIME_POINTS_REDEEMED, TIER_CODE, TIER_VALID_UNTIL,
    CREATED_BY, CREATION_DATE, UPDATED_BY, UPDATE_DATE
FROM POS_LOYALTY_ACCOUNTS
```
- **CUSTOMER_ID:** Popup LOV لإظهار اسم العميل.
- الأعمدة `POINTS_BALANCE` وما يليه للقراءة فقط (Read Only).

---

## 5. التبويب 3: حركات الولاء (IR - Read Only)
- **الاستعلام (SQL Query):**
```sql
SELECT 
    LOYALTY_TXN_ID, LOYALTY_ACCOUNT_ID, ORDER_ID, TXN_TYPE, POINTS, POINTS_BEFORE, POINTS_AFTER, NOTES, TXN_DATE
FROM POS_LOYALTY_TRANSACTIONS
ORDER BY TXN_DATE DESC
```
