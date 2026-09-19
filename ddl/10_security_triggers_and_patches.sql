-- ============================================================================
-- SCRIPT: 10_security_triggers_and_patches.sql
-- PROJECT: Enterprise POS & ERP (Oracle APEX App 102)
-- PURPOSE: Cumulative patch consolidating all Security, Custom Auth, 
--          Inventory Triggers, GL Journal Compound Triggers, and Schema Updates.
-- ============================================================================

-- 1. SCHEMA MODIFICATIONS
ALTER TABLE POS_USER_ORG_ACCESS MODIFY INV_ORG_ID NULL;
ALTER TABLE POS_USER_ORG_ACCESS MODIFY LEGAL_ENTITY_ID NULL;

DECLARE
    v_col NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_col FROM USER_TAB_COLUMNS 
     WHERE TABLE_NAME = 'POS_APP_USERS' AND COLUMN_NAME = 'PASSWORD_HASH';
    IF v_col = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE POS_APP_USERS ADD PASSWORD_HASH VARCHAR2(64)';
    END IF;
END;
/

UPDATE POS_APP_USERS
   SET PASSWORD_HASH = STANDARD_HASH('Welcome@123', 'SHA256')
 WHERE PASSWORD_HASH IS NULL;
COMMIT;

DECLARE
    v_col NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_col FROM USER_TAB_COLUMNS 
     WHERE TABLE_NAME = 'POS_INVENTORY_TRANSACTIONS' AND COLUMN_NAME = 'TXN_STATUS';
    IF v_col = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE POS_INVENTORY_TRANSACTIONS ADD TXN_STATUS VARCHAR2(20) DEFAULT ''POSTED''';
    END IF;

    SELECT COUNT(*) INTO v_col FROM USER_TAB_COLUMNS 
     WHERE TABLE_NAME = 'POS_INVENTORY_TRANSACTIONS' AND COLUMN_NAME = 'REVERSAL_OF_TXN_ID';
    IF v_col = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE POS_INVENTORY_TRANSACTIONS ADD REVERSAL_OF_TXN_ID NUMBER';
    END IF;

    SELECT COUNT(*) INTO v_col FROM USER_TAB_COLUMNS 
     WHERE TABLE_NAME = 'POS_STOCK_TRANSFERS' AND COLUMN_NAME = 'CANCEL_REASON';
    IF v_col = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE POS_STOCK_TRANSFERS ADD CANCEL_REASON VARCHAR2(500)';
    END IF;
END;
/

-- 2. CUSTOM AUTHENTICATION PACKAGE (POS_AUTH_PKG)
CREATE OR REPLACE PACKAGE POS_AUTH_PKG AS
    FUNCTION  AUTHENTICATE(p_username VARCHAR2, p_password VARCHAR2) RETURN BOOLEAN;
    PROCEDURE POST_AUTH;
END POS_AUTH_PKG;
/

CREATE OR REPLACE PACKAGE BODY POS_AUTH_PKG AS

    FUNCTION AUTHENTICATE(p_username VARCHAR2, p_password VARCHAR2) 
    RETURN BOOLEAN IS
        v_count  NUMBER;
        v_locked CHAR(1);
    BEGIN
        SELECT COUNT(*), MAX(NVL(ACCOUNT_LOCKED,'N'))
          INTO v_count, v_locked
          FROM POS_APP_USERS
         WHERE UPPER(APEX_USERNAME) = UPPER(p_username)
           AND PASSWORD_HASH = STANDARD_HASH(p_password, 'SHA256')
           AND IS_ACTIVE = 'Y';

        IF v_count = 1 AND v_locked = 'N' THEN
            UPDATE POS_APP_USERS
               SET FAILED_LOGIN_COUNT = 0,
                   LAST_LOGIN_DATE    = SYSDATE
             WHERE UPPER(APEX_USERNAME) = UPPER(p_username);
            COMMIT;
            RETURN TRUE;
        ELSE
            UPDATE POS_APP_USERS
               SET FAILED_LOGIN_COUNT = NVL(FAILED_LOGIN_COUNT, 0) + 1,
                   ACCOUNT_LOCKED = CASE 
                       WHEN NVL(FAILED_LOGIN_COUNT, 0) + 1 >= 5 THEN 'Y' 
                       ELSE 'N' END
             WHERE UPPER(APEX_USERNAME) = UPPER(p_username);
            COMMIT;
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN RETURN FALSE;
    END AUTHENTICATE;

    PROCEDURE POST_AUTH IS
        v_user_id   NUMBER;
        v_role      VARCHAR2(30);
        v_full_name VARCHAR2(240);
        v_le_list   VARCHAR2(4000) := '';
        v_org_list  VARCHAR2(4000) := '';
        v_is_admin  VARCHAR2(1)    := 'N';
    BEGIN
        SELECT APP_USER_ID, USER_ROLE, NVL(FULL_NAME_AR, FULL_NAME_EN)
          INTO v_user_id, v_role, v_full_name
          FROM POS_APP_USERS
         WHERE UPPER(APEX_USERNAME) = UPPER(V('APP_USER'))
           AND IS_ACTIVE = 'Y';

        IF v_role IN ('SYSADMIN', 'GENERAL_AUDITOR') THEN
            v_is_admin := 'Y'; 
            v_le_list  := 'ALL'; 
            v_org_list := 'ALL';
        ELSE
            FOR r IN (SELECT DISTINCT TO_CHAR(LEGAL_ENTITY_ID) LE_ID
                        FROM POS_USER_ORG_ACCESS
                       WHERE APP_USER_ID = v_user_id AND IS_ACTIVE = 'Y'
                         AND LEGAL_ENTITY_ID IS NOT NULL)
            LOOP 
                v_le_list := v_le_list || r.LE_ID || ','; 
            END LOOP;

            FOR r IN (SELECT DISTINCT TO_CHAR(io.INV_ORG_ID) ORG_ID
                        FROM POS_USER_ORG_ACCESS uoa
                        JOIN POS_INVENTORY_ORGS io
                          ON (uoa.INV_ORG_ID = io.INV_ORG_ID
                           OR (uoa.INV_ORG_ID IS NULL
                               AND io.ORG_UNIT_ID IN (
                                   SELECT ORG_UNIT_ID FROM POS_OPERATING_UNITS
                                    WHERE LEGAL_ENTITY_ID = uoa.LEGAL_ENTITY_ID)))
                       WHERE uoa.APP_USER_ID = v_user_id
                         AND uoa.IS_ACTIVE = 'Y' AND io.IS_ACTIVE = 'Y')
            LOOP 
                v_org_list := v_org_list || r.ORG_ID || ','; 
            END LOOP;

            v_le_list  := RTRIM(v_le_list,  ',');
            v_org_list := RTRIM(v_org_list, ',');
        END IF;

        APEX_UTIL.SET_SESSION_STATE('AI_USER_ID',   TO_CHAR(v_user_id));
        APEX_UTIL.SET_SESSION_STATE('AI_USER_ROLE', v_role);
        APEX_UTIL.SET_SESSION_STATE('AI_USER_NAME', v_full_name);
        APEX_UTIL.SET_SESSION_STATE('AI_IS_ADMIN',  v_is_admin);
        APEX_UTIL.SET_SESSION_STATE('AI_LE_LIST',   v_le_list);
        APEX_UTIL.SET_SESSION_STATE('AI_ORG_LIST',  v_org_list);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            APEX_UTIL.SET_SESSION_STATE('AI_IS_ADMIN', 'N');
            APEX_UTIL.SET_SESSION_STATE('AI_LE_LIST',  '');
            APEX_UTIL.SET_SESSION_STATE('AI_ORG_LIST', '');
    END POST_AUTH;

END POS_AUTH_PKG;
/

-- 3. SECURITY CONTEXT VIEWS
CREATE OR REPLACE VIEW POS_USER_PERMITTED_LE_V AS
SELECT le.*
  FROM POS_LEGAL_ENTITIES le
 WHERE le.IS_ACTIVE = 'Y'
   AND (
       V('AI_IS_ADMIN') = 'Y'
       OR V('AI_LE_LIST') = 'ALL'
       OR INSTR(',' || V('AI_LE_LIST') || ',',
                ',' || TO_CHAR(le.LEGAL_ENTITY_ID) || ',') > 0
   );

CREATE OR REPLACE VIEW POS_USER_PERMITTED_ORG_V AS
SELECT io.*
  FROM POS_INVENTORY_ORGS io
 WHERE io.IS_ACTIVE = 'Y'
   AND (
       V('AI_IS_ADMIN') = 'Y'
       OR V('AI_ORG_LIST') = 'ALL'
       OR INSTR(',' || V('AI_ORG_LIST') || ',',
                ',' || TO_CHAR(io.INV_ORG_ID) || ',') > 0
   );

-- 4. INVENTORY TRIGGERS
CREATE OR REPLACE TRIGGER POS_INV_TXN_BIR
BEFORE INSERT ON POS_INVENTORY_TRANSACTIONS
FOR EACH ROW
BEGIN
    IF :NEW.INV_TXN_ID IS NULL THEN
        :NEW.INV_TXN_ID := POS_INV_TXN_SEQ.NEXTVAL;
    END IF;
    IF :NEW.TXN_DATE IS NULL THEN
        :NEW.TXN_DATE := SYSDATE;
    END IF;
    IF :NEW.TXN_STATUS IS NULL THEN
        :NEW.TXN_STATUS := 'POSTED';
    END IF;
    IF :NEW.TOTAL_COST IS NULL AND :NEW.QUANTITY IS NOT NULL AND :NEW.UNIT_COST IS NOT NULL THEN
        :NEW.TOTAL_COST := ROUND(:NEW.QUANTITY * :NEW.UNIT_COST, 4);
    END IF;
    IF :NEW.CREATION_DATE IS NULL THEN
        :NEW.CREATION_DATE := SYSDATE;
    END IF;
    :NEW.LAST_UPDATE_DATE := SYSDATE;
END;
/

CREATE OR REPLACE TRIGGER POS_INV_TXN_AFTER_INSERT
AFTER INSERT ON POS_INVENTORY_TRANSACTIONS
FOR EACH ROW
DECLARE
    v_qty_change NUMBER := 0;
BEGIN
    CASE :NEW.TXN_TYPE
        WHEN 'RECEIPT'         THEN v_qty_change := :NEW.QUANTITY;
        WHEN 'RETURN'          THEN v_qty_change := :NEW.QUANTITY;
        WHEN 'TRANSFER_IN'     THEN v_qty_change := :NEW.QUANTITY;
        WHEN 'OPENING_BALANCE' THEN v_qty_change := :NEW.QUANTITY;
        WHEN 'ADJUSTMENT'      THEN v_qty_change := :NEW.QUANTITY;
        WHEN 'SALE'            THEN v_qty_change := -(:NEW.QUANTITY);
        WHEN 'TRANSFER_OUT'    THEN v_qty_change := -(:NEW.QUANTITY);
        WHEN 'WRITE_OFF'       THEN v_qty_change := -(:NEW.QUANTITY);
        ELSE v_qty_change := 0;
    END CASE;

    IF v_qty_change != 0 THEN
        MERGE INTO POS_INVENTORY_BALANCES b
        USING DUAL ON (
            b.INV_ORG_ID = :NEW.INV_ORG_ID
            AND b.SUBINV_ID = :NEW.SUBINV_ID
            AND b.ITEM_ID = :NEW.ITEM_ID
            AND NVL(b.VARIANT_ID, -1) = NVL(:NEW.VARIANT_ID, -1)
        )
        WHEN MATCHED THEN
            UPDATE SET 
                b.QUANTITY_ON_HAND = b.QUANTITY_ON_HAND + v_qty_change,
                b.LAST_UPDATE_DATE = SYSDATE,
                b.LAST_COUNT_DATE  = SYSDATE
        WHEN NOT MATCHED THEN
            INSERT (
                BALANCE_ID, INV_ORG_ID, SUBINV_ID, ITEM_ID, VARIANT_ID,
                UOM_CODE, QUANTITY_ON_HAND, QUANTITY_RESERVED,
                CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE
            ) VALUES (
                POS_INV_BALANCES_SEQ.NEXTVAL, :NEW.INV_ORG_ID, :NEW.SUBINV_ID, :NEW.ITEM_ID, :NEW.VARIANT_ID,
                :NEW.UOM_CODE, GREATEST(0, v_qty_change), 0,
                NVL(:NEW.CREATED_BY, 1), SYSDATE, NVL(:NEW.LAST_UPDATED_BY, 1), SYSDATE
            );
    END IF;
END;
/

-- 5. STOCK TRANSFER TRIGGERS
CREATE OR REPLACE TRIGGER POS_STOCK_TRANSFERS_BIR
BEFORE INSERT OR UPDATE ON POS_STOCK_TRANSFERS
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        IF :NEW.TRANSFER_ID IS NULL THEN
            :NEW.TRANSFER_ID := POS_STOCK_TRANSFERS_SEQ.NEXTVAL;
        END IF;
        IF :NEW.TRANSFER_NO IS NULL THEN
            :NEW.TRANSFER_NO := 'TRF-' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '-' || LPAD(:NEW.TRANSFER_ID, 5, '0');
        END IF;
        IF :NEW.TRANSFER_STATUS IS NULL THEN
            :NEW.TRANSFER_STATUS := 'DRAFT';
        END IF;
        IF :NEW.TRANSFER_DATE IS NULL THEN
            :NEW.TRANSFER_DATE := SYSDATE;
        END IF;
        IF :NEW.CREATION_DATE IS NULL THEN
            :NEW.CREATION_DATE := SYSDATE;
        END IF;
        :NEW.LAST_UPDATE_DATE := SYSDATE;
    END IF;
    IF UPDATING THEN
        :NEW.LAST_UPDATE_DATE := SYSDATE;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER POS_STOCK_TRF_LINES_BIR
BEFORE INSERT ON POS_STOCK_TRANSFER_LINES
FOR EACH ROW
DECLARE
    v_line NUMBER;
BEGIN
    IF :NEW.TRANSFER_LINE_ID IS NULL THEN
        :NEW.TRANSFER_LINE_ID := POS_STOCK_TRF_LINES_SEQ.NEXTVAL;
    END IF;
    IF :NEW.TRANSFER_ID IS NULL THEN
        :NEW.TRANSFER_ID := TO_NUMBER(V('P230_SELECTED_TRANSFER_ID'));
    END IF;
    IF :NEW.LINE_NO IS NULL THEN
        SELECT NVL(MAX(LINE_NO), 0) + 1 INTO v_line
          FROM POS_STOCK_TRANSFER_LINES WHERE TRANSFER_ID = :NEW.TRANSFER_ID;
        :NEW.LINE_NO := v_line;
    END IF;
    IF :NEW.LINE_STATUS IS NULL THEN
        :NEW.LINE_STATUS := 'PENDING';
    END IF;
    IF :NEW.APPROVED_QTY IS NULL THEN
        :NEW.APPROVED_QTY := :NEW.REQUESTED_QTY;
    END IF;
    IF :NEW.CREATION_DATE IS NULL THEN
        :NEW.CREATION_DATE := SYSDATE;
    END IF;
    :NEW.LAST_UPDATE_DATE := SYSDATE;
END;
/

-- 6. GL JOURNAL TRIGGERS
CREATE OR REPLACE TRIGGER POS_GL_JOURNALS_BIR
BEFORE INSERT OR UPDATE ON POS_GL_JOURNALS
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        IF :NEW.JOURNAL_ID IS NULL THEN
            :NEW.JOURNAL_ID := POS_GL_JOURNALS_SEQ.NEXTVAL;
        END IF;
        IF :NEW.JOURNAL_NO IS NULL OR :NEW.JOURNAL_NO LIKE '%--%' THEN
            :NEW.JOURNAL_NO := 'JNL-' || TO_CHAR(SYSDATE, 'YYYYMM') || '-' || LPAD(:NEW.JOURNAL_ID, 6, '0');
        END IF;
        IF :NEW.STATUS IS NULL THEN
            :NEW.STATUS := 'DRAFT';
        END IF;
        IF :NEW.CREATION_DATE IS NULL THEN
            :NEW.CREATION_DATE := SYSDATE;
        END IF;
        :NEW.LAST_UPDATE_DATE := SYSDATE;
    END IF;
    IF UPDATING THEN
        :NEW.LAST_UPDATE_DATE := SYSDATE;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER POS_GL_JOURNAL_LINES_CMP_TRG
FOR INSERT OR UPDATE OR DELETE ON POS_GL_JOURNAL_LINES
COMPOUND TRIGGER

    TYPE t_journal_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    g_journal_ids t_journal_ids;

    BEFORE EACH ROW IS
    BEGIN
        IF INSERTING THEN
            IF :NEW.JOURNAL_LINE_ID IS NULL THEN
                :NEW.JOURNAL_LINE_ID := POS_GL_JOURNAL_LINES_SEQ.NEXTVAL;
            END IF;

            IF :NEW.JOURNAL_ID IS NULL THEN
                :NEW.JOURNAL_ID := TO_NUMBER(V('P240_SELECTED_JOURNAL_ID'));
            END IF;

            IF :NEW.LINE_NO IS NULL THEN
                :NEW.LINE_NO := NVL(:NEW.JOURNAL_LINE_ID, POS_GL_JOURNAL_LINES_SEQ.NEXTVAL);
            END IF;

            IF :NEW.DEBIT_AMOUNT IS NULL THEN :NEW.DEBIT_AMOUNT := 0; END IF;
            IF :NEW.CREDIT_AMOUNT IS NULL THEN :NEW.CREDIT_AMOUNT := 0; END IF;

            IF :NEW.CREATION_DATE IS NULL THEN :NEW.CREATION_DATE := SYSDATE; END IF;
            :NEW.LAST_UPDATE_DATE := SYSDATE;
        END IF;

        IF UPDATING THEN
            :NEW.LAST_UPDATE_DATE := SYSDATE;
        END IF;
    END BEFORE EACH ROW;

    AFTER EACH ROW IS
        v_jid NUMBER;
    BEGIN
        v_jid := CASE WHEN DELETING THEN :OLD.JOURNAL_ID ELSE :NEW.JOURNAL_ID END;
        IF v_jid IS NOT NULL THEN
            g_journal_ids(g_journal_ids.COUNT + 1) := v_jid;
        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_jid NUMBER;
    BEGIN
        FOR i IN 1 .. g_journal_ids.COUNT LOOP
            v_jid := g_journal_ids(i);

            MERGE INTO POS_GL_JOURNAL_LINES dst
            USING (
                SELECT JOURNAL_LINE_ID,
                       ROW_NUMBER() OVER (ORDER BY JOURNAL_LINE_ID) AS SEQ_NO
                  FROM POS_GL_JOURNAL_LINES
                 WHERE JOURNAL_ID = v_jid
            ) src
            ON (dst.JOURNAL_LINE_ID = src.JOURNAL_LINE_ID)
            WHEN MATCHED THEN
                UPDATE SET dst.LINE_NO = src.SEQ_NO;

            UPDATE POS_GL_JOURNALS j
               SET (TOTAL_DEBIT, TOTAL_CREDIT, LAST_UPDATE_DATE) = (
                   SELECT NVL(SUM(l.DEBIT_AMOUNT), 0),
                          NVL(SUM(l.CREDIT_AMOUNT), 0),
                          SYSDATE
                     FROM POS_GL_JOURNAL_LINES l
                    WHERE l.JOURNAL_ID = v_jid
               )
             WHERE j.JOURNAL_ID = v_jid;
        END LOOP;

        g_journal_ids.DELETE;
    END AFTER STATEMENT;

END POS_GL_JOURNAL_LINES_CMP_TRG;
/
