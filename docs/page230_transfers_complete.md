# 🔄 نظام تحويلات البضاعة بين الفروع
## دليل البناء الكامل وفق معايير ERP العالمية

---

## 🗺️ دورة حياة التحويل (Transfer Lifecycle)

```
  [DRAFT]
  مسودة
  ↙       ↘
يُلغى    يُعتمد
  ↓          ↓
[CANCELLED] [APPROVED]
  مُلغى    معتمد
             ↙    ↘
         يُلغى  يُشحن
           ↓       ↓
      [CANCELLED] [IN_TRANSIT]
                  في الطريق
                  ↙      ↘
              يُلغى    يُستلم
                ↓         ↓
          [CANCELLED]  [RECEIVED]
                       مُستلَم ✅
```

### 🔑 قواعد كل مرحلة:

| الحالة | هل يمكن تعديل الرأس؟ | هل يمكن تعديل البنود؟ | هل يمكن الإلغاء؟ | أثر على المخزون |
|---|---|---|---|---|
| **DRAFT** | ✅ نعم | ✅ نعم | ✅ نعم (بدون أثر) | لا شيء |
| **APPROVED** | 🔶 جزئي (ملاحظات/تواريخ) | ✅ نعم | ✅ نعم (بدون أثر) | لا شيء |
| **IN_TRANSIT** | ❌ لا | ❌ لا | ✅ نعم + يعكس الخصم | خصم من المصدر (TRANSFER_OUT) |
| **RECEIVED** | ❌ لا | ❌ لا | ❌ لا | إضافة للوجهة (TRANSFER_IN) |
| **CANCELLED** | ❌ لا | ❌ لا | ❌ لا | يعكس حسب المرحلة |

---

## ⚙️ المرحلة 0: قاعدة البيانات

### 0-أ: إضافة عمود `CAN_EDIT_LINES` لجدول التحويلات

```sql
-- إضافة عمود مساعد لتحديد ما إذا كانت البنود قابلة للتعديل
-- (يُستخدم في Allowed Row Operations Column في الـ IG)
ALTER TABLE POS_STOCK_TRANSFERS
ADD CANCEL_REASON VARCHAR2(500);

-- تحديث TRANSFER_STATUS الافتراضية
UPDATE POS_STOCK_TRANSFERS
   SET TRANSFER_STATUS = 'DRAFT'
 WHERE TRANSFER_STATUS IS NULL;

COMMIT;
```

---

### 0-ب: Trigger لتوليد PK ورقم التحويل (BIR)

```sql
CREATE OR REPLACE TRIGGER POS_STOCK_TRANSFERS_BIR
BEFORE INSERT ON POS_STOCK_TRANSFERS
FOR EACH ROW
DECLARE
    v_next_id NUMBER;
BEGIN
    -- توليد PK
    IF :NEW.TRANSFER_ID IS NULL THEN
        SELECT NVL(MAX(TRANSFER_ID), 1000000) + 1
          INTO :NEW.TRANSFER_ID
          FROM POS_STOCK_TRANSFERS;
    END IF;
    -- توليد رقم التحويل تلقائياً
    IF :NEW.TRANSFER_NO IS NULL THEN
        SELECT NVL(MAX(TRANSFER_ID), 1000000) + 1
          INTO v_next_id
          FROM POS_STOCK_TRANSFERS;
        :NEW.TRANSFER_NO := 'TRF-' || TO_CHAR(SYSDATE,'YYYYMMDD') ||
                            '-' || LPAD(v_next_id - 1000000, 5, '0');
    END IF;
    -- ضبط الحالة الافتراضية
    IF :NEW.TRANSFER_STATUS IS NULL THEN
        :NEW.TRANSFER_STATUS := 'DRAFT';
    END IF;
    -- ضبط تاريخ الإنشاء
    IF :NEW.CREATION_DATE IS NULL THEN
        :NEW.CREATION_DATE := SYSDATE;
    END IF;
    :NEW.LAST_UPDATE_DATE := SYSDATE;
END;
/

CREATE OR REPLACE TRIGGER POS_STOCK_TRF_LINES_BIR
BEFORE INSERT ON POS_STOCK_TRANSFER_LINES
FOR EACH ROW
DECLARE
    v_line_no NUMBER;
BEGIN
    -- توليد PK
    IF :NEW.TRANSFER_LINE_ID IS NULL THEN
        SELECT NVL(MAX(TRANSFER_LINE_ID), 1000000) + 1
          INTO :NEW.TRANSFER_LINE_ID
          FROM POS_STOCK_TRANSFER_LINES;
    END IF;
    -- توليد رقم السطر تلقائياً
    IF :NEW.LINE_NO IS NULL THEN
        SELECT NVL(MAX(LINE_NO), 0) + 1
          INTO v_line_no
          FROM POS_STOCK_TRANSFER_LINES
         WHERE TRANSFER_ID = :NEW.TRANSFER_ID;
        :NEW.LINE_NO := v_line_no;
    END IF;
    -- ضبط حالة السطر
    IF :NEW.LINE_STATUS IS NULL THEN
        :NEW.LINE_STATUS := 'PENDING';
    END IF;
    IF :NEW.CREATION_DATE IS NULL THEN
        :NEW.CREATION_DATE := SYSDATE;
    END IF;
    :NEW.LAST_UPDATE_DATE := SYSDATE;
END;
/
```

---

### 0-ج: Ajax Callback `PROCESS_TRANSFER_ACTION`

هذا هو قلب النظام! يتعامل مع كل تحولات الحالة وأثرها على المخزون.

في **Processing ➔ Ajax Callback**، أنشئ Process باسم `PROCESS_TRANSFER_ACTION`:

```sql
DECLARE
    v_transfer_id  NUMBER       := TO_NUMBER(apex_application.g_x01);
    v_action       VARCHAR2(20) := apex_application.g_x02;
    -- APPROVE / SHIP / RECEIVE / CANCEL
    v_reason       VARCHAR2(500):= apex_application.g_x03;
    v_transfer     POS_STOCK_TRANSFERS%ROWTYPE;

    PROCEDURE post_inventory_txn(
        p_org_id     NUMBER,
        p_subinv_id  NUMBER,
        p_item_id    NUMBER,
        p_variant_id NUMBER,
        p_uom        VARCHAR2,
        p_qty        NUMBER,
        p_cost       NUMBER,
        p_txn_type   VARCHAR2,
        p_ref_id     NUMBER
    ) IS
    BEGIN
        INSERT INTO POS_INVENTORY_TRANSACTIONS (
            INV_ORG_ID, SUBINV_ID, ITEM_ID, VARIANT_ID,
            UOM_CODE, TXN_TYPE, QUANTITY,
            UNIT_COST, TOTAL_COST,
            TRANSFER_ID, TXN_STATUS,
            NOTES
        ) VALUES (
            p_org_id, p_subinv_id, p_item_id, p_variant_id,
            NVL(p_uom,'EA'), p_txn_type, p_qty,
            p_cost, p_qty * NVL(p_cost,0),
            p_ref_id, 'POSTED',
            p_txn_type || ' - Transfer #' || p_ref_id
        );
        -- الـ AFTER INSERT Trigger يُحدِّث الرصيد تلقائياً!
    END;

BEGIN
    -- جلب بيانات التحويل والتحقق من وجوده
    BEGIN
        SELECT * INTO v_transfer
        FROM POS_STOCK_TRANSFERS
        WHERE TRANSFER_ID = v_transfer_id
        FOR UPDATE; -- قفل للتحديث
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            apex_json.open_object;
            apex_json.write('success', false);
            apex_json.write('message', '⚠️ التحويل غير موجود!');
            apex_json.close_object;
            RETURN;
    END;

    -- =============================================
    -- APPROVE: مسودة → معتمد
    -- =============================================
    IF v_action = 'APPROVE' THEN
        IF v_transfer.TRANSFER_STATUS != 'DRAFT' THEN
            apex_json.open_object;
            apex_json.write('success', false);
            apex_json.write('message', '⚠️ لا يمكن اعتماد تحويل بحالة: ' || v_transfer.TRANSFER_STATUS);
            apex_json.close_object;
            RETURN;
        END IF;

        -- التحقق من وجود بنود
        DECLARE v_lines_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_lines_count
            FROM POS_STOCK_TRANSFER_LINES
            WHERE TRANSFER_ID = v_transfer_id;
            IF v_lines_count = 0 THEN
                apex_json.open_object;
                apex_json.write('success', false);
                apex_json.write('message', '⚠️ لا يمكن اعتماد تحويل بدون بنود!');
                apex_json.close_object;
                RETURN;
            END IF;
        END;

        UPDATE POS_STOCK_TRANSFERS
           SET TRANSFER_STATUS = 'APPROVED', LAST_UPDATE_DATE = SYSDATE
         WHERE TRANSFER_ID = v_transfer_id;

        UPDATE POS_STOCK_TRANSFER_LINES
           SET LINE_STATUS = 'APPROVED', LAST_UPDATE_DATE = SYSDATE
         WHERE TRANSFER_ID = v_transfer_id AND LINE_STATUS = 'PENDING';

    -- =============================================
    -- SHIP: معتمد → في الطريق + خصم من المصدر
    -- =============================================
    ELSIF v_action = 'SHIP' THEN
        IF v_transfer.TRANSFER_STATUS != 'APPROVED' THEN
            apex_json.open_object;
            apex_json.write('success', false);
            apex_json.write('message', '⚠️ لا يمكن الشحن إلا بعد الاعتماد!');
            apex_json.close_object;
            RETURN;
        END IF;

        -- خصم الكميات من مخزون الفرع المُرسِل (TRANSFER_OUT)
        FOR ln IN (
            SELECT l.ITEM_ID, l.VARIANT_ID, l.UOM_CODE,
                   NVL(l.APPROVED_QTY, l.REQUESTED_QTY) AS SHIP_QTY,
                   l.UNIT_COST
            FROM POS_STOCK_TRANSFER_LINES l
            WHERE l.TRANSFER_ID = v_transfer_id
              AND l.LINE_STATUS != 'CANCELLED'
        ) LOOP
            -- التحقق من كفاية المخزون
            DECLARE v_available NUMBER;
            BEGIN
                SELECT NVL(QUANTITY_ON_HAND, 0) - NVL(QUANTITY_RESERVED, 0)
                  INTO v_available
                  FROM POS_INVENTORY_BALANCES
                 WHERE INV_ORG_ID = v_transfer.FROM_INV_ORG_ID
                   AND ITEM_ID = ln.ITEM_ID
                   AND NVL(VARIANT_ID, -1) = NVL(ln.VARIANT_ID, -1);

                IF v_available < ln.SHIP_QTY THEN
                    ROLLBACK;
                    apex_json.open_object;
                    apex_json.write('success', false);
                    apex_json.write('message',
                        '⚠️ مخزون غير كافٍ للصنف ID=' || ln.ITEM_ID ||
                        ' | المتاح: ' || v_available ||
                        ' | المطلوب: ' || ln.SHIP_QTY);
                    apex_json.close_object;
                    RETURN;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    ROLLBACK;
                    apex_json.open_object;
                    apex_json.write('success', false);
                    apex_json.write('message', '⚠️ لا يوجد رصيد مخزون للصنف ID=' || ln.ITEM_ID || ' في الفرع المُرسِل!');
                    apex_json.close_object;
                    RETURN;
            END;

            -- تسجيل حركة TRANSFER_OUT (الـ Trigger يخصم تلقائياً)
            post_inventory_txn(
                v_transfer.FROM_INV_ORG_ID,
                NVL(v_transfer.FROM_SUBINV_ID, 1000001),
                ln.ITEM_ID, ln.VARIANT_ID,
                NVL(ln.UOM_CODE,'EA'),
                ln.SHIP_QTY, ln.UNIT_COST,
                'TRANSFER_OUT', v_transfer_id
            );
        END LOOP;

        UPDATE POS_STOCK_TRANSFERS
           SET TRANSFER_STATUS = 'IN_TRANSIT',
               TRANSFER_DATE   = SYSDATE,
               LAST_UPDATE_DATE = SYSDATE
         WHERE TRANSFER_ID = v_transfer_id;

        UPDATE POS_STOCK_TRANSFER_LINES
           SET LINE_STATUS = 'SHIPPED',
               SHIPPED_QTY = NVL(APPROVED_QTY, REQUESTED_QTY),
               LAST_UPDATE_DATE = SYSDATE
         WHERE TRANSFER_ID = v_transfer_id
           AND LINE_STATUS = 'APPROVED';

    -- =============================================
    -- RECEIVE: في الطريق → مستلَم + إضافة للوجهة
    -- =============================================
    ELSIF v_action = 'RECEIVE' THEN
        IF v_transfer.TRANSFER_STATUS != 'IN_TRANSIT' THEN
            apex_json.open_object;
            apex_json.write('success', false);
            apex_json.write('message', '⚠️ لا يمكن الاستلام إلا للتحويلات في الطريق!');
            apex_json.close_object;
            RETURN;
        END IF;

        -- إضافة الكميات لمخزون الفرع المُستلِم (TRANSFER_IN)
        FOR ln IN (
            SELECT l.ITEM_ID, l.VARIANT_ID, l.UOM_CODE,
                   NVL(l.SHIPPED_QTY, l.REQUESTED_QTY) AS RCV_QTY,
                   l.UNIT_COST
            FROM POS_STOCK_TRANSFER_LINES l
            WHERE l.TRANSFER_ID = v_transfer_id
              AND l.LINE_STATUS = 'SHIPPED'
        ) LOOP
            -- تسجيل حركة TRANSFER_IN (الـ Trigger يُضيف تلقائياً)
            post_inventory_txn(
                v_transfer.TO_INV_ORG_ID,
                NVL(v_transfer.TO_SUBINV_ID, 1000001),
                ln.ITEM_ID, ln.VARIANT_ID,
                NVL(ln.UOM_CODE,'EA'),
                ln.RCV_QTY, ln.UNIT_COST,
                'TRANSFER_IN', v_transfer_id
            );
        END LOOP;

        UPDATE POS_STOCK_TRANSFERS
           SET TRANSFER_STATUS      = 'RECEIVED',
               ACTUAL_RECEIVE_DATE  = SYSDATE,
               LAST_UPDATE_DATE     = SYSDATE
         WHERE TRANSFER_ID = v_transfer_id;

        UPDATE POS_STOCK_TRANSFER_LINES
           SET LINE_STATUS   = 'RECEIVED',
               RECEIVED_QTY = NVL(SHIPPED_QTY, REQUESTED_QTY),
               LAST_UPDATE_DATE = SYSDATE
         WHERE TRANSFER_ID = v_transfer_id
           AND LINE_STATUS  = 'SHIPPED';

    -- =============================================
    -- CANCEL: إلغاء مع عكس أثر المخزون إن وُجد
    -- =============================================
    ELSIF v_action = 'CANCEL' THEN
        IF v_transfer.TRANSFER_STATUS IN ('RECEIVED','CANCELLED') THEN
            apex_json.open_object;
            apex_json.write('success', false);
            apex_json.write('message', '⚠️ لا يمكن إلغاء تحويل بحالة: ' || v_transfer.TRANSFER_STATUS);
            apex_json.close_object;
            RETURN;
        END IF;

        -- إذا كان التحويل في الطريق، يجب عكس الخصم من الفرع المُرسِل
        IF v_transfer.TRANSFER_STATUS = 'IN_TRANSIT' THEN
            FOR ln IN (
                SELECT l.ITEM_ID, l.VARIANT_ID, l.UOM_CODE,
                       NVL(l.SHIPPED_QTY, l.REQUESTED_QTY) AS REVERSE_QTY,
                       l.UNIT_COST
                FROM POS_STOCK_TRANSFER_LINES l
                WHERE l.TRANSFER_ID = v_transfer_id
                  AND l.LINE_STATUS = 'SHIPPED'
            ) LOOP
                -- عكس TRANSFER_OUT = ADJUSTMENT موجب يُعيد المخزون للمصدر
                INSERT INTO POS_INVENTORY_TRANSACTIONS (
                    INV_ORG_ID, SUBINV_ID, ITEM_ID, VARIANT_ID,
                    UOM_CODE, TXN_TYPE, QUANTITY,
                    UNIT_COST, TOTAL_COST,
                    TRANSFER_ID, TXN_STATUS, NOTES
                ) VALUES (
                    v_transfer.FROM_INV_ORG_ID,
                    NVL(v_transfer.FROM_SUBINV_ID, 1000001),
                    ln.ITEM_ID, ln.VARIANT_ID,
                    NVL(ln.UOM_CODE,'EA'),
                    'ADJUSTMENT', ln.REVERSE_QTY,
                    ln.UNIT_COST, ln.REVERSE_QTY * NVL(ln.UNIT_COST,0),
                    v_transfer_id, 'REVERSAL',
                    'إلغاء تحويل رقم ' || v_transfer_id || ' | ' || NVL(v_reason,'—')
                );
            END LOOP;
        END IF;

        UPDATE POS_STOCK_TRANSFERS
           SET TRANSFER_STATUS = 'CANCELLED',
               CANCEL_REASON   = v_reason,
               LAST_UPDATE_DATE = SYSDATE
         WHERE TRANSFER_ID = v_transfer_id;

        UPDATE POS_STOCK_TRANSFER_LINES
           SET LINE_STATUS = 'CANCELLED', LAST_UPDATE_DATE = SYSDATE
         WHERE TRANSFER_ID = v_transfer_id
           AND LINE_STATUS NOT IN ('RECEIVED');

    ELSE
        apex_json.open_object;
        apex_json.write('success', false);
        apex_json.write('message', '⚠️ إجراء غير معروف: ' || v_action);
        apex_json.close_object;
        RETURN;
    END IF;

    COMMIT;

    apex_json.open_object;
    apex_json.write('success', true);
    apex_json.write('action', v_action);
    apex_json.write('message',
        CASE v_action
            WHEN 'APPROVE'  THEN '✅ تم اعتماد التحويل رقم ' || v_transfer_id
            WHEN 'SHIP'     THEN '🚚 تم شحن التحويل وخصم المخزون من الفرع المُرسِل'
            WHEN 'RECEIVE'  THEN '✅ تم استلام التحويل وإضافة المخزون للفرع المُستلِم'
            WHEN 'CANCEL'   THEN '🚫 تم إلغاء التحويل' ||
                                 CASE WHEN v_transfer.TRANSFER_STATUS = 'IN_TRANSIT'
                                      THEN ' وإعادة المخزون للفرع المُرسِل'
                                      ELSE '' END
        END
    );
    apex_json.close_object;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        apex_json.open_object;
        apex_json.write('success', false);
        apex_json.write('message', 'خطأ: ' || SQLERRM);
        apex_json.close_object;
END;
```

---

## 🏗️ المرحلة 1: جريد التحويلات الرئيسي (Stock Transfers)

### 1-أ: SQL Query

```sql
SELECT
    t.TRANSFER_ID,
    t.TRANSFER_NO,
    t.FROM_INV_ORG_ID,
    f.INV_ORG_NAME                          AS FROM_ORG_NAME,
    t.TO_INV_ORG_ID,
    o.INV_ORG_NAME                          AS TO_ORG_NAME,
    t.TRANSFER_STATUS,
    -- تسمية الحالة بالعربي مع أيقونة
    CASE t.TRANSFER_STATUS
        WHEN 'DRAFT'       THEN '📝 مسودة'
        WHEN 'APPROVED'    THEN '✅ معتمد'
        WHEN 'IN_TRANSIT'  THEN '🚚 في الطريق'
        WHEN 'RECEIVED'    THEN '📦 مستلَم'
        WHEN 'CANCELLED'   THEN '🚫 مُلغى'
    END                                     AS STATUS_LABEL,
    t.TRANSFER_DATE,
    t.EXPECTED_DATE,
    t.ACTUAL_RECEIVE_DATE,
    t.NOTES,
    t.CANCEL_REASON,
    -- عدد بنود التحويل
    (SELECT COUNT(*) FROM POS_STOCK_TRANSFER_LINES l
      WHERE l.TRANSFER_ID = t.TRANSFER_ID)  AS LINES_COUNT,
    -- إجمالي الكميات
    (SELECT NVL(SUM(l.REQUESTED_QTY),0)
       FROM POS_STOCK_TRANSFER_LINES l
      WHERE l.TRANSFER_ID = t.TRANSFER_ID)  AS TOTAL_QTY,
    -- أزرار الإجراءات حسب الحالة
    CASE t.TRANSFER_STATUS
        WHEN 'DRAFT'      THEN 'APPROVE,VIEW_LINES,CANCEL'
        WHEN 'APPROVED'   THEN 'SHIP,VIEW_LINES,CANCEL'
        WHEN 'IN_TRANSIT' THEN 'RECEIVE,VIEW_LINES,CANCEL'
        WHEN 'RECEIVED'   THEN 'VIEW_LINES'
        WHEN 'CANCELLED'  THEN 'VIEW_LINES'
        ELSE 'VIEW_LINES'
    END                                     AS ALLOWED_ACTIONS
FROM POS_STOCK_TRANSFERS t
JOIN POS_INVENTORY_ORGS f ON f.INV_ORG_ID = t.FROM_INV_ORG_ID
JOIN POS_INVENTORY_ORGS o ON o.INV_ORG_ID = t.TO_INV_ORG_ID
ORDER BY t.CREATION_DATE DESC, t.TRANSFER_ID DESC
```

* **Primary Key:** `TRANSFER_ID`

---

### 1-ب: ضبط الأعمدة

| اسم العمود | Label | النوع | إعدادات |
|---|---|---|---|
| `TRANSFER_ID` | — | `Hidden` | PK ✅ |
| `TRANSFER_NO` | **رقم التحويل** | `Plain Text` | Query Only: **ON** (يتولد تلقائياً) |
| `FROM_INV_ORG_ID` | **من فرع** | `Select List` | LOV: POS_INVENTORY_ORGS / Required |
| `FROM_ORG_NAME` | **الفرع المُرسِل** | `Plain Text` | Query Only: **ON** |
| `TO_INV_ORG_ID` | **إلى فرع** | `Select List` | LOV: POS_INVENTORY_ORGS / Required |
| `TO_ORG_NAME` | **الفرع المُستلِم** | `Plain Text` | Query Only: **ON** |
| `TRANSFER_STATUS` | — | `Hidden` | Query Only: **ON** |
| `STATUS_LABEL` | **الحالة** | `Plain Text` | Query Only: **ON** |
| `TRANSFER_DATE` | **تاريخ التحويل** | `Date Picker` | Default: Today |
| `EXPECTED_DATE` | **التاريخ المتوقع** | `Date Picker` | |
| `ACTUAL_RECEIVE_DATE` | **تاريخ الاستلام الفعلي** | `Plain Text` | Query Only: **ON** |
| `NOTES` | **ملاحظات** | `Text Field` | |
| `CANCEL_REASON` | **سبب الإلغاء** | `Plain Text` | Query Only: **ON** |
| `LINES_COUNT` | **بنود** | `Plain Text` | Query Only: **ON** |
| `TOTAL_QTY` | **إجمالي الكميات** | `Plain Text` | Query Only: **ON** |
| `ALLOWED_ACTIONS` | — | `Hidden` | Query Only: **ON** |
| `إجراءات` | **إجراءات** | `HTML Expression` | *(انظر HTML أدناه)* |

**HTML Expression لعمود الإجراءات:**
```html
<div style="display:flex;gap:4px;flex-wrap:wrap;">
  <!-- زر عرض البنود (دائماً ظاهر) -->
  <button type="button" class="t-Button t-Button--small t-Button--primary"
    onclick="showTransferLines(this,&TRANSFER_ID.,'&TRANSFER_NO.');">
    📋 بنود (&LINES_COUNT.)
  </button>
  <!-- زر الاعتماد (DRAFT فقط) -->
  <button type="button" class="t-Button t-Button--small t-Button--success"
    onclick="doTransferAction(this,&TRANSFER_ID.,'APPROVE','');"
    style="display:&SHOW_APPROVE.">
    ✅ اعتماد
  </button>
  <!-- زر الشحن (APPROVED فقط) -->
  <button type="button" class="t-Button t-Button--small t-Button--warning"
    onclick="doTransferAction(this,&TRANSFER_ID.,'SHIP','');"
    style="display:&SHOW_SHIP.">
    🚚 شحن
  </button>
  <!-- زر الاستلام (IN_TRANSIT فقط) -->
  <button type="button" class="t-Button t-Button--small t-Button--success"
    onclick="doTransferAction(this,&TRANSFER_ID.,'RECEIVE','');"
    style="display:&SHOW_RECEIVE.">
    📦 استلام
  </button>
  <!-- زر الإلغاء -->
  <button type="button" class="t-Button t-Button--small t-Button--danger"
    onclick="doTransferAction(this,&TRANSFER_ID.,'CANCEL','&TRANSFER_STATUS.');"
    style="display:&SHOW_CANCEL.">
    🚫 إلغاء
  </button>
</div>
```

> [!NOTE]
> لتشغيل أزرار الإظهار/الإخفاء، أضف هذه الأعمدة المحسوبة في SQL:
> ```sql
> CASE WHEN t.TRANSFER_STATUS = 'DRAFT'      THEN 'inline-block' ELSE 'none' END AS SHOW_APPROVE,
> CASE WHEN t.TRANSFER_STATUS = 'APPROVED'   THEN 'inline-block' ELSE 'none' END AS SHOW_SHIP,
> CASE WHEN t.TRANSFER_STATUS = 'IN_TRANSIT' THEN 'inline-block' ELSE 'none' END AS SHOW_RECEIVE,
> CASE WHEN t.TRANSFER_STATUS NOT IN ('RECEIVED','CANCELLED') THEN 'inline-block' ELSE 'none' END AS SHOW_CANCEL
> ```

---

### 1-ج: إعدادات Edit/Toolbar

| الخاصية | القيمة |
|---|---|
| **Add Row** | ✅ `Yes` (إنشاء تحويل جديد) |
| **Update Row** | ❌ `No` (التحديث عبر أزرار الإجراءات فقط) |
| **Delete Row** | ❌ `No` (الإلغاء عبر زر CANCEL فقط) |

---

## 🏗️ المرحلة 2: جريد بنود التحويل (Transfer Lines)

### 2-أ: SQL Query

```sql
SELECT
    l.TRANSFER_LINE_ID,
    l.TRANSFER_ID,
    l.LINE_NO,
    l.ITEM_ID,
    i.ITEM_NAME_AR                              AS ITEM_NAME,
    i.ITEM_CODE,
    l.VARIANT_ID,
    NVL(v.SKU_CODE,'—')                        AS VARIANT_SKU,
    NVL(v.VARIANT_NAME_EN,'بدون متغير')        AS VARIANT_NAME,
    l.UOM_CODE,
    l.REQUESTED_QTY,
    l.APPROVED_QTY,
    l.SHIPPED_QTY,
    l.RECEIVED_QTY,
    l.UNIT_COST,
    l.LINE_STATUS,
    CASE l.LINE_STATUS
        WHEN 'PENDING'   THEN '⏳ معلق'
        WHEN 'APPROVED'  THEN '✅ معتمد'
        WHEN 'SHIPPED'   THEN '🚚 مشحون'
        WHEN 'RECEIVED'  THEN '📦 مستلَم'
        WHEN 'CANCELLED' THEN '🚫 مُلغى'
    END                                         AS LINE_STATUS_LABEL,
    -- المخزون المتاح في الفرع المُرسِل
    (SELECT NVL(b.QUANTITY_ON_HAND,0) - NVL(b.QUANTITY_RESERVED,0)
       FROM POS_INVENTORY_BALANCES b
       JOIN POS_STOCK_TRANSFERS t ON t.TRANSFER_ID = l.TRANSFER_ID
      WHERE b.INV_ORG_ID = t.FROM_INV_ORG_ID
        AND b.ITEM_ID    = l.ITEM_ID
        AND NVL(b.VARIANT_ID,-1) = NVL(l.VARIANT_ID,-1)
        AND ROWNUM = 1)                         AS AVAILABLE_STOCK,
    -- هل السطر قابل للتعديل؟ (PENDING أو APPROVED فقط)
    CASE WHEN l.LINE_STATUS IN ('PENDING','APPROVED') THEN 'Y' ELSE 'N' END AS IS_EDITABLE
FROM POS_STOCK_TRANSFER_LINES l
JOIN POS_ITEMS i ON i.ITEM_ID = l.ITEM_ID
LEFT JOIN POS_ITEM_VARIANTS v ON v.VARIANT_ID = l.VARIANT_ID
WHERE l.TRANSFER_ID = NVL(:P230_SELECTED_TRANSFER_ID, -1)
ORDER BY l.LINE_NO
```

* **Primary Key:** `TRANSFER_LINE_ID`
* **Page Items to Submit:** `P230_SELECTED_TRANSFER_ID`

---

### 2-ب: ضبط الأعمدة

| اسم العمود | Label | النوع | إعدادات |
|---|---|---|---|
| `TRANSFER_LINE_ID` | — | `Hidden` | PK ✅ |
| `TRANSFER_ID` | — | `Hidden` | Default: `Item = P230_SELECTED_TRANSFER_ID` / Query Only: **OFF** |
| `LINE_NO` | **#** | `Plain Text` | Query Only: **ON** (يتولد من Trigger) |
| `ITEM_ID` | **الصنف** | `Select List` | LOV: POS_ITEMS |
| `ITEM_NAME` | **اسم الصنف** | `Plain Text` | Query Only: **ON** |
| `ITEM_CODE` | — | `Hidden` | Query Only: **ON** |
| `VARIANT_ID` | **المتغير** | `Select List` | LOV: POS_ITEM_VARIANTS / Display Null: `— بدون متغير —` |
| `VARIANT_SKU` | **SKU** | `Plain Text` | Query Only: **ON** |
| `VARIANT_NAME` | — | `Hidden` | Query Only: **ON** |
| `UOM_CODE` | **الوحدة** | `Select List` | LOV: POS_UNITS_OF_MEASURE / Default: `EA` |
| `REQUESTED_QTY` | **الكمية المطلوبة** | `Number Field` | Required |
| `APPROVED_QTY` | **الكمية المعتمدة** | `Number Field` | |
| `SHIPPED_QTY` | **الكمية المشحونة** | `Plain Text` | Query Only: **ON** |
| `RECEIVED_QTY` | **الكمية المستلمة** | `Plain Text` | Query Only: **ON** |
| `UNIT_COST` | **سعر الوحدة** | `Number Field` | |
| `LINE_STATUS` | — | `Hidden` | Query Only: **ON** |
| `LINE_STATUS_LABEL` | **حالة السطر** | `Plain Text` | Query Only: **ON** |
| `AVAILABLE_STOCK` | **المخزون المتاح** | `Plain Text` | Query Only: **ON** |
| `IS_EDITABLE` | — | `Hidden` | Query Only: **ON** |

---

### 2-ج: إعدادات Edit/Toolbar

| الخاصية | القيمة |
|---|---|
| **Add Row** | ✅ `Yes` |
| **Update Row** | ✅ `Yes` |
| **Delete Row** | ✅ `Yes` |
| **Allowed Row Operations Column** | `IS_EDITABLE` ← هذا هو المفتاح! |

> [!IMPORTANT]
> عمود `IS_EDITABLE` هو الحارس الذكي:
> - إذا كان السطر `PENDING` أو `APPROVED`: قيمته `Y` ← يمكن التعديل والحذف
> - إذا كان `SHIPPED` أو `RECEIVED` أو `CANCELLED`: قيمته `N` ← مقفل للقراءة فقط!

---

## 🏗️ المرحلة 3: JavaScript الكامل

في **Page 230 ➔ JavaScript ➔ Execute when Page Loads** (استبدل الكود القديم بالكامل):

```javascript
// ==========================================================
// PAGE 230 — INVENTORY & TRANSFERS CONTROLLER (ERP Standard)
// ==========================================================

// 1. عرض بنود التحويل
window.showTransferLines = function(pBtn, transferId, transferNo) {
    if (pBtn) {
        var $tr = $(pBtn).closest('tr');
        $tr.siblings().removeClass('is-selected');
        $tr.addClass('is-selected');
    }
    apex.item('P230_SELECTED_TRANSFER_ID').setValue(transferId);

    apex.server.process('SET_TRANSFER_ID_SESSION', {
        x01: String(transferId)
    }, {
        dataType: 'json',
        success: function() {
            var linesEl = document.getElementById('transfer_lines_reg');
            if (linesEl) {
                $(linesEl).trigger('apexrefresh');
                setTimeout(function() {
                    linesEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
                }, 300);
            }
        }
    });
};

// 2. تنفيذ إجراء على التحويل (Approve / Ship / Receive / Cancel)
window.doTransferAction = function(pBtn, transferId, action, currentStatus) {
    var messages = {
        'APPROVE' : { confirm: null, prompt: null },
        'SHIP'    : { confirm: '⚠️ هل تؤكد شحن هذا التحويل؟\nسيتم خصم الكميات من مخزون الفرع المُرسِل فوراً!', prompt: null },
        'RECEIVE' : { confirm: '📦 هل تؤكد استلام هذا التحويل؟\nسيتم إضافة الكميات لمخزون الفرع المُستلِم فوراً!', prompt: null },
        'CANCEL'  : { confirm: null, prompt: '🚫 تأكيد إلغاء التحويل\n\nيرجى إدخال سبب الإلغاء (إلزامي):' }
    };

    var msg = messages[action];
    var reason = '';

    // تأكيد للشحن والاستلام
    if (msg.confirm && !confirm(msg.confirm)) return;

    // طلب السبب للإلغاء
    if (msg.prompt) {
        reason = prompt(msg.prompt, '');
        if (reason === null) return;
        if (!reason || reason.trim() === '') {
            apex.message.showErrors([{
                type: 'error', location: 'page',
                message: '⛔ يجب إدخال سبب الإلغاء!'
            }]);
            return;
        }
    }

    // استدعاء السيرفر
    apex.server.process('PROCESS_TRANSFER_ACTION', {
        x01: String(transferId),
        x02: action,
        x03: reason.trim()
    }, {
        dataType: 'json',
        loadingIndicator: '#transfers_reg',
        success: function(pData) {
            if (pData && pData.success) {
                apex.message.showPageSuccess(pData.message);
                // تحديث جميع المناطق المتأثرة
                ['transfers_reg','transfer_lines_reg','stock_balances_reg','inv_kpi_region']
                    .forEach(function(id) {
                        var el = document.getElementById(id);
                        if (el) $(el).trigger('apexrefresh');
                    });
            } else {
                apex.message.showErrors([{
                    type: 'error', location: 'page',
                    message: pData ? pData.message : '⛔ خطأ غير متوقع!'
                }]);
            }
        },
        error: function(xhr) {
            apex.message.showErrors([{
                type: 'error', location: 'page',
                message: '⛔ فشل الاتصال: ' + xhr.statusText
            }]);
        }
    });
};

// 3. عكس حركة الاستلام (موروث من المرحلة السابقة)
window.reverseTransaction = function(txnId, qty, itemName, variantSku) {
    var displayName = itemName + (variantSku && variantSku !== '—' ? ' / ' + variantSku : '');
    var reason = prompt(
        '⚠️ إلغاء حركة استلام\n الصنف: ' + displayName +
        '\n الكمية: ' + qty + '\n\nيرجى إدخال السبب:', ''
    );
    if (reason === null) return;
    if (!reason.trim()) {
        apex.message.showErrors([{ type:'error', location:'page', message:'⛔ السبب إلزامي!' }]);
        return;
    }
    apex.server.process('REVERSE_INV_TRANSACTION', { x01: String(txnId), x02: reason.trim() }, {
        dataType: 'json',
        success: function(pData) {
            if (pData && pData.success) {
                apex.message.showPageSuccess(pData.message);
                ['stock_receipt_reg','stock_balances_reg','inv_kpi_region'].forEach(function(id) {
                    var el = document.getElementById(id); if (el) $(el).trigger('apexrefresh');
                });
            } else {
                apex.message.showErrors([{ type:'error', location:'page', message: pData ? pData.message : 'خطأ!' }]);
            }
        }
    });
};
```

---

## 🧪 دليل الاختبار الكامل

| # | الاختبار | الخطوة | النتيجة المتوقعة |
|---|---|---|---|
| ✅ 1 | إنشاء تحويل جديد | Add Row + حدد فرعين + Save | رقم TRF-YYYYMMDD-XXXXX يتولد تلقائياً بحالة `📝 مسودة` |
| ✅ 2 | إضافة بنود للتحويل | اضغط `📋 بنود` + Add Row + أضف صنف + كمية + Save | المخزون المتاح يظهر، السطر يُحفظ بحالة `⏳ معلق` |
| ✅ 3 | اعتماد التحويل | اضغط `✅ اعتماد` | الحالة → `✅ معتمد`، زر الشحن يظهر |
| ✅ 4 | شحن التحويل | اضغط `🚚 شحن` وأكّد | الحالة → `🚚 في الطريق`، مخزون الفرع المُرسِل ينقص |
| ✅ 5 | استلام التحويل | اضغط `📦 استلام` وأكّد | الحالة → `📦 مستلَم`، مخزون الفرع المُستلِم يزيد |
| ✅ 6 | محاولة إلغاء مستلَم | اضغط `🚫 إلغاء` على تحويل مستلَم | رسالة: `⚠️ لا يمكن إلغاء تحويل مستلَم` |
| ✅ 7 | إلغاء تحويل في الطريق | اضغط `🚫 إلغاء` + أدخل السبب | الحالة → `🚫 مُلغى`، المخزون يعود للفرع المُرسِل! |
| ✅ 8 | محاولة تعديل سطر مشحون | انقر على سطر بحالة `مشحون` | السطر مقفل (IS_EDITABLE = N) ولا يمكن تعديله |
