# دليل تنفيذ صفحة 300: إدارة المستخدمين والصلاحيات (Users & Access Control)

## 1. إعدادات الصفحة (Page Setup)
* **رقم الصفحة (Page Number):** 300
* **اسم الصفحة (Page Name):** إدارة المستخدمين والصلاحيات
* **وضع الصفحة (Page Mode):** Normal
* **القالب (Template):** Standard
* **مخطط التفويض (Authorization Scheme):** AUTH_MANAGER_UP

---

## 2. عناصر الصفحة (Page Items)
* **اسم العنصر:** `P300_SELECTED_USER_ID`
  * **النوع:** Hidden
  * **الوصف:** يستخدم للربط بين المستخدم المحدد وصلاحياته (Master-Detail).
  * **حماية حالة الجلسة (Value Protected):** No (لتحديثه عبر Ajax).

---

## 3. مناطق الصفحة (Regions & SQL Queries)

### المنطقة الأولى: المستخدمين (users_ig)
* **العنوان:** إدارة المستخدمين
* **النوع:** Interactive Grid
* **مصدر البيانات (SQL Query):**
```sql
SELECT APP_USER_ID,
       APEX_USERNAME,
       FULL_NAME_EN,
       FULL_NAME_AR,
       EMAIL,
       PHONE,
       USER_ROLE,
       DEFAULT_INV_ORG_ID,
       DEFAULT_TERMINAL_ID,
       PIN_HASH,
       LANGUAGE_CODE,
       IS_ACTIVE,
       LAST_LOGIN_DATE,
       PASSWORD_CHANGE_DATE,
       FAILED_LOGIN_COUNT,
       ACCOUNT_LOCKED,
       CREATED_BY,
       CREATION_DATE,
       LAST_UPDATED_BY,
       LAST_UPDATE_DATE
  FROM POS_APP_USERS
```
* **خصائص الأعمدة (Column Settings):**
  * `APP_USER_ID`: Primary Key, Hidden.
  * `APEX_USERNAME`: Text Field, العنوان: اسم المستخدم.
  * `FULL_NAME_EN`: Text Field, العنوان: الاسم (إنجليزي).
  * `FULL_NAME_AR`: Text Field, العنوان: الاسم (عربي).
  * `USER_ROLE`: Select List, العنوان: الدور.
    * **Static LOV:** `SYSADMIN=مدير النظام, ORG_ADMIN=مدير المؤسسة, BRANCH_MANAGER=مدير الفرع, CASHIER=كاشير, AUDITOR=مراجع, VIEWER=مشاهد`.
  * `DEFAULT_INV_ORG_ID`: Select List, العنوان: الفرع الافتراضي.
    * **Dynamic LOV:** `SELECT INV_ORG_NAME d, INV_ORG_ID r FROM POS_INVENTORY_ORGS`
  * `DEFAULT_TERMINAL_ID`: Select List, العنوان: نقطة البيع الافتراضية.
    * **Dynamic LOV:** `SELECT TERMINAL_NAME d, TERMINAL_ID r FROM POS_POS_TERMINALS`
  * `PIN_HASH`: Password Field, العنوان: رمز المرور (PIN).
  * `IS_ACTIVE`: Switch, العنوان: فعال؟, القيم: `Y/N`.
  * `ACCOUNT_LOCKED`: Switch, العنوان: مقفل؟, القيم: `Y/N`.
  * أعمدة التدقيق (`CREATED_BY, CREATION_DATE, ...`): Hidden, Display Only.

### المنطقة الثانية: صلاحيات الفروع (user_orgs_ig)
* **العنوان:** صلاحيات الفروع للمستخدم
* **النوع:** Interactive Grid
* **مصدر البيانات (SQL Query):**
```sql
SELECT ACCESS_ID,
       APP_USER_ID,
       INV_ORG_ID,
       ACCESS_LEVEL,
       GRANTED_BY,
       GRANT_DATE,
       REVOKE_DATE,
       IS_ACTIVE
  FROM POS_USER_ORG_ACCESS
 WHERE APP_USER_ID = :P300_SELECTED_USER_ID
```
* **خصائص الأعمدة (Column Settings):**
  * `ACCESS_ID`: Primary Key, Hidden.
  * `APP_USER_ID`: Hidden, Default Value -> Item `P300_SELECTED_USER_ID`.
  * `INV_ORG_ID`: Select List, العنوان: الفرع/المخزن.
    * **Dynamic LOV:** `SELECT INV_ORG_NAME d, INV_ORG_ID r FROM POS_INVENTORY_ORGS`
  * `ACCESS_LEVEL`: Select List, العنوان: مستوى الصلاحية.
    * **Static LOV:** `FULL=وصول كامل, READ_ONLY=قراءة فقط, CASHIER_ONLY=كاشير فقط`.
  * `IS_ACTIVE`: Switch, العنوان: فعال؟, القيم: `Y/N`.

---

## 4. الإجراءات الديناميكية (Dynamic Actions)

### الربط بين الشبكتين (Master-Detail Linking)
* **الحدث:** Selection Change [Interactive Grid]
* **المنطقة:** users_ig
* **الإجراء الأول:** Set Value
  * **النوع:** JavaScript Expression
  * **الكود:** `this.data.selectedRecords[0] ? this.data.model.getValue(this.data.selectedRecords[0], "APP_USER_ID") : ""`
  * **العنصر المتأثر:** `P300_SELECTED_USER_ID`
* **الإجراء الثاني:** Execute Server-Side Code
  * **الكود:** `NULL;` (لإرسال القيمة للخادم).
  * **Items to Submit:** `P300_SELECTED_USER_ID`
* **الإجراء الثالث:** Refresh
  * **المنطقة:** user_orgs_ig

---

## 5. عمليات المعالجة (Processes & Ajax Callbacks)

### معالجة تدقيق المستخدمين (Audit Columns)
* **النوع:** Automatic Row Processing (DML) / PL/SQL
* **النقطة الزمنية (Point):** Processing
* **الكود (إذا تم ككود PL/SQL قبل الحفظ):**
```plsql
BEGIN
    IF :APEX$ROW_STATUS = 'C' THEN
        :CREATED_BY := :AI_USER_ID;
        :CREATION_DATE := SYSDATE;
    END IF;
    IF :APEX$ROW_STATUS IN ('C', 'U') THEN
        :LAST_UPDATED_BY := :AI_USER_ID;
        :LAST_UPDATE_DATE := SYSDATE;
    END IF;
END;
```

---

## 6. الأزرار (Buttons)
* **الزر:** `BTN_RESET_PWD` (في منطقة users_ig)
  * **العنوان:** إعادة تعيين كلمة المرور
  * **السلوك:** Redirect to URL أو Dynamic Action للفتح كـ Dialog مع رسالة تأكيد.
* **الزر:** `BTN_TOGGLE_LOCK`
  * **العنوان:** قفل / فتح الحساب
  * **السلوك:** Dynamic Action يقوم بتنفيذ PL/SQL لتبديل حالة `ACCOUNT_LOCKED`.
