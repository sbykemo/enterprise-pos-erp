# دليل تنفيذ صفحة 420 و 430: إعدادات النظام وسجل التدقيق

## 1. صفحة 420: إعدادات النظام (System Settings)
- **نظام الصلاحيات:** `AUTH_MANAGER_UP`

### التبويب 1: الإعدادات (Settings IG)
- تجميع بناءً على `SETTING_SCOPE`.
- **الاستعلام (SQL Query):**
```sql
SELECT 
    SETTING_ID, SETTING_SCOPE, SCOPE_ID, SETTING_KEY, SETTING_VALUE, DATA_TYPE, DESCRIPTION, IS_ENCRYPTED, IS_ACTIVE
FROM POS_APP_SETTINGS
```

### التبويب 2: قوالب الطباعة (Print Templates IG)
- **الاستعلام (SQL Query):**
```sql
SELECT 
    TEMPLATE_ID, TEMPLATE_CODE, TEMPLATE_TYPE, INV_ORG_ID, TEMPLATE_BODY, PAPER_WIDTH, IS_DEFAULT, IS_ACTIVE
FROM POS_PRINT_TEMPLATES
```
- `TEMPLATE_BODY`: نوعه Rich Text Editor أو Textarea كبير لتعديل الـ CLOB.

---

## 2. صفحة 430: سجل التدقيق (Audit Log)
- **نظام الصلاحيات:** `AUTH_MANAGER_UP`
- 3 علامات تبويب للقراءة فقط (Interactive Reports).

### التبويب 1: سجل التدقيق (Audit Log)
- فلاتر مخصصة لتاريخ التعديل (Date Range) واسم الجدول (Table Name).
- **الاستعلام (SQL Query):**
```sql
SELECT 
    AUDIT_ID, TABLE_NAME, RECORD_ID, ACTION_TYPE, OLD_VALUES, NEW_VALUES, CHANGED_BY, CHANGE_DATE, SESSION_ID, IP_ADDRESS, TERMINAL_ID, INV_ORG_ID
FROM POS_AUDIT_LOG
```
- `OLD_VALUES` و `NEW_VALUES`: تنسيق JSON في الواجهة.

### التبويب 2: طابور المزامنة (Sync Queue)
- **الاستعلام:**
```sql
SELECT SYNC_ID, IDEMPOTENCY_KEY, TERMINAL_ID, INV_ORG_ID, CASHIER_USER_ID, PAYLOAD_TYPE, SYNC_STATUS, RETRY_COUNT, LAST_ERROR
FROM POS_OFFLINE_SYNC_QUEUE
```

### التبويب 3: سجل التعارضات (Conflict Log)
- **الاستعلام:**
```sql
SELECT CONFLICT_ID, SYNC_ID, CONFLICT_TYPE, RESOLUTION
FROM POS_SYNC_CONFLICT_LOG
```
