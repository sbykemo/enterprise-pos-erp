# 🔐 منظومة الصلاحيات وعزل البيانات — Enterprise Security Architecture
## Oracle VPD + Application Context — مطبقة على كامل النظام

---

## 🏛️ المعمارية الكاملة

```
                         ┌─────────────────────────────────┐
                         │           APP_USER LOGIN        │
                         │   (APEX Authentication Event)   │
                         └────────────────┬────────────────┘
                                          │
                                          ▼
                         ┌─────────────────────────────────┐
                         │    POST-AUTH: POS_SEC_PKG       │
                         │  .SET_USER_CONTEXT(username)    │
                         │  يقرأ صلاحيات المستخدم من DB   │
                         │  ويضعها في APPLICATION CONTEXT  │
                         └────────────────┬────────────────┘
                                          │
              ┌───────────────────────────┴───────────────────────────┐
              ▼                                                       ▼
   ┌─────────────────────┐                               ┌─────────────────────┐
   │      SYSADMIN       │                               │    OPERATIONAL      │
   │    GENERAL_AUDITOR  │                               │    LE_MANAGER       │
   │    (Full Access)    │                               │    BRANCH_MANAGER   │
   │                     │                               │    CASHIER          │
   │  CTX: IS_ADMIN=Y    │                               │  CTX: IS_ADMIN=N    │
   │  CTX: LE_LIST=ALL   │                               │  CTX: LE_LIST=1,3   │
   │  CTX: ORG_LIST=ALL  │                               │  CTX: ORG_LIST=5    │
   └──────────┬──────────┘                               └──────────┬──────────┘
              │                                                     │
              └─────────────────────────┬───────────────────────────┘
                                        │
                                        ▼
                         ┌─────────────────────────────────┐
                         │      SECURITY ENGINE LAYER      │
                         │  ┌─────────────────────────┐   │
                         │  │ APPLICATION CONTEXT     │   │
                         │  │  POS_SEC_CTX            │   │
                         │  │  IS_ADMIN, LE_LIST,     │   │
                         │  │  ORG_LIST, USER_ROLE    │   │
                         │  └─────────────────────────┘   │
                         └────────────────┬────────────────┘
                                          │
                 ┌────────────────────────┴────────────────────────┐
                 ▼                                                 ▼
  ┌──────────────────────────┐                     ┌──────────────────────────┐
  │  LEVEL 1: LEGAL ENTITY   │                     │  LEVEL 2: INV ORG/BRANCH │
  │ POS_USER_PERMITTED_LE_V  │                     │ POS_USER_PERMITTED_ORG_V │
  └─────────────┬────────────┘                     └─────────────┬────────────┘
                │                                               │
                ▼                                               ▼
   ┌────────────────────────┐                    ┌─────────────────────────────┐
   │ شاشات المحاسبة والمالية│                    │  شاشات المخزون والتشغيل    │
   │ • دليل الحسابات        │                    │  • أرصدة المخزون واستلامها  │
   │ • قيود اليومية         │                    │  • تحويلات البضاعة          │
   │ • الفترات المحاسبية    │                    │  • نقطة البيع (الكاشير)     │
   │ • القوائم المالية       │                    │  • إغلاق الوردية Z-Report   │
   │ • الضرائب وإقرارات VAT │                    │  • الموردون والمشتريات      │
   └────────────────────────┘                    └─────────────────────────────┘
```

---

## ⚙️ المرحلة 0: جدول مصفوفة الصلاحيات المحدَّث

### 0-أ: مراجعة أدوار المستخدمين المعتمدة في النظام

| الدور (USER_ROLE) | الوصف | مستوى الوصول |
|---|---|---|
| `SYSADMIN` | مدير النظام العام | كل الشركات + كل الفروع + كل الشاشات |
| `GENERAL_AUDITOR` | مراجع عام | يقرأ كل شيء بدون تعديل (Read-Only Global) |
| `LE_MANAGER` | مدير كيان قانوني (شركة) | كل فروع شركته فقط |
| `BRANCH_MANAGER` | مدير فرع | فرعه المحدد فقط |
| `CASHIER` | كاشير | فرعه وجهاز الكاشير المحدد له فقط |

---

### 0-ب: جدول الصلاحيات (`POS_USER_ORG_ACCESS`)

```sql
-- التأكد من هيكل جدول الصلاحيات
-- يجب أن يحتوي على هذه الأعمدة كحد أدنى:
-- ACCESS_ID, APP_USER_ID, LEGAL_ENTITY_ID (NULL = كل الشركات)
-- INV_ORG_ID (NULL = كل فروع الشركة), TERMINAL_ID (NULL = كل الأجهزة)
-- IS_READ_ONLY (Y/N), IS_ACTIVE (Y/N)

ALTER TABLE POS_USER_ORG_ACCESS ADD (
    LEGAL_ENTITY_ID NUMBER,
    IS_READ_ONLY    CHAR(1) DEFAULT 'N',
    TERMINAL_ID     NUMBER
);

-- تسجيل بيانات اختبارية لاختبار العزل لاحقاً
-- مثال: مستخدم مخصص لشركة 1000001 فقط بجميع فروعها
INSERT INTO POS_USER_ORG_ACCESS 
    (ACCESS_ID, APP_USER_ID, LEGAL_ENTITY_ID, INV_ORG_ID, IS_READ_ONLY, IS_ACTIVE)
VALUES (
    NVL((SELECT MAX(ACCESS_ID) FROM POS_USER_ORG_ACCESS), 0) + 1,
    /* APP_USER_ID للمستخدم المحدود */(SELECT APP_USER_ID FROM POS_APP_USERS WHERE APEX_USERNAME = 'YOUR_TEST_USER'),
    1000001,
    NULL,   -- NULL = كل فروع الشركة
    'N',
    'Y'
);
COMMIT;
```

---

## ⚙️ المرحلة 1: Oracle Application Context

### 1-أ: إنشاء الـ Context

```sql
-- Application Context: يُخزَّن في ذاكرة الـ Session لكل مستخدم
CREATE OR REPLACE CONTEXT POS_SEC_CTX
    USING POS_SEC_PKG
    ACCESSED GLOBALLY;
```

---

### 1-ب: Package المسؤول عن ضبط الصلاحيات

```sql
CREATE OR REPLACE PACKAGE POS_SEC_PKG AS
    -- يُستدعى من APEX Post-Authentication
    PROCEDURE SET_USER_CONTEXT(p_apex_username VARCHAR2);
    -- للتحقق السريع هل المستخدم admin
    FUNCTION  IS_ADMIN RETURN VARCHAR2;
    -- قائمة الـ Legal Entities المسموحة (مفصولة بفاصلة)
    FUNCTION  GET_PERMITTED_LE_LIST RETURN VARCHAR2;
    -- قائمة الـ Inventory Orgs المسموحة
    FUNCTION  GET_PERMITTED_ORG_LIST RETURN VARCHAR2;
END POS_SEC_PKG;
/

CREATE OR REPLACE PACKAGE BODY POS_SEC_PKG AS

    -- ================================================================
    -- الإجراء الرئيسي: يُشغَّل فور تسجيل دخول المستخدم
    -- ================================================================
    PROCEDURE SET_USER_CONTEXT(p_apex_username VARCHAR2) IS
        v_user_id    NUMBER;
        v_role       VARCHAR2(30);
        v_le_list    VARCHAR2(4000) := '';
        v_org_list   VARCHAR2(4000) := '';
        v_is_admin   VARCHAR2(1)   := 'N';
    BEGIN
        -- جلب بيانات المستخدم
        BEGIN
            SELECT APP_USER_ID, USER_ROLE
              INTO v_user_id, v_role
              FROM POS_APP_USERS
             WHERE UPPER(APEX_USERNAME) = UPPER(p_apex_username)
               AND IS_ACTIVE = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- إذا لم يوجد في الجدول، افترض أنه مطور (Admin)
                DBMS_SESSION.SET_CONTEXT('POS_SEC_CTX', 'IS_ADMIN',   'Y');
                DBMS_SESSION.SET_CONTEXT('POS_SEC_CTX', 'USER_ROLE',  'SYSADMIN');
                DBMS_SESSION.SET_CONTEXT('POS_SEC_CTX', 'LE_LIST',    'ALL');
                DBMS_SESSION.SET_CONTEXT('POS_SEC_CTX', 'ORG_LIST',   'ALL');
                RETURN;
        END;

        -- تحديد نوع المستخدم
        IF v_role IN ('SYSADMIN', 'GENERAL_AUDITOR') THEN
            v_is_admin := 'Y';
        END IF;

        -- بناء قائمة الـ Legal Entities المسموحة
        IF v_is_admin = 'Y' THEN
            v_le_list  := 'ALL';
            v_org_list := 'ALL';
        ELSE
            -- الحالة 1: له صلاحية شركة بالكامل (INV_ORG_ID IS NULL)
            FOR r IN (
                SELECT DISTINCT TO_CHAR(LEGAL_ENTITY_ID) AS LE_ID
                  FROM POS_USER_ORG_ACCESS
                 WHERE APP_USER_ID = v_user_id
                   AND IS_ACTIVE   = 'Y'
                   AND LEGAL_ENTITY_ID IS NOT NULL
            ) LOOP
                v_le_list := v_le_list || r.LE_ID || ',';
            END LOOP;

            -- الحالة 2: بناء قائمة الـ INV_ORGs المسموح بها
            FOR r IN (
                SELECT DISTINCT
                       NVL(TO_CHAR(uoa.INV_ORG_ID), 'LE_' || uoa.LEGAL_ENTITY_ID) AS ORG_REF,
                       io.INV_ORG_ID,
                       io.ORG_UNIT_ID
                  FROM POS_USER_ORG_ACCESS uoa
                  JOIN POS_INVENTORY_ORGS  io
                    ON (uoa.INV_ORG_ID = io.INV_ORG_ID
                     OR (uoa.INV_ORG_ID IS NULL
                         AND io.ORG_UNIT_ID IN (
                             SELECT ou.ORG_UNIT_ID FROM POS_OPERATING_UNITS ou
                              WHERE ou.LEGAL_ENTITY_ID = uoa.LEGAL_ENTITY_ID)))
                 WHERE uoa.APP_USER_ID = v_user_id
                   AND uoa.IS_ACTIVE   = 'Y'
                   AND io.IS_ACTIVE    = 'Y'
            ) LOOP
                v_org_list := v_org_list || TO_CHAR(r.INV_ORG_ID) || ',';
            END LOOP;

            -- إزالة الفاصلة الأخيرة
            IF LENGTH(v_le_list)  > 0 THEN v_le_list  := RTRIM(v_le_list,  ','); END IF;
            IF LENGTH(v_org_list) > 0 THEN v_org_list := RTRIM(v_org_list, ','); END IF;
        END IF;

        -- وضع القيم في الـ Context
        DBMS_SESSION.SET_CONTEXT('POS_SEC_CTX', 'USER_ID',   TO_CHAR(v_user_id));
        DBMS_SESSION.SET_CONTEXT('POS_SEC_CTX', 'USER_ROLE', v_role);
        DBMS_SESSION.SET_CONTEXT('POS_SEC_CTX', 'IS_ADMIN',  v_is_admin);
        DBMS_SESSION.SET_CONTEXT('POS_SEC_CTX', 'LE_LIST',   v_le_list);
        DBMS_SESSION.SET_CONTEXT('POS_SEC_CTX', 'ORG_LIST',  v_org_list);

    EXCEPTION
        WHEN OTHERS THEN
            -- في أي حالة خطأ: لا تكسر الدخول، اعطِ صلاحية صفرية للأمان
            DBMS_SESSION.SET_CONTEXT('POS_SEC_CTX', 'IS_ADMIN',  'N');
            DBMS_SESSION.SET_CONTEXT('POS_SEC_CTX', 'LE_LIST',   '');
            DBMS_SESSION.SET_CONTEXT('POS_SEC_CTX', 'ORG_LIST',  '');
    END SET_USER_CONTEXT;

    -- ================================================================
    FUNCTION IS_ADMIN RETURN VARCHAR2 IS
    BEGIN
        RETURN NVL(SYS_CONTEXT('POS_SEC_CTX', 'IS_ADMIN'), 'N');
    END;

    FUNCTION GET_PERMITTED_LE_LIST RETURN VARCHAR2 IS
    BEGIN
        RETURN NVL(SYS_CONTEXT('POS_SEC_CTX', 'LE_LIST'), '');
    END;

    FUNCTION GET_PERMITTED_ORG_LIST RETURN VARCHAR2 IS
    BEGIN
        RETURN NVL(SYS_CONTEXT('POS_SEC_CTX', 'ORG_LIST'), '');
    END;

END POS_SEC_PKG;
/
```

---

## ⚙️ المرحلة 2: الـ Security Views (قلب النظام)

### 2-أ: View الشركات المسموحة

```sql
CREATE OR REPLACE VIEW POS_USER_PERMITTED_LE_V AS
SELECT le.*
  FROM POS_LEGAL_ENTITIES le
 WHERE le.IS_ACTIVE = 'Y'
   AND (
       -- Admin يرى الكل
       SYS_CONTEXT('POS_SEC_CTX', 'IS_ADMIN') = 'Y'
       OR
       -- مستخدم عادي: تحقق من قائمة الشركات
       INSTR(
           ',' || SYS_CONTEXT('POS_SEC_CTX', 'LE_LIST') || ',',
           ',' || TO_CHAR(le.LEGAL_ENTITY_ID) || ','
       ) > 0
   );
```

---

### 2-ب: View الفروع والمخازن المسموحة

```sql
CREATE OR REPLACE VIEW POS_USER_PERMITTED_ORG_V AS
SELECT io.*
  FROM POS_INVENTORY_ORGS io
 WHERE io.IS_ACTIVE = 'Y'
   AND (
       SYS_CONTEXT('POS_SEC_CTX', 'IS_ADMIN') = 'Y'
       OR
       -- مسموح بالفرع مباشرة
       INSTR(
           ',' || SYS_CONTEXT('POS_SEC_CTX', 'ORG_LIST') || ',',
           ',' || TO_CHAR(io.INV_ORG_ID) || ','
       ) > 0
   );
```

---

## ⚙️ المرحلة 3: ربط الـ Context بـ APEX (الخطوة المحورية)

### في APEX App Builder ➔ App 102 ➔ Security ➔ Authentication Scheme:

1. افتح **Application 102**.
2. اضغط على **`Shared Components`** (المكونات المشتركة).
3. اختر **`Authentication Schemes`**.
4. افتح الـ Authentication Scheme الحالي.
5. ابحث عن حقل **`Post-Authentication Procedure Name`**.
6. اكتب فيه بالضبط:
```
POS_SEC_PKG.SET_USER_CONTEXT
```
7. اضغط **`Apply Changes`**.

> [!IMPORTANT]
> **هذا هو المفتاح الرئيسي للنظام بالكامل!**
> بمجرد تسجيل أي مستخدم دخوله في التطبيق، يقوم أيبكس تلقائياً باستدعاء `POS_SEC_PKG.SET_USER_CONTEXT` وتمرير اسم المستخدم إليه، فيقوم البروسيجر بملء الـ Context بصلاحياته وقائمة شركاته وفروعه — مرة واحدة عند الدخول وتستمر طوال جلسة العمل.

---

## ⚙️ المرحلة 4: تطبيق العزل على كل شاشات التطبيق

### القاعدة الذهبية التي تُطبَّق على كل استعلام في النظام:

#### لشاشات المحاسبة (ترتبط بالشركة):
```sql
-- أضف هذا الشرط في WHERE لكل استعلام يحتوي على LEGAL_ENTITY_ID
AND LEGAL_ENTITY_ID IN (SELECT LEGAL_ENTITY_ID FROM POS_USER_PERMITTED_LE_V)
```

#### لشاشات المخزون والتشغيل (ترتبط بالفرع):
```sql
-- أضف هذا الشرط في WHERE لكل استعلام يحتوي على INV_ORG_ID
AND INV_ORG_ID IN (SELECT INV_ORG_ID FROM POS_USER_PERMITTED_ORG_V)
```

---

### تطبيق فوري على الشاشات الحالية:

#### Page 240 — دليل الحسابات (`coa_reg`):
```sql
WHERE a.IS_ACTIVE = 'Y'
  AND a.LEGAL_ENTITY_ID = NVL(:P240_LE_FILTER, a.LEGAL_ENTITY_ID)
  AND a.LEGAL_ENTITY_ID IN (SELECT LEGAL_ENTITY_ID FROM POS_USER_PERMITTED_LE_V)
```

#### Page 240 — LOV لحقل `P240_LE_FILTER`:
```sql
SELECT LEGAL_ENTITY_NAME D, LEGAL_ENTITY_ID R
  FROM POS_USER_PERMITTED_LE_V
 ORDER BY LEGAL_ENTITY_NAME
```

#### Page 240 — Default Value لحقل `P240_LE_FILTER`:
```sql
-- يختار تلقائياً الشركة الوحيدة للمستخدم أو NULL للـ Admin
SELECT CASE WHEN COUNT(*) = 1 THEN MIN(LEGAL_ENTITY_ID) ELSE NULL END
  FROM POS_USER_PERMITTED_LE_V
```

#### Page 230 — أرصدة المخزون (`stock_balances_reg`):
```sql
AND b.INV_ORG_ID IN (SELECT INV_ORG_ID FROM POS_USER_PERMITTED_ORG_V)
```

#### Page 230 — التحويلات (`transfers_reg`):
```sql
AND (t.FROM_INV_ORG_ID IN (SELECT INV_ORG_ID FROM POS_USER_PERMITTED_ORG_V)
  OR t.TO_INV_ORG_ID   IN (SELECT INV_ORG_ID FROM POS_USER_PERMITTED_ORG_V))
```

#### كل LOV للفروع في النظام:
```sql
-- استبدل: FROM POS_INVENTORY_ORGS
-- بـ:     FROM POS_USER_PERMITTED_ORG_V
SELECT INV_ORG_NAME D, INV_ORG_ID R
  FROM POS_USER_PERMITTED_ORG_V
 ORDER BY INV_ORG_NAME
```

---

## ⚙️ المرحلة 5: شاشة إدارة الصلاحيات (للـ SYSADMIN)

### منطقة إضافية في أي شاشة Admin:

تُعرض وتُعدَّل فيها مصفوفة الصلاحيات بصرياً:

```sql
SELECT
    u.APEX_USERNAME AS "المستخدم",
    u.USER_ROLE     AS "الدور",
    le.LEGAL_ENTITY_NAME AS "الشركة",
    io.INV_ORG_NAME AS "الفرع",
    uoa.IS_READ_ONLY AS "قراءة فقط؟",
    uoa.IS_ACTIVE AS "نشط؟"
FROM POS_USER_ORG_ACCESS uoa
JOIN POS_APP_USERS        u  ON u.APP_USER_ID  = uoa.APP_USER_ID
LEFT JOIN POS_LEGAL_ENTITIES le ON le.LEGAL_ENTITY_ID = uoa.LEGAL_ENTITY_ID
LEFT JOIN POS_INVENTORY_ORGS io ON io.INV_ORG_ID      = uoa.INV_ORG_ID
ORDER BY u.APEX_USERNAME, le.LEGAL_ENTITY_NAME, io.INV_ORG_NAME
```

---

## 🧪 دليل الاختبار الكامل للصلاحيات

### الاختبار 1: Admin يرى كل الشركات:
```sql
-- شغّل في SQL Commands لاختبار الـ Context يدوياً:
EXEC POS_SEC_PKG.SET_USER_CONTEXT('ADMIN_USER');
SELECT SYS_CONTEXT('POS_SEC_CTX','IS_ADMIN') FROM DUAL;   -- النتيجة: Y
SELECT SYS_CONTEXT('POS_SEC_CTX','LE_LIST') FROM DUAL;    -- النتيجة: ALL
SELECT COUNT(*) FROM POS_USER_PERMITTED_LE_V;             -- النتيجة: 2 (كل الشركات)
```

### الاختبار 2: مستخدم عادي يرى شركة واحدة فقط:
```sql
EXEC POS_SEC_PKG.SET_USER_CONTEXT('TEST_USER');
SELECT SYS_CONTEXT('POS_SEC_CTX','IS_ADMIN') FROM DUAL;   -- النتيجة: N
SELECT SYS_CONTEXT('POS_SEC_CTX','LE_LIST') FROM DUAL;    -- النتيجة: 1000001
SELECT COUNT(*) FROM POS_USER_PERMITTED_LE_V;             -- النتيجة: 1 (شركته فقط!)
SELECT COUNT(*) FROM POS_COA_ACCOUNTS
 WHERE LEGAL_ENTITY_ID IN (SELECT LEGAL_ENTITY_ID FROM POS_USER_PERMITTED_LE_V);
-- النتيجة: فقط حسابات شركته!
```

---

## 📋 جدول تطبيق التحديث على كل شاشات النظام

| الشاشة | اسم المنطقة | الشرط المضاف |
|---|---|---|
| **Page 230** — أرصدة المخزون | `stock_balances_reg` | `INV_ORG_ID IN (SELECT INV_ORG_ID FROM POS_USER_PERMITTED_ORG_V)` |
| **Page 230** — استلام بضاعة | `stock_receipt_reg` | `INV_ORG_ID IN (SELECT INV_ORG_ID FROM POS_USER_PERMITTED_ORG_V)` |
| **Page 230** — تحويلات | `transfers_reg` | `FROM_INV_ORG_ID IN (...)` |
| **Page 220** — قوائم الأسعار | `price_lists_reg` | `INV_ORG_ID IN (...)` |
| **Page 240** — دليل الحسابات | `coa_reg` | `LEGAL_ENTITY_ID IN (SELECT LEGAL_ENTITY_ID FROM POS_USER_PERMITTED_LE_V)` |
| **Page 240** — قيود اليومية | `journals_reg` | `LEGAL_ENTITY_ID IN (...)` |
| **Page 250** — الورديات | `shifts_reg` | `INV_ORG_ID IN (SELECT INV_ORG_ID FROM POS_USER_PERMITTED_ORG_V)` |
| **كل LOVs للفروع** | — | استبدل `POS_INVENTORY_ORGS` بـ `POS_USER_PERMITTED_ORG_V` |
| **كل LOVs للشركات** | — | استبدل `POS_LEGAL_ENTITIES` بـ `POS_USER_PERMITTED_LE_V` |
