# 📦 جريد استلام البضاعة - دليل البناء الكامل من الصفر
## وفق المعايير العالمية لأنظمة ERP (SAP / Oracle EBS Style)

---

> [!IMPORTANT]
> **المبدأ الذهبي لسلامة البيانات:**
> لا تُعدِّل ولا تمسح أي حركة مخزون بعد حفظها مباشرة.
> الإلغاء = قيد عكسي (Reversal Entry) يُبطل أثر الحركة الأصلية.
> كل حركة = سجل أبدي في تاريخ المخزون (Audit Trail).

---

## ⚙️ المرحلة 0: قاعدة البيانات (Database Layer)

### 0-أ: تعديل جدول POS_INVENTORY_TRANSACTIONS

شغّل في **SQL Workshop ➔ SQL Commands** كل كتلة على حدة:

```sql
-- إضافة عمود حالة الحركة
ALTER TABLE POS_INVENTORY_TRANSACTIONS
ADD TXN_STATUS VARCHAR2(20) DEFAULT 'POSTED'
    CONSTRAINT pos_inv_txn_status_chk
    CHECK (TXN_STATUS IN ('POSTED','REVERSED','REVERSAL'));

-- إضافة مرجع للحركة الأصلية (في حالة القيد العكسي)
ALTER TABLE POS_INVENTORY_TRANSACTIONS
ADD REVERSAL_OF_TXN_ID NUMBER;

-- تحديث السجلات الموجودة
UPDATE POS_INVENTORY_TRANSACTIONS SET TXN_STATUS = 'POSTED' WHERE TXN_STATUS IS NULL;
COMMIT;
```

---

### 0-ب: Trigger لتوليد PK + ضبط حالة الحركة (BEFORE INSERT)

```sql
CREATE OR REPLACE TRIGGER POS_INV_TXN_BIR
BEFORE INSERT ON POS_INVENTORY_TRANSACTIONS
FOR EACH ROW
BEGIN
    -- توليد PK تلقائياً
    IF :NEW.INV_TXN_ID IS NULL THEN
        SELECT NVL(MAX(INV_TXN_ID), 1000000) + 1
          INTO :NEW.INV_TXN_ID
          FROM POS_INVENTORY_TRANSACTIONS;
    END IF;
    -- ضبط تواريخ الإنشاء
    IF :NEW.TXN_DATE IS NULL THEN
        :NEW.TXN_DATE := SYSTIMESTAMP;
    END IF;
    IF :NEW.CREATION_DATE IS NULL THEN
        :NEW.CREATION_DATE := SYSDATE;
    END IF;
    :NEW.LAST_UPDATE_DATE := SYSDATE;
    -- ضبط الحالة الافتراضية
    IF :NEW.TXN_STATUS IS NULL THEN
        :NEW.TXN_STATUS := 'POSTED';
    END IF;
    -- حساب الإجمالي تلقائياً إذا كان فارغاً
    IF :NEW.TOTAL_COST IS NULL AND :NEW.UNIT_COST IS NOT NULL THEN
        :NEW.TOTAL_COST := :NEW.QUANTITY * :NEW.UNIT_COST;
    END IF;
END;
/
```

---

### 0-ج: Trigger لتحديث رصيد المخزون تلقائياً (AFTER INSERT)

```sql
CREATE OR REPLACE TRIGGER POS_INV_TXN_AFTER_INSERT
AFTER INSERT ON POS_INVENTORY_TRANSACTIONS
FOR EACH ROW
DECLARE
    v_bal_count  NUMBER;
    v_qty_change NUMBER;
BEGIN
    -- تحديد اتجاه الحركة: وارد (+) أم صادر (-)
    v_qty_change := CASE :NEW.TXN_TYPE
        WHEN 'RECEIPT'           THEN  :NEW.QUANTITY
        WHEN 'RETURN'            THEN  :NEW.QUANTITY
        WHEN 'TRANSFER_IN'       THEN  :NEW.QUANTITY
        WHEN 'OPENING_BALANCE'   THEN  :NEW.QUANTITY
        WHEN 'SALE'              THEN -:NEW.QUANTITY
        WHEN 'TRANSFER_OUT'      THEN -:NEW.QUANTITY
        WHEN 'WRITE_OFF'         THEN -:NEW.QUANTITY
        WHEN 'ADJUSTMENT'        THEN  :NEW.QUANTITY  -- يعتمد على الإشارة المُدخَلة
        WHEN 'CYCLE_COUNT'       THEN  :NEW.QUANTITY
        ELSE 0
    END;

    -- البحث عن سجل الرصيد
    SELECT COUNT(*) INTO v_bal_count
    FROM POS_INVENTORY_BALANCES
    WHERE INV_ORG_ID           = :NEW.INV_ORG_ID
      AND SUBINV_ID            = :NEW.SUBINV_ID
      AND ITEM_ID              = :NEW.ITEM_ID
      AND NVL(VARIANT_ID, -1) = NVL(:NEW.VARIANT_ID, -1)
      AND UOM_CODE             = NVL(:NEW.UOM_CODE, 'EA');

    IF v_bal_count > 0 THEN
        -- رصيد موجود: حدِّثه
        UPDATE POS_INVENTORY_BALANCES
           SET QUANTITY_ON_HAND       = QUANTITY_ON_HAND + v_qty_change,
               TOTAL_COST            = GREATEST(TOTAL_COST + NVL(:NEW.TOTAL_COST, 0), 0),
               LAST_TRANSACTION_DATE = SYSDATE
         WHERE INV_ORG_ID            = :NEW.INV_ORG_ID
           AND SUBINV_ID             = :NEW.SUBINV_ID
           AND ITEM_ID               = :NEW.ITEM_ID
           AND NVL(VARIANT_ID, -1)  = NVL(:NEW.VARIANT_ID, -1)
           AND UOM_CODE             = NVL(:NEW.UOM_CODE, 'EA');
    ELSE
        -- رصيد جديد: أنشئه
        INSERT INTO POS_INVENTORY_BALANCES (
            INV_ORG_ID, SUBINV_ID, ITEM_ID, VARIANT_ID,
            UOM_CODE, QUANTITY_ON_HAND, TOTAL_COST,
            LAST_TRANSACTION_DATE
        ) VALUES (
            :NEW.INV_ORG_ID, :NEW.SUBINV_ID,
            :NEW.ITEM_ID,    :NEW.VARIANT_ID,
            NVL(:NEW.UOM_CODE,'EA'),
            v_qty_change,
            NVL(:NEW.TOTAL_COST, 0),
            SYSDATE
        );
    END IF;
END;
/
```

---

### 0-د: التحقق من نجاح إنشاء الـ Triggers

```sql
SELECT TRIGGER_NAME, STATUS, TRIGGER_TYPE, TABLE_NAME
FROM USER_TRIGGERS
WHERE TABLE_NAME = 'POS_INVENTORY_TRANSACTIONS'
ORDER BY TRIGGER_NAME;
```

**النتيجة المتوقعة:**

| TRIGGER_NAME | STATUS | TRIGGER_TYPE | TABLE_NAME |
|---|---|---|---|
| POS_INV_TXN_AFTER_INSERT | ENABLED | AFTER EACH ROW | POS_INVENTORY_TRANSACTIONS |
| POS_INV_TXN_BIR | ENABLED | BEFORE EACH ROW | POS_INVENTORY_TRANSACTIONS |

---

## 🏗️ المرحلة 1: بناء Interactive Grid في Page 230

### 1-أ: إنشاء المنطقة

* **Title:** `📦 سجل استلام البضاعة (Stock Receipts)`
* **Type:** `Interactive Grid`
* **Static ID:** `stock_receipt_reg`

---

### 1-ب: SQL Query الكامل

```sql
SELECT
    t.INV_TXN_ID,
    t.INV_ORG_ID,
    io.INV_ORG_NAME,
    t.SUBINV_ID,
    si.SUBINV_NAME,
    t.ITEM_ID,
    i.ITEM_NAME_AR                          AS ITEM_NAME,
    i.ITEM_CODE,
    t.VARIANT_ID,
    NVL(v.SKU_CODE, '—')                   AS VARIANT_SKU,
    NVL(v.VARIANT_NAME_EN, 'بدون متغير')  AS VARIANT_NAME,
    t.UOM_CODE,
    t.QUANTITY,
    t.UNIT_COST,
    NVL(t.TOTAL_COST, t.QUANTITY * NVL(t.UNIT_COST,0)) AS TOTAL_COST,
    t.NOTES,
    t.TXN_STATUS,
    t.REVERSAL_OF_TXN_ID,
    CAST(t.TXN_DATE AS DATE)                AS TXN_DATE,
    -- عمود مساعد لتعطيل زر العكس على الحركات المُعكَسة
    CASE
        WHEN t.TXN_STATUS IN ('REVERSED','REVERSAL')
        THEN 'disabled title="تمت معالجة هذه الحركة"'
        ELSE ''
    END AS BTN_DISABLED,
    -- نص الحالة للعرض
    CASE t.TXN_STATUS
        WHEN 'POSTED'   THEN '🟢 مُرحَّل'
        WHEN 'REVERSED' THEN '🔴 مُلغى'
        WHEN 'REVERSAL' THEN '🔵 قيد عكسي'
    END AS STATUS_LABEL
FROM POS_INVENTORY_TRANSACTIONS t
JOIN POS_INVENTORY_ORGS io  ON io.INV_ORG_ID  = t.INV_ORG_ID
JOIN POS_SUBINVENTORIES si  ON si.SUBINV_ID   = t.SUBINV_ID
JOIN POS_ITEMS i            ON i.ITEM_ID      = t.ITEM_ID
LEFT JOIN POS_ITEM_VARIANTS v ON v.VARIANT_ID = t.VARIANT_ID
WHERE t.TXN_TYPE = 'RECEIPT'
ORDER BY t.TXN_DATE DESC, t.INV_TXN_ID DESC
```

* **Primary Key Column:** `INV_TXN_ID`

---

### 1-ج: ضبط الأعمدة

| اسم العمود | Label | النوع | إعدادات خاصة |
|---|---|---|---|
| `INV_TXN_ID` | — | `Hidden` | Primary Key ✅ |
| `INV_ORG_ID` | **الفرع المستلِم** | `Select List` | LOV: `SELECT INV_ORG_NAME D, INV_ORG_ID R FROM POS_INVENTORY_ORGS WHERE IS_ACTIVE='Y'` / Required |
| `INV_ORG_NAME` | — | `Hidden` | Query Only: **ON** |
| `SUBINV_ID` | **موقع التخزين** | `Select List` | LOV: `SELECT SUBINV_NAME D, SUBINV_ID R FROM POS_SUBINVENTORIES WHERE IS_ACTIVE='Y'` / Required |
| `SUBINV_NAME` | **الموقع** | `Plain Text` | Query Only: **ON** |
| `ITEM_ID` | **الصنف** | `Select List` | LOV: `SELECT ITEM_NAME_AR \|\| ' (' \|\| ITEM_CODE \|\| ')' D, ITEM_ID R FROM POS_ITEMS WHERE IS_ACTIVE='Y' ORDER BY ITEM_NAME_AR` / Required |
| `ITEM_NAME` | **اسم الصنف** | `Plain Text` | Query Only: **ON** |
| `ITEM_CODE` | — | `Hidden` | Query Only: **ON** |
| `VARIANT_ID` | **المتغير** | `Select List` | LOV: `SELECT SKU_CODE \|\| ' - ' \|\| VARIANT_NAME_EN D, VARIANT_ID R FROM POS_ITEM_VARIANTS WHERE IS_ACTIVE='Y'` / Display Null: `— بدون متغير —` |
| `VARIANT_SKU` | **SKU** | `Plain Text` | Query Only: **ON** |
| `VARIANT_NAME` | — | `Hidden` | Query Only: **ON** |
| `UOM_CODE` | **الوحدة** | `Select List` | LOV: `SELECT UOM_NAME_EN D, UOM_CODE R FROM POS_UNITS_OF_MEASURE WHERE IS_ACTIVE='Y'` / Default: `EA` |
| `QUANTITY` | **الكمية المستلمة** | `Number Field` | Required / Format: `999,990` |
| `UNIT_COST` | **سعر الوحدة** | `Number Field` | Format: `999,990.00` |
| `TOTAL_COST` | **الإجمالي** | `Plain Text` | Query Only: **ON** |
| `NOTES` | **ملاحظات / رقم الفاتورة** | `Text Field` | |
| `TXN_STATUS` | — | `Hidden` | Query Only: **ON** |
| `REVERSAL_OF_TXN_ID` | — | `Hidden` | Query Only: **ON** |
| `TXN_DATE` | **تاريخ الاستلام** | `Plain Text` | Query Only: **ON** |
| `BTN_DISABLED` | — | `Hidden` | Query Only: **ON** |
| `STATUS_LABEL` | **الحالة** | `Plain Text` | Query Only: **ON** |
| `إجراءات` | **إجراءات** | `HTML Expression` | *(انظر الكود أدناه)* |

**HTML Expression لعمود الإجراءات:**
```html
<button type="button"
        class="t-Button t-Button--small t-Button--danger"
        onclick="reverseTransaction(&INV_TXN_ID., &QUANTITY., '&ITEM_NAME.', '&VARIANT_SKU.');"
        &BTN_DISABLED.>
  🔄 عكس
</button>
```

---

### 1-د: إعدادات Edit/Toolbar

في **Attributes ➔ Edit**:

| الخاصية | القيمة | السبب |
|---|---|---|
| **Edit Enabled** | `Yes` | لتفعيل وضع الجريد |
| **Allowed Operations ➔ Add Row** | ✅ `Yes` | الإدخال مسموح |
| **Allowed Operations ➔ Update Row** | ❌ `No` | لا تعديل بعد الحفظ! |
| **Allowed Operations ➔ Delete Row** | ❌ `No` | لا حذف! فقط عكس |

---

## 🏗️ المرحلة 2: Ajax Callbacks

### 2-أ: REVERSE_INV_TRANSACTION

في **Processing ➔ Ajax Callback ➔ Create Process**:
* **Name:** `REVERSE_INV_TRANSACTION`

```sql
DECLARE
    v_txn_id     NUMBER       := TO_NUMBER(apex_application.g_x01);
    v_reason     VARCHAR2(500):= apex_application.g_x02;
    v_orig       POS_INVENTORY_TRANSACTIONS%ROWTYPE;
    v_new_id     NUMBER;
BEGIN
    -- جلب الحركة الأصلية والتأكد أنها POSTED فقط
    BEGIN
        SELECT * INTO v_orig
        FROM POS_INVENTORY_TRANSACTIONS
        WHERE INV_TXN_ID = v_txn_id
          AND TXN_STATUS = 'POSTED';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            apex_json.open_object;
            apex_json.write('success', false);
            apex_json.write('message', '⚠️ هذه الحركة تم إلغاؤها مسبقاً أو غير موجودة!');
            apex_json.close_object;
            RETURN;
    END;

    -- تأشير الحركة الأصلية كـ REVERSED
    UPDATE POS_INVENTORY_TRANSACTIONS
       SET TXN_STATUS       = 'REVERSED',
           LAST_UPDATE_DATE = SYSDATE
     WHERE INV_TXN_ID = v_txn_id;

    -- إنشاء القيد العكسي (ADJUSTMENT بكمية سالبة)
    INSERT INTO POS_INVENTORY_TRANSACTIONS (
        INV_ORG_ID, SUBINV_ID, ITEM_ID, VARIANT_ID, UOM_CODE,
        TXN_TYPE,     QUANTITY,           UNIT_COST,
        TOTAL_COST,   NOTES,              TXN_STATUS,
        REVERSAL_OF_TXN_ID
    ) VALUES (
        v_orig.INV_ORG_ID,  v_orig.SUBINV_ID,
        v_orig.ITEM_ID,     v_orig.VARIANT_ID,
        v_orig.UOM_CODE,
        'ADJUSTMENT',
        -v_orig.QUANTITY,                          -- كمية سالبة = عكس الأثر
        v_orig.UNIT_COST,
        -NVL(v_orig.TOTAL_COST, 0),
        'إلغاء حركة رقم ' || v_txn_id || ' | السبب: ' || NVL(v_reason,'—'),
        'REVERSAL',
        v_txn_id
    ) RETURNING INV_TXN_ID INTO v_new_id;
    -- ☝️ الـ AFTER INSERT Trigger يُعدِّل الرصيد تلقائياً!

    COMMIT;

    apex_json.open_object;
    apex_json.write('success',       true);
    apex_json.write('reversalTxnId', v_new_id);
    apex_json.write('message',
        '✅ تم إلغاء الاستلام رقم ' || v_txn_id ||
        ' وخصم ' || ABS(v_orig.QUANTITY) ||
        ' وحدة من المخزون بنجاح.');
    apex_json.close_object;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        apex_json.open_object;
        apex_json.write('success', false);
        apex_json.write('message', 'خطأ في قاعدة البيانات: ' || SQLERRM);
        apex_json.close_object;
END;
```

---

## 🏗️ المرحلة 3: JavaScript في Page 230

في **Page 230 ➔ JavaScript ➔ Execute when Page Loads**:

```javascript
// ==========================================================
// PAGE 230 — STOCK RECEIPT CONTROLLER (ERP Standard)
// ==========================================================

// دالة عكس/إلغاء حركة الاستلام مع Audit Trail
window.reverseTransaction = function(txnId, qty, itemName, variantSku) {
    var displayName = itemName + (variantSku && variantSku !== '—' ? ' / ' + variantSku : '');

    // خطوة 1: مطالبة المستخدم بإدخال سبب الإلغاء (إلزامي)
    var reason = prompt(
        '⚠️ تأكيد إلغاء حركة الاستلام\n' +
        '━━━━━━━━━━━━━━━━━━━━━━━\n' +
        'الصنف: ' + displayName + '\n' +
        'الكمية: ' + qty + ' وحدة\n' +
        'رقم الحركة: ' + txnId + '\n\n' +
        '⚠️ سيتم خصم ' + qty + ' وحدة من رصيد المخزون فوراً!\n\n' +
        'يرجى إدخال سبب الإلغاء (إلزامي):',
        ''
    );

    // إلغاء إذا ضغط Cancel
    if (reason === null) return;

    // رفض الإلغاء إذا كان السبب فارغاً
    if (!reason || reason.trim() === '') {
        apex.message.showErrors([{
            type:     'error',
            location: 'page',
            message:  '⛔ يجب إدخال سبب الإلغاء! العملية ملغاة.'
        }]);
        return;
    }

    // خطوة 2: استدعاء السيرفر لتنفيذ القيد العكسي
    apex.server.process('REVERSE_INV_TRANSACTION', {
        x01: String(txnId),
        x02: reason.trim()
    }, {
        dataType: 'json',
        loadingIndicator: '#stock_receipt_reg',
        success: function(pData) {
            if (pData && pData.success) {
                // نجاح: رسالة + تحديث جميع المناطق المتأثرة
                apex.message.showPageSuccess(pData.message);

                var regions = [
                    'stock_receipt_reg',
                    'stock_balances_reg',
                    'inv_kpi_region'
                ];
                regions.forEach(function(id) {
                    var el = document.getElementById(id);
                    if (el) $(el).trigger('apexrefresh');
                });
            } else {
                apex.message.showErrors([{
                    type:     'error',
                    location: 'page',
                    message:  pData ? pData.message : 'خطأ غير متوقع في الخادم!'
                }]);
            }
        },
        error: function(xhr) {
            apex.message.showErrors([{
                type:     'error',
                location: 'page',
                message:  '⛔ فشل الاتصال بالخادم: ' + xhr.statusText
            }]);
        }
    });
};
```

---

## 🧪 دليل الاختبار الكامل

### ✅ اختبار 1: إدخال استلام صحيح
1. اضغط **Add Row** في جريد الاستلام.
2. أدخل: فرع + موقع + صنف + كمية (مثلاً: 30) + سعر.
3. اضغط **Save**.
4. **التحقق:**
   ```sql
   -- تأكد من تحديث الرصيد
   SELECT QUANTITY_ON_HAND FROM POS_INVENTORY_BALANCES
   WHERE ITEM_ID = [رقم الصنف];
   ```
   ✔️ الرصيد زاد بمقدار 30.
   ✔️ الحركة ظهرت بحالة `🟢 مُرحَّل`.

---

### ✅ اختبار 2: محاولة تعديل سجل محفوظ
1. انقر مرتين على أي خلية في سجل محفوظ.
2. ✔️ لا يفتح أي حقل للتعديل (Update Allowed = No).

---

### ✅ اختبار 3: محاولة حذف سجل محفوظ
1. حاول تحديد سطر والضغط على Delete.
2. ✔️ لا يوجد زر Delete في الـ Toolbar.

---

### ✅ اختبار 4: إلغاء استلام خاطئ (Reversal)
1. اضغط **🔄 عكس** على أي سجل بحالة `🟢 مُرحَّل`.
2. أدخل السبب: `"كمية خاطئة"`.
3. اضغط OK.
4. **التحقق:**
   - ✔️ الحركة الأصلية أصبحت `🔴 مُلغى`.
   - ✔️ سجل جديد ظهر بنوع `ADJUSTMENT` وكمية سالبة بحالة `🔵 قيد عكسي`.
   - ✔️ رصيد المخزون انخفض بمقدار الكمية الملغاة.
   - ✔️ زر **🔄 عكس** أصبح معطلاً `disabled` على كلا السجلين.

---

### ✅ اختبار 5: محاولة عكس حركة مُلغاة بالفعل
1. اضغط **🔄 عكس** على سجل بحالة `🔴 مُلغى`.
2. ✔️ الزر معطل (`disabled`) ولا يمكن النقر عليه.

---

### ✅ اختبار 6: إلغاء نافذة السبب (Cancel)
1. اضغط **🔄 عكس** على أي سجل نشط.
2. في نافذة السبب، اضغط **Cancel**.
3. ✔️ لا يحدث شيء - العملية مُلغاة بالكامل.

---

### ✅ اختبار 7: إدخال سبب فارغ
1. اضغط **🔄 عكس** على أي سجل نشط.
2. اترك حقل السبب فارغاً واضغط OK.
3. ✔️ تظهر رسالة خطأ: `⛔ يجب إدخال سبب الإلغاء!`

---

## 📐 المعايير العالمية المطبَّقة في هذا النظام

| المعيار | التطبيق في نظامنا |
|---|---|
| **Immutable Audit Trail** | كل حركة = سجل أبدي لا يُحذف |
| **Reversal-Only Cancellation** | الإلغاء = قيد عكسي وليس حذفاً |
| **Mandatory Reversal Reason** | سبب الإلغاء إلزامي للـ Audit Trail |
| **Status-Based Row Lock** | REVERSED/REVERSAL لا يمكن عكسهما مرة ثانية |
| **Trigger-Based Balance Update** | الرصيد يتحدث تلقائياً من أي مصدر |
| **Separation of Concerns** | DB Layer (Trigger) منفصل عن UI Layer (APEX) |
| **Atomic Transactions** | COMMIT / ROLLBACK في كل عملية |
| **JSON Error Handling** | كل Ajax Callback يُرجع JSON منظم دائماً |
