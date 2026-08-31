-- ==============================================================================
-- POS_CLEANUP_ALL.sql
-- Description: Complete Teardown & Drop Script for Enterprise POS & ERP Suite
-- Safe for: Oracle APEX (OCI Cloud) / SQL Workshop / Autonomous DB / Oracle 19c
-- ==============================================================================

SET DEFINE OFF;

PROMPT ============================================================
PROMPT  Starting Complete Teardown of POS & ERP Database Objects...
PROMPT ============================================================

-- 1. DROP ALL PACKAGES
BEGIN
    FOR r IN (
        SELECT OBJECT_NAME 
        FROM USER_OBJECTS 
        WHERE OBJECT_TYPE = 'PACKAGE' 
          AND (OBJECT_NAME LIKE 'PKG_%' OR OBJECT_NAME LIKE 'POS_%')
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP PACKAGE ' || r.OBJECT_NAME;
            DBMS_OUTPUT.PUT_LINE('Dropped Package: ' || r.OBJECT_NAME);
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END LOOP;
END;
/

-- 2. DROP ALL POLICIES & CONTEXTS
BEGIN
    FOR r IN (
        SELECT OBJECT_NAME, POLICY_NAME 
        FROM USER_POLICIES 
        WHERE OBJECT_NAME LIKE 'POS_%'
    ) LOOP
        BEGIN
            DBMS_RLS.DROP_POLICY(
                object_schema => USER,
                object_name   => r.OBJECT_NAME,
                policy_name   => r.POLICY_NAME
            );
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP FUNCTION POS_ORG_SECURITY_POLICY';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP CONTEXT POS_CTX';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

-- 3. DROP ALL POS TABLES (CASCADE CONSTRAINTS)
BEGIN
    FOR r IN (
        SELECT TABLE_NAME 
        FROM USER_TABLES 
        WHERE TABLE_NAME LIKE 'POS_%'
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || r.TABLE_NAME || ' CASCADE CONSTRAINTS PURGE';
            DBMS_OUTPUT.PUT_LINE('Dropped Table: ' || r.TABLE_NAME);
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END LOOP;
END;
/

-- 4. DROP ALL POS SEQUENCES
BEGIN
    FOR r IN (
        SELECT SEQUENCE_NAME 
        FROM USER_SEQUENCES 
        WHERE SEQUENCE_NAME LIKE 'POS_%' OR SEQUENCE_NAME LIKE 'SEQ_%'
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP SEQUENCE ' || r.SEQUENCE_NAME;
            DBMS_OUTPUT.PUT_LINE('Dropped Sequence: ' || r.SEQUENCE_NAME);
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END LOOP;
END;
/

-- 5. DROP ALL VIEWS & SYNONYMS
BEGIN
    FOR r IN (
        SELECT OBJECT_NAME, OBJECT_TYPE 
        FROM USER_OBJECTS 
        WHERE OBJECT_TYPE IN ('VIEW', 'SYNONYM') 
          AND OBJECT_NAME LIKE 'POS_%'
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP ' || r.OBJECT_TYPE || ' ' || r.OBJECT_NAME;
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END LOOP;
END;
/

COMMIT;

PROMPT ============================================================
PROMPT  Cleanup Complete! All POS Database Objects have been removed.
PROMPT ============================================================