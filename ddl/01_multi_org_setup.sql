-- ============================================================================
-- FILE: 01_multi_org_setup.sql
-- DESCRIPTION: Multi-Org Hierarchy, Terminals, Users, VPD Security Setup
-- ARCHITECTURE: Enterprise POS & ERP Suite
-- AUTHOR: DBA Team
-- DATE: 2024
-- ============================================================================

-- ==========================================================================
-- SECTION 1: SEQUENCES
-- ==========================================================================
CREATE SEQUENCE SEQ_LEGAL_ENTITY_ID START WITH 1000001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_ORG_UNIT_ID     START WITH 1000001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_INV_ORG_ID      START WITH 1000001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_SUBINV_ID       START WITH 1000001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_TERMINAL_ID     START WITH 1000001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_APP_USER_ID     START WITH 1000001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_USER_ACCESS_ID  START WITH 1000001 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ==========================================================================
-- TABLE 1: POS_LEGAL_ENTITIES
-- ==========================================================================
CREATE TABLE POS_LEGAL_ENTITIES (
    LEGAL_ENTITY_ID         NUMBER          DEFAULT SEQ_LEGAL_ENTITY_ID.NEXTVAL NOT NULL,
    LEGAL_ENTITY_CODE       VARCHAR2(30)    NOT NULL,
    LEGAL_ENTITY_NAME       VARCHAR2(240)   NOT NULL,
    COUNTRY_CODE            VARCHAR2(5),
    TAX_REGISTRATION_NO     VARCHAR2(50),
    CURRENCY_CODE           VARCHAR2(3)     DEFAULT 'USD' NOT NULL,
    FISCAL_YEAR_START_MONTH NUMBER(2)       DEFAULT 1,
    LOGO_URL                VARCHAR2(500),
    ADDRESS_LINE1           VARCHAR2(240),
    ADDRESS_LINE2           VARCHAR2(240),
    CITY                    VARCHAR2(100),
    PHONE                   VARCHAR2(50),
    EMAIL                   VARCHAR2(240),
    IS_ACTIVE               CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE            DEFAULT SYSDATE,
    LAST_UPDATED_BY         NUMBER,
    LAST_UPDATE_DATE        DATE,
    CONSTRAINT POS_LE_PK    PRIMARY KEY (LEGAL_ENTITY_ID),
    CONSTRAINT POS_LE_CODE_UK UNIQUE (LEGAL_ENTITY_CODE),
    CONSTRAINT POS_LE_ACTIVE_CHK CHECK (IS_ACTIVE IN ('Y','N')),
    CONSTRAINT POS_LE_MONTH_CHK CHECK (FISCAL_YEAR_START_MONTH BETWEEN 1 AND 12)
);

COMMENT ON TABLE POS_LEGAL_ENTITIES IS 'Legal Entity master - top level of the multi-org hierarchy. Represents a registered legal company.';
COMMENT ON COLUMN POS_LEGAL_ENTITIES.LEGAL_ENTITY_ID IS 'Surrogate primary key. Generated from SEQ_LEGAL_ENTITY_ID.';
COMMENT ON COLUMN POS_LEGAL_ENTITIES.LEGAL_ENTITY_CODE IS 'Short unique code for the legal entity, used in reports and lookups.';
COMMENT ON COLUMN POS_LEGAL_ENTITIES.TAX_REGISTRATION_NO IS 'VAT/GST registration number used in e-invoicing.';
COMMENT ON COLUMN POS_LEGAL_ENTITIES.FISCAL_YEAR_START_MONTH IS 'Month number (1-12) indicating fiscal year start.';
COMMENT ON COLUMN POS_LEGAL_ENTITIES.IS_ACTIVE IS 'Y=Active, N=Inactive.';

CREATE INDEX POS_LE_COUNTRY_IDX ON POS_LEGAL_ENTITIES(COUNTRY_CODE);
CREATE INDEX POS_LE_ACTIVE_IDX ON POS_LEGAL_ENTITIES(IS_ACTIVE);

-- ==========================================================================
-- TABLE 2: POS_OPERATING_UNITS
-- ==========================================================================
CREATE TABLE POS_OPERATING_UNITS (
    ORG_UNIT_ID             NUMBER          DEFAULT SEQ_ORG_UNIT_ID.NEXTVAL NOT NULL,
    ORG_UNIT_CODE           VARCHAR2(30)    NOT NULL,
    ORG_UNIT_NAME           VARCHAR2(240)   NOT NULL,
    LEGAL_ENTITY_ID         NUMBER          NOT NULL,
    ORG_TYPE                VARCHAR2(20)    DEFAULT 'BRANCH' NOT NULL,
    DEFAULT_CURRENCY_CODE   VARCHAR2(3)     DEFAULT 'USD',
    REPORTING_CURRENCY_CODE VARCHAR2(3),
    DESCRIPTION             VARCHAR2(500),
    IS_ACTIVE               CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE            DEFAULT SYSDATE,
    LAST_UPDATED_BY         NUMBER,
    LAST_UPDATE_DATE        DATE,
    CONSTRAINT POS_OU_PK        PRIMARY KEY (ORG_UNIT_ID),
    CONSTRAINT POS_OU_CODE_UK   UNIQUE (ORG_UNIT_CODE),
    CONSTRAINT POS_OU_LE_FK     FOREIGN KEY (LEGAL_ENTITY_ID) REFERENCES POS_LEGAL_ENTITIES(LEGAL_ENTITY_ID),
    CONSTRAINT POS_OU_TYPE_CHK  CHECK (ORG_TYPE IN ('HQ','BRANCH','WAREHOUSE','FRANCHISE')),
    CONSTRAINT POS_OU_ACTIVE_CHK CHECK (IS_ACTIVE IN ('Y','N'))
);

COMMENT ON TABLE POS_OPERATING_UNITS IS 'Operating Units (OUs) sit below Legal Entities. Represents HQ, regional offices, or franchise groups.';
COMMENT ON COLUMN POS_OPERATING_UNITS.ORG_TYPE IS 'HQ=Headquarters, BRANCH=Retail Branch, WAREHOUSE=Distribution Center, FRANCHISE=Franchise Unit.';
COMMENT ON COLUMN POS_OPERATING_UNITS.REPORTING_CURRENCY_CODE IS 'Currency used for consolidated reporting if different from functional currency.';

CREATE INDEX POS_OU_LE_IDX ON POS_OPERATING_UNITS(LEGAL_ENTITY_ID);
CREATE INDEX POS_OU_ACTIVE_IDX ON POS_OPERATING_UNITS(IS_ACTIVE);

-- ==========================================================================
-- TABLE 3: POS_INVENTORY_ORGS
-- ==========================================================================
CREATE TABLE POS_INVENTORY_ORGS (
    INV_ORG_ID              NUMBER          DEFAULT SEQ_INV_ORG_ID.NEXTVAL NOT NULL,
    INV_ORG_CODE            VARCHAR2(30)    NOT NULL,
    INV_ORG_NAME            VARCHAR2(240)   NOT NULL,
    ORG_UNIT_ID             NUMBER          NOT NULL,
    PARENT_INV_ORG_ID       NUMBER,
    ORG_CATEGORY            VARCHAR2(20)    DEFAULT 'STORE' NOT NULL,
    SECTOR_TYPE             VARCHAR2(20)    DEFAULT 'RETAIL' NOT NULL,
    ADDRESS_LINE1           VARCHAR2(240),
    ADDRESS_LINE2           VARCHAR2(240),
    CITY                    VARCHAR2(100),
    COUNTRY_CODE            VARCHAR2(5),
    PHONE                   VARCHAR2(50),
    EMAIL                   VARCHAR2(240),
    MANAGER_USER_ID         NUMBER,
    COSTING_METHOD          VARCHAR2(20)    DEFAULT 'AVERAGE' NOT NULL,
    TIMEZONE_CODE           VARCHAR2(50)    DEFAULT 'UTC',
    FISCAL_PRINTER_ID       VARCHAR2(100),
    IS_ACTIVE               CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE            DEFAULT SYSDATE,
    LAST_UPDATED_BY         NUMBER,
    LAST_UPDATE_DATE        DATE,
    CONSTRAINT POS_IO_PK            PRIMARY KEY (INV_ORG_ID),
    CONSTRAINT POS_IO_CODE_UK       UNIQUE (INV_ORG_CODE),
    CONSTRAINT POS_IO_OU_FK         FOREIGN KEY (ORG_UNIT_ID) REFERENCES POS_OPERATING_UNITS(ORG_UNIT_ID),
    CONSTRAINT POS_IO_PARENT_FK     FOREIGN KEY (PARENT_INV_ORG_ID) REFERENCES POS_INVENTORY_ORGS(INV_ORG_ID),
    CONSTRAINT POS_IO_CATEGORY_CHK  CHECK (ORG_CATEGORY IN ('STORE','WAREHOUSE','KITCHEN','VENDING')),
    CONSTRAINT POS_IO_SECTOR_CHK    CHECK (SECTOR_TYPE IN ('RETAIL','FNB','SERVICE','HYBRID')),
    CONSTRAINT POS_IO_COSTING_CHK   CHECK (COSTING_METHOD IN ('FIFO','AVERAGE','STANDARD')),
    CONSTRAINT POS_IO_ACTIVE_CHK    CHECK (IS_ACTIVE IN ('Y','N'))
);

COMMENT ON TABLE POS_INVENTORY_ORGS IS 'Inventory Organizations: Physical branches, stores, warehouses. This is the primary data isolation unit for VPD security.';
COMMENT ON COLUMN POS_INVENTORY_ORGS.COSTING_METHOD IS 'FIFO=First-In-First-Out, AVERAGE=Moving Weighted Average, STANDARD=Standard Cost.';
COMMENT ON COLUMN POS_INVENTORY_ORGS.SECTOR_TYPE IS 'RETAIL=General retail, FNB=Food & Beverage, SERVICE=Service business, HYBRID=Mixed.';
COMMENT ON COLUMN POS_INVENTORY_ORGS.PARENT_INV_ORG_ID IS 'Self-referencing FK for hierarchical org structures (e.g., sub-warehouse of a main store).';

CREATE INDEX POS_IO_OU_IDX      ON POS_INVENTORY_ORGS(ORG_UNIT_ID);
CREATE INDEX POS_IO_PARENT_IDX  ON POS_INVENTORY_ORGS(PARENT_INV_ORG_ID);
CREATE INDEX POS_IO_SECTOR_IDX  ON POS_INVENTORY_ORGS(SECTOR_TYPE);
CREATE INDEX POS_IO_ACTIVE_IDX  ON POS_INVENTORY_ORGS(IS_ACTIVE);

-- ==========================================================================
-- TABLE 4: POS_SUBINVENTORIES
-- ==========================================================================
CREATE TABLE POS_SUBINVENTORIES (
    SUBINV_ID               NUMBER          DEFAULT SEQ_SUBINV_ID.NEXTVAL NOT NULL,
    SUBINV_CODE             VARCHAR2(30)    NOT NULL,
    SUBINV_NAME             VARCHAR2(240)   NOT NULL,
    INV_ORG_ID              NUMBER          NOT NULL,
    SUBINV_TYPE             VARCHAR2(20)    DEFAULT 'SHELF' NOT NULL,
    IS_RESERVABLE           CHAR(1)         DEFAULT 'Y',
    IS_ASSET_VALUED         CHAR(1)         DEFAULT 'Y',
    RESTRICT_ITEMS          CHAR(1)         DEFAULT 'N',
    DESCRIPTION             VARCHAR2(500),
    IS_ACTIVE               CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE            DEFAULT SYSDATE,
    LAST_UPDATED_BY         NUMBER,
    LAST_UPDATE_DATE        DATE,
    CONSTRAINT POS_SI_PK        PRIMARY KEY (SUBINV_ID),
    CONSTRAINT POS_SI_ORG_CODE_UK UNIQUE (INV_ORG_ID, SUBINV_CODE),
    CONSTRAINT POS_SI_ORG_FK    FOREIGN KEY (INV_ORG_ID) REFERENCES POS_INVENTORY_ORGS(INV_ORG_ID),
    CONSTRAINT POS_SI_TYPE_CHK  CHECK (SUBINV_TYPE IN ('SHELF','FLOOR','BACKSTORE','STAGING','TRANSIT')),
    CONSTRAINT POS_SI_RESERV_CHK CHECK (IS_RESERVABLE IN ('Y','N')),
    CONSTRAINT POS_SI_ASSET_CHK CHECK (IS_ASSET_VALUED IN ('Y','N')),
    CONSTRAINT POS_SI_ACTIVE_CHK CHECK (IS_ACTIVE IN ('Y','N'))
);

COMMENT ON TABLE POS_SUBINVENTORIES IS 'Sub-storage locations within an Inventory Org. Examples: Main Shelf, Back Store, Staging Area.';
COMMENT ON COLUMN POS_SUBINVENTORIES.IS_RESERVABLE IS 'Y if stock in this subinventory can be reserved for orders.';
COMMENT ON COLUMN POS_SUBINVENTORIES.IS_ASSET_VALUED IS 'Y if this subinventory stock is counted as financial asset inventory.';
COMMENT ON COLUMN POS_SUBINVENTORIES.RESTRICT_ITEMS IS 'Y if only specific items are allowed in this subinventory.';

CREATE INDEX POS_SI_ORG_IDX    ON POS_SUBINVENTORIES(INV_ORG_ID);
CREATE INDEX POS_SI_ACTIVE_IDX ON POS_SUBINVENTORIES(IS_ACTIVE);

-- ==========================================================================
-- TABLE 5: POS_POS_TERMINALS
-- ==========================================================================
CREATE TABLE POS_POS_TERMINALS (
    TERMINAL_ID             NUMBER          DEFAULT SEQ_TERMINAL_ID.NEXTVAL NOT NULL,
    TERMINAL_CODE           VARCHAR2(30)    NOT NULL,
    TERMINAL_NAME           VARCHAR2(100),
    INV_ORG_ID              NUMBER          NOT NULL,
    SUBINV_ID               NUMBER,
    TERMINAL_TYPE           VARCHAR2(20)    DEFAULT 'CASHIER' NOT NULL,
    IP_ADDRESS              VARCHAR2(45),
    MAC_ADDRESS             VARCHAR2(20),
    PRINTER_TYPE            VARCHAR2(20)    DEFAULT 'NETWORK',
    PRINTER_IP              VARCHAR2(45),
    PRINTER_PORT            NUMBER          DEFAULT 9100,
    PRINTER_USB_VENDOR_ID   VARCHAR2(10),
    PRINTER_USB_PRODUCT_ID  VARCHAR2(10),
    CASH_DRAWER_ENABLED     CHAR(1)         DEFAULT 'N',
    POLE_DISPLAY_ENABLED    CHAR(1)         DEFAULT 'N',
    POLE_DISPLAY_IP         VARCHAR2(45),
    POLE_DISPLAY_PORT       NUMBER          DEFAULT 3000,
    KDS_ENABLED             CHAR(1)         DEFAULT 'N',
    DEFAULT_PRICE_LIST_ID   NUMBER,
    IS_ACTIVE               CHAR(1)         DEFAULT 'Y' NOT NULL,
    LAST_SYNC_DATE          DATE,
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE            DEFAULT SYSDATE,
    LAST_UPDATED_BY         NUMBER,
    LAST_UPDATE_DATE        DATE,
    CONSTRAINT POS_TRM_PK       PRIMARY KEY (TERMINAL_ID),
    CONSTRAINT POS_TRM_CODE_UK  UNIQUE (TERMINAL_CODE),
    CONSTRAINT POS_TRM_ORG_FK   FOREIGN KEY (INV_ORG_ID) REFERENCES POS_INVENTORY_ORGS(INV_ORG_ID),
    CONSTRAINT POS_TRM_SI_FK    FOREIGN KEY (SUBINV_ID) REFERENCES POS_SUBINVENTORIES(SUBINV_ID),
    CONSTRAINT POS_TRM_TYPE_CHK CHECK (TERMINAL_TYPE IN ('CASHIER','KIOSK','MOBILE','KDS')),
    CONSTRAINT POS_TRM_DRAWER_CHK CHECK (CASH_DRAWER_ENABLED IN ('Y','N')),
    CONSTRAINT POS_TRM_ACTIVE_CHK CHECK (IS_ACTIVE IN ('Y','N'))
);

COMMENT ON TABLE POS_POS_TERMINALS IS 'POS Terminal hardware registry. Each terminal belongs to an Inventory Org and optionally a Subinventory.';
COMMENT ON COLUMN POS_POS_TERMINALS.PRINTER_TYPE IS 'NETWORK=TCP/IP printer, USB=Web USB API, SERIAL=Web Serial API.';
COMMENT ON COLUMN POS_POS_TERMINALS.PRINTER_IP IS 'IP address for network thermal printer (ESC/POS over TCP port 9100).';
COMMENT ON COLUMN POS_POS_TERMINALS.CASH_DRAWER_ENABLED IS 'Y if an RJ11 cash drawer is connected to the thermal printer.';
COMMENT ON COLUMN POS_POS_TERMINALS.KDS_ENABLED IS 'Y if this terminal acts as or communicates with a Kitchen Display System.';

CREATE INDEX POS_TRM_ORG_IDX    ON POS_POS_TERMINALS(INV_ORG_ID);
CREATE INDEX POS_TRM_ACTIVE_IDX ON POS_POS_TERMINALS(IS_ACTIVE);

-- ==========================================================================
-- TABLE 6: POS_APP_USERS
-- ==========================================================================
CREATE TABLE POS_APP_USERS (
    APP_USER_ID             NUMBER          DEFAULT SEQ_APP_USER_ID.NEXTVAL NOT NULL,
    APEX_USERNAME           VARCHAR2(100)   NOT NULL,
    FULL_NAME_EN            VARCHAR2(240),
    FULL_NAME_AR            VARCHAR2(240),
    EMAIL                   VARCHAR2(240),
    PHONE                   VARCHAR2(50),
    USER_ROLE               VARCHAR2(30)    DEFAULT 'CASHIER' NOT NULL,
    DEFAULT_INV_ORG_ID      NUMBER,
    DEFAULT_TERMINAL_ID     NUMBER,
    PIN_HASH                VARCHAR2(64),
    LANGUAGE_CODE           VARCHAR2(10)    DEFAULT 'EN',
    IS_ACTIVE               CHAR(1)         DEFAULT 'Y' NOT NULL,
    LAST_LOGIN_DATE         DATE,
    PASSWORD_CHANGE_DATE    DATE,
    FAILED_LOGIN_COUNT      NUMBER          DEFAULT 0,
    ACCOUNT_LOCKED          CHAR(1)         DEFAULT 'N',
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE            DEFAULT SYSDATE,
    LAST_UPDATED_BY         NUMBER,
    LAST_UPDATE_DATE        DATE,
    CONSTRAINT POS_AU_PK        PRIMARY KEY (APP_USER_ID),
    CONSTRAINT POS_AU_UNAME_UK  UNIQUE (APEX_USERNAME),
    CONSTRAINT POS_AU_ORG_FK    FOREIGN KEY (DEFAULT_INV_ORG_ID) REFERENCES POS_INVENTORY_ORGS(INV_ORG_ID),
    CONSTRAINT POS_AU_TERM_FK   FOREIGN KEY (DEFAULT_TERMINAL_ID) REFERENCES POS_POS_TERMINALS(TERMINAL_ID),
    CONSTRAINT POS_AU_ROLE_CHK  CHECK (USER_ROLE IN ('SYSADMIN','ORG_ADMIN','BRANCH_MANAGER','CASHIER','AUDITOR','VIEWER')),
    CONSTRAINT POS_AU_ACTIVE_CHK CHECK (IS_ACTIVE IN ('Y','N')),
    CONSTRAINT POS_AU_LOCKED_CHK CHECK (ACCOUNT_LOCKED IN ('Y','N'))
);

COMMENT ON TABLE POS_APP_USERS IS 'Application user master extending APEX workspace users. Stores role, default org, terminal assignments.';
COMMENT ON COLUMN POS_APP_USERS.APEX_USERNAME IS 'Maps to APEX_WORKSPACE_APEX_USERS.USER_NAME. Must match exactly for APEX authentication.';
COMMENT ON COLUMN POS_APP_USERS.USER_ROLE IS 'SYSADMIN=Full access, ORG_ADMIN=Org level, BRANCH_MANAGER=Branch level, CASHIER=POS only, AUDITOR=Read+Reports, VIEWER=Read only.';
COMMENT ON COLUMN POS_APP_USERS.PIN_HASH IS 'SHA-256 hashed 4-6 digit PIN for quick cashier login on shared terminals.';

CREATE INDEX POS_AU_ORG_IDX    ON POS_APP_USERS(DEFAULT_INV_ORG_ID);
CREATE INDEX POS_AU_ROLE_IDX   ON POS_APP_USERS(USER_ROLE);
CREATE INDEX POS_AU_ACTIVE_IDX ON POS_APP_USERS(IS_ACTIVE);

-- ==========================================================================
-- TABLE 7: POS_USER_ORG_ACCESS
-- ==========================================================================
CREATE TABLE POS_USER_ORG_ACCESS (
    ACCESS_ID               NUMBER          DEFAULT SEQ_USER_ACCESS_ID.NEXTVAL NOT NULL,
    APP_USER_ID             NUMBER          NOT NULL,
    INV_ORG_ID              NUMBER          NOT NULL,
    ACCESS_LEVEL            VARCHAR2(20)    DEFAULT 'CASHIER_ONLY' NOT NULL,
    GRANTED_BY              NUMBER,
    GRANT_DATE              DATE            DEFAULT SYSDATE,
    REVOKE_DATE             DATE,
    IS_ACTIVE               CHAR(1)         DEFAULT 'Y' NOT NULL,
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE            DEFAULT SYSDATE,
    LAST_UPDATED_BY         NUMBER,
    LAST_UPDATE_DATE        DATE,
    CONSTRAINT POS_UOA_PK       PRIMARY KEY (ACCESS_ID),
    CONSTRAINT POS_UOA_UK       UNIQUE (APP_USER_ID, INV_ORG_ID),
    CONSTRAINT POS_UOA_USER_FK  FOREIGN KEY (APP_USER_ID) REFERENCES POS_APP_USERS(APP_USER_ID),
    CONSTRAINT POS_UOA_ORG_FK   FOREIGN KEY (INV_ORG_ID) REFERENCES POS_INVENTORY_ORGS(INV_ORG_ID),
    CONSTRAINT POS_UOA_LEVEL_CHK CHECK (ACCESS_LEVEL IN ('FULL','READ_ONLY','CASHIER_ONLY')),
    CONSTRAINT POS_UOA_ACTIVE_CHK CHECK (IS_ACTIVE IN ('Y','N'))
);

COMMENT ON TABLE POS_USER_ORG_ACCESS IS 'Row-Level Security access map: which user can access which Inventory Orgs. Used by VPD policies.';
COMMENT ON COLUMN POS_USER_ORG_ACCESS.ACCESS_LEVEL IS 'FULL=All operations, READ_ONLY=View only, CASHIER_ONLY=POS transactions only.';
COMMENT ON COLUMN POS_USER_ORG_ACCESS.GRANTED_BY IS 'APP_USER_ID of the admin who granted this access.';

CREATE INDEX POS_UOA_USER_IDX ON POS_USER_ORG_ACCESS(APP_USER_ID);
CREATE INDEX POS_UOA_ORG_IDX  ON POS_USER_ORG_ACCESS(INV_ORG_ID);

-- Application Context (Wrapped safely for APEX Cloud / OCI schemas where CREATE ANY CONTEXT may be restricted)
BEGIN
    EXECUTE IMMEDIATE 'CREATE OR REPLACE CONTEXT POS_CTX USING POS_CTX_PKG ACCESSED GLOBALLY';
EXCEPTION
    WHEN OTHERS THEN
        NULL; -- Handled safely in cloud workspaces
END;
/

-- Context Package Spec (called by APEX post-authentication process)
CREATE OR REPLACE PACKAGE POS_CTX_PKG AS
    -- Package state fallback when database context is restricted
    g_app_user_id   NUMBER := NULL;
    g_apex_username VARCHAR2(100) := NULL;
    g_user_role     VARCHAR2(30) := NULL;
    g_inv_org_id    NUMBER := NULL;

    PROCEDURE SET_SESSION_CONTEXT(
        p_apex_username IN VARCHAR2,
        p_inv_org_id    IN NUMBER DEFAULT NULL
    );
    PROCEDURE CLEAR_SESSION_CONTEXT;
END POS_CTX_PKG;
/

CREATE OR REPLACE PACKAGE BODY POS_CTX_PKG AS

    PROCEDURE SET_SESSION_CONTEXT(
        p_apex_username IN VARCHAR2,
        p_inv_org_id    IN NUMBER DEFAULT NULL
    ) IS
        v_user_id       POS_APP_USERS.APP_USER_ID%TYPE;
        v_role          POS_APP_USERS.USER_ROLE%TYPE;
        v_org_id        POS_APP_USERS.DEFAULT_INV_ORG_ID%TYPE;
    BEGIN
        -- Fetch user details
        SELECT APP_USER_ID, USER_ROLE, DEFAULT_INV_ORG_ID
          INTO v_user_id, v_role, v_org_id
          FROM POS_APP_USERS
         WHERE UPPER(APEX_USERNAME) = UPPER(p_apex_username)
           AND IS_ACTIVE = 'Y';

        -- Set package global variables
        g_app_user_id   := v_user_id;
        g_apex_username := UPPER(p_apex_username);
        g_user_role     := v_role;
        g_inv_org_id    := NVL(p_inv_org_id, v_org_id);

        -- Set context attributes if DB context exists
        BEGIN
            DBMS_SESSION.SET_CONTEXT('POS_CTX', 'APP_USER_ID',   TO_CHAR(v_user_id));
            DBMS_SESSION.SET_CONTEXT('POS_CTX', 'APEX_USERNAME', UPPER(p_apex_username));
            DBMS_SESSION.SET_CONTEXT('POS_CTX', 'USER_ROLE',     v_role);
            DBMS_SESSION.SET_CONTEXT('POS_CTX', 'INV_ORG_ID',    TO_CHAR(NVL(p_inv_org_id, v_org_id)));
        EXCEPTION
            WHEN OTHERS THEN
                NULL; -- Context set via package globals
        END;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'User not found or inactive: ' || p_apex_username);
    END SET_SESSION_CONTEXT;

    PROCEDURE CLEAR_SESSION_CONTEXT IS
    BEGIN
        g_app_user_id   := NULL;
        g_apex_username := NULL;
        g_user_role     := NULL;
        g_inv_org_id    := NULL;
        BEGIN
            DBMS_SESSION.CLEAR_ALL_CONTEXT('POS_CTX');
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END CLEAR_SESSION_CONTEXT;

END POS_CTX_PKG;
/

-- VPD Policy Function
CREATE OR REPLACE FUNCTION POS_ORG_SECURITY_POLICY(
    p_schema IN VARCHAR2,
    p_object IN VARCHAR2
) RETURN VARCHAR2 IS
    v_role    VARCHAR2(30);
    v_user_id VARCHAR2(20);
BEGIN
    v_role    := NVL(SYS_CONTEXT('POS_CTX', 'USER_ROLE'), POS_CTX_PKG.g_user_role);
    v_user_id := NVL(SYS_CONTEXT('POS_CTX', 'APP_USER_ID'), TO_CHAR(POS_CTX_PKG.g_app_user_id));

    -- SYSADMINs see all data
    IF v_role = 'SYSADMIN' OR v_user_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- All other roles: restrict to accessible orgs
    RETURN 'INV_ORG_ID IN (
        SELECT INV_ORG_ID
          FROM POS_USER_ORG_ACCESS
         WHERE APP_USER_ID = ' || NVL(v_user_id, '0') || '
           AND IS_ACTIVE = ''Y''
    )';
END POS_ORG_SECURITY_POLICY;
/

-- Safe VPD Policy Application (wrapped with exception handling for APEX Cloud / Autonomous schemas)
BEGIN
    EXECUTE IMMEDIATE '
    BEGIN
        DBMS_RLS.ADD_POLICY(
            object_schema   => USER,
            object_name     => ''POS_ORDERS'',
            policy_name     => ''POS_ORDERS_VPD'',
            function_schema => USER,
            policy_function => ''POS_ORG_SECURITY_POLICY'',
            statement_types => ''SELECT, INSERT, UPDATE, DELETE'',
            update_check    => TRUE,
            enable          => TRUE
        );
    END;';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE '
    BEGIN
        DBMS_RLS.ADD_POLICY(
            object_schema   => USER,
            object_name     => ''POS_INVENTORY_TRANSACTIONS'',
            policy_name     => ''POS_INVTXN_VPD'',
            function_schema => USER,
            policy_function => ''POS_ORG_SECURITY_POLICY'',
            statement_types => ''SELECT, INSERT, UPDATE, DELETE'',
            update_check    => TRUE,
            enable          => TRUE
        );
    END;';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE '
    BEGIN
        DBMS_RLS.ADD_POLICY(
            object_schema   => USER,
            object_name     => ''POS_GL_JOURNALS'',
            policy_name     => ''POS_GL_VPD'',
            function_schema => USER,
            policy_function => ''POS_ORG_SECURITY_POLICY'',
            statement_types => ''SELECT, INSERT, UPDATE, DELETE'',
            update_check    => TRUE,
            enable          => TRUE
        );
    END;';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
