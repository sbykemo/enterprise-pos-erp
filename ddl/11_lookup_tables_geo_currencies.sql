-- ==============================================================================
-- FILE: 11_lookup_tables_geo_currencies.sql
-- DESCRIPTION: Master Reference Lookup Tables for Countries, Currencies & Cities
-- ARCHITECTURE: Enterprise POS & ERP Suite (TCA / Geographic Hierarchy)
-- SCHEMA: POS (Oracle 12c+ / Autonomous Database)
-- ==============================================================================

-- 1. جدول العملات المرجعي (Currencies Master)
CREATE TABLE POS_CURRENCIES (
    CURRENCY_CODE       VARCHAR2(5)   PRIMARY KEY,
    CURRENCY_NAME_AR    VARCHAR2(100) NOT NULL,
    CURRENCY_NAME_EN    VARCHAR2(100) NOT NULL,
    CURRENCY_SYMBOL     VARCHAR2(10),
    DECIMAL_PLACES      NUMBER(1)     DEFAULT 2 NOT NULL,
    IS_ACTIVE           CHAR(1)       DEFAULT 'Y' NOT NULL CHECK (IS_ACTIVE IN ('Y','N'))
);

COMMENT ON TABLE POS_CURRENCIES IS 'سجل العملات الرسمي المعتمد في النظام مع ضبط الخانات العشرية ورموز العملات';

-- 2. جدول الدول المرجعي (Countries Master - ISO 3166-1)
CREATE TABLE POS_COUNTRIES (
    COUNTRY_CODE        VARCHAR2(5)   PRIMARY KEY,
    COUNTRY_NAME_AR     VARCHAR2(100) NOT NULL,
    COUNTRY_NAME_EN     VARCHAR2(100) NOT NULL,
    PHONE_PREFIX        VARCHAR2(10),
    DEFAULT_CURRENCY    VARCHAR2(5)   REFERENCES POS_CURRENCIES(CURRENCY_CODE),
    IS_ACTIVE           CHAR(1)       DEFAULT 'Y' NOT NULL CHECK (IS_ACTIVE IN ('Y','N'))
);

COMMENT ON TABLE POS_COUNTRIES IS 'سجل الدول الرسمي المعتمد وفق معيار ISO 3166-1 Alpha-2';

-- 3. جدول المدن المرجعي (Cities Master with Country FK)
CREATE TABLE POS_CITIES (
    CITY_CODE           VARCHAR2(10)  PRIMARY KEY,
    COUNTRY_CODE        VARCHAR2(5)   NOT NULL REFERENCES POS_COUNTRIES(COUNTRY_CODE),
    CITY_NAME_AR        VARCHAR2(100) NOT NULL,
    CITY_NAME_EN        VARCHAR2(100) NOT NULL,
    SORT_ORDER          NUMBER(4)     DEFAULT 10,
    IS_ACTIVE           CHAR(1)       DEFAULT 'Y' NOT NULL CHECK (IS_ACTIVE IN ('Y','N'))
);

COMMENT ON TABLE POS_CITIES IS 'سجل المدن الجغرافي المعتمد لكل دولة لتفادي أخطاء الإدخال وضمان دقة تقارير الفروع والعملاء';
CREATE INDEX POS_CITIES_COUNTRY_IDX ON POS_CITIES(COUNTRY_CODE);

-- ==============================================================================
-- SEED DATA: تغذية العملات الأساسية
-- ==============================================================================
INSERT INTO POS_CURRENCIES VALUES ('SAR', 'ريال سعودي', 'Saudi Riyal', '﷼', 2, 'Y');
INSERT INTO POS_CURRENCIES VALUES ('EGP', 'جنيه مصري', 'Egyptian Pound', 'ج.م', 2, 'Y');
INSERT INTO POS_CURRENCIES VALUES ('AED', 'درهم إماراتي', 'UAE Dirham', 'د.إ', 2, 'Y');
INSERT INTO POS_CURRENCIES VALUES ('KWD', 'دينار كويتي', 'Kuwaiti Dinar', 'د.ك', 3, 'Y');
INSERT INTO POS_CURRENCIES VALUES ('BHD', 'دينار بحريني', 'Bahraini Dinar', 'د.ب', 3, 'Y');
INSERT INTO POS_CURRENCIES VALUES ('OMR', 'ريال عماني', 'Omani Rial', 'ر.ع', 3, 'Y');
INSERT INTO POS_CURRENCIES VALUES ('QAR', 'ريال قطري', 'Qatari Riyal', 'ر.ق', 2, 'Y');
INSERT INTO POS_CURRENCIES VALUES ('JOD', 'دينار أردني', 'Jordanian Dinar', 'د.أ', 3, 'Y');
INSERT INTO POS_CURRENCIES VALUES ('USD', 'دولار أمريكي', 'US Dollar', '$', 2, 'Y');
INSERT INTO POS_CURRENCIES VALUES ('EUR', 'يورو', 'Euro', '€', 2, 'Y');
INSERT INTO POS_CURRENCIES VALUES ('GBP', 'جنيه إسترليني', 'British Pound', '£', 2, 'Y');

-- ==============================================================================
-- SEED DATA: تغذية الدول
-- ==============================================================================
INSERT INTO POS_COUNTRIES VALUES ('SA', 'المملكة العربية السعودية', 'Saudi Arabia', '+966', 'SAR', 'Y');
INSERT INTO POS_COUNTRIES VALUES ('EG', 'جمهورية مصر العربية', 'Egypt', '+20', 'EGP', 'Y');
INSERT INTO POS_COUNTRIES VALUES ('AE', 'الإمارات العربية المتحدة', 'United Arab Emirates', '+971', 'AED', 'Y');
INSERT INTO POS_COUNTRIES VALUES ('KW', 'دولة الكويت', 'Kuwait', '+965', 'KWD', 'Y');
INSERT INTO POS_COUNTRIES VALUES ('BH', 'مملكة البحرين', 'Bahrain', '+973', 'BHD', 'Y');
INSERT INTO POS_COUNTRIES VALUES ('OM', 'سلطنة عمان', 'Oman', '+968', 'OMR', 'Y');
INSERT INTO POS_COUNTRIES VALUES ('QA', 'دولة قطر', 'Qatar', '+974', 'QAR', 'Y');
INSERT INTO POS_COUNTRIES VALUES ('JO', 'المملكة الأردنية الهاشمية', 'Jordan', '+962', 'JOD', 'Y');
INSERT INTO POS_COUNTRIES VALUES ('US', 'الولايات المتحدة الأمريكية', 'United States', '+1', 'USD', 'Y');
INSERT INTO POS_COUNTRIES VALUES ('GB', 'المملكة المتحدة', 'United Kingdom', '+44', 'GBP', 'Y');

-- ==============================================================================
-- SEED DATA: تغذية أهم المدن (Cities)
-- ==============================================================================

-- مدن المملكة العربية السعودية (SA)
INSERT INTO POS_CITIES VALUES ('SA-RUH', 'SA', 'الرياض', 'Riyadh', 1, 'Y');
INSERT INTO POS_CITIES VALUES ('SA-JED', 'SA', 'جدة', 'Jeddah', 2, 'Y');
INSERT INTO POS_CITIES VALUES ('SA-MAK', 'SA', 'مكة المكرمة', 'Makkah', 3, 'Y');
INSERT INTO POS_CITIES VALUES ('SA-MED', 'SA', 'المدينة المنورة', 'Madinah', 4, 'Y');
INSERT INTO POS_CITIES VALUES ('SA-DMM', 'SA', 'الدمام', 'Dammam', 5, 'Y');
INSERT INTO POS_CITIES VALUES ('SA-KHB', 'SA', 'الخبر', 'Khobar', 6, 'Y');
INSERT INTO POS_CITIES VALUES ('SA-JBL', 'SA', 'الجبيل', 'Jubail', 7, 'Y');
INSERT INTO POS_CITIES VALUES ('SA-HOF', 'SA', 'الأحساء / الهفوف', 'Al-Ahsa', 8, 'Y');
INSERT INTO POS_CITIES VALUES ('SA-ELQ', 'SA', 'القصيم / بريدة', 'Buraidah', 9, 'Y');
INSERT INTO POS_CITIES VALUES ('SA-TIF', 'SA', 'الطائف', 'Taif', 10, 'Y');
INSERT INTO POS_CITIES VALUES ('SA-TUU', 'SA', 'تبوك', 'Tabuk', 11, 'Y');
INSERT INTO POS_CITIES VALUES ('SA-AHB', 'SA', 'أبها / عسير', 'Abha', 12, 'Y');
INSERT INTO POS_CITIES VALUES ('SA-KHM', 'SA', 'خميس مشيط', 'Khamis Mushait', 13, 'Y');
INSERT INTO POS_CITIES VALUES ('SA-HAS', 'SA', 'حائل', 'Hail', 14, 'Y');
INSERT INTO POS_CITIES VALUES ('SA-GIZ', 'SA', 'جازان', 'Jazan', 15, 'Y');
INSERT INTO POS_CITIES VALUES ('SA-NJR', 'SA', 'نجران', 'Najran', 16, 'Y');
INSERT INTO POS_CITIES VALUES ('SA-YAN', 'SA', 'ينبع', 'Yanbu', 17, 'Y');

-- مدن جمهورية مصر العربية (EG)
INSERT INTO POS_CITIES VALUES ('EG-CAI', 'EG', 'القاهرة', 'Cairo', 1, 'Y');
INSERT INTO POS_CITIES VALUES ('EG-GIZ', 'EG', 'الجيزة', 'Giza', 2, 'Y');
INSERT INTO POS_CITIES VALUES ('EG-ALY', 'EG', 'الإسكندرية', 'Alexandria', 3, 'Y');
INSERT INTO POS_CITIES VALUES ('EG-MNS', 'EG', 'المنصورة', 'Mansoura', 4, 'Y');
INSERT INTO POS_CITIES VALUES ('EG-TTA', 'EG', 'طنطا', 'Tanta', 5, 'Y');
INSERT INTO POS_CITIES VALUES ('EG-PSD', 'EG', 'بورسعيد', 'Port Said', 6, 'Y');
INSERT INTO POS_CITIES VALUES ('EG-ISU', 'EG', 'الإسماعيلية', 'Ismailia', 7, 'Y');
INSERT INTO POS_CITIES VALUES ('EG-SUZ', 'EG', 'السويس', 'Suez', 8, 'Y');
INSERT INTO POS_CITIES VALUES ('EG-ZAG', 'EG', 'الزقازيق', 'Zagazig', 9, 'Y');
INSERT INTO POS_CITIES VALUES ('EG-DAM', 'EG', 'دمياط', 'Damietta', 10, 'Y');
INSERT INTO POS_CITIES VALUES ('EG-ATZ', 'EG', 'أسيوط', 'Assiut', 11, 'Y');
INSERT INTO POS_CITIES VALUES ('EG-SOF', 'EG', 'سوهاج', 'Sohag', 12, 'Y');
INSERT INTO POS_CITIES VALUES ('EG-LXR', 'EG', 'الأقصر', 'Luxor', 13, 'Y');
INSERT INTO POS_CITIES VALUES ('EG-ASW', 'EG', 'أسوان', 'Aswan', 14, 'Y');
INSERT INTO POS_CITIES VALUES ('EG-HRG', 'EG', 'الغردقة', 'Hurghada', 15, 'Y');
INSERT INTO POS_CITIES VALUES ('EG-SSH', 'EG', 'شرم الشيخ', 'Sharm El Sheikh', 16, 'Y');

-- مدن الإمارات العربية المتحدة (AE)
INSERT INTO POS_CITIES VALUES ('AE-DXB', 'AE', 'دبي', 'Dubai', 1, 'Y');
INSERT INTO POS_CITIES VALUES ('AE-AUH', 'AE', 'أبوظبي', 'Abu Dhabi', 2, 'Y');
INSERT INTO POS_CITIES VALUES ('AE-SHJ', 'AE', 'الشارقة', 'Sharjah', 3, 'Y');
INSERT INTO POS_CITIES VALUES ('AE-AJM', 'AE', 'عجمان', 'Ajman', 4, 'Y');
INSERT INTO POS_CITIES VALUES ('AE-RAK', 'AE', 'رأس الخيمة', 'Ras Al Khaimah', 5, 'Y');
INSERT INTO POS_CITIES VALUES ('AE-FJR', 'AE', 'الفجيرة', 'Fujairah', 6, 'Y');
INSERT INTO POS_CITIES VALUES ('AE-AAN', 'AE', 'العين', 'Al Ain', 7, 'Y');

-- مدن دولة الكويت (KW)
INSERT INTO POS_CITIES VALUES ('KW-KWI', 'KW', 'مدينة الكويت', 'Kuwait City', 1, 'Y');
INSERT INTO POS_CITIES VALUES ('KW-HWL', 'KW', 'حولي', 'Hawalli', 2, 'Y');
INSERT INTO POS_CITIES VALUES ('KW-FRW', 'KW', 'الفروانية', 'Farwaniya', 3, 'Y');
INSERT INTO POS_CITIES VALUES ('KW-AHM', 'KW', 'الأحمدي', 'Al Ahmadi', 4, 'Y');
INSERT INTO POS_CITIES VALUES ('KW-JHR', 'KW', 'الجهراء', 'Al Jahra', 5, 'Y');

-- مدن مملكة البحرين (BH)
INSERT INTO POS_CITIES VALUES ('BH-MNM', 'BH', 'المنامة', 'Manama', 1, 'Y');
INSERT INTO POS_CITIES VALUES ('BH-MHR', 'BH', 'المحرق', 'Muharraq', 2, 'Y');
INSERT INTO POS_CITIES VALUES ('BH-RIF', 'BH', 'الرفاع', 'Riffa', 3, 'Y');

-- مدن سلطنة عمان (OM)
INSERT INTO POS_CITIES VALUES ('OM-MCT', 'OM', 'مسقط', 'Muscat', 1, 'Y');
INSERT INTO POS_CITIES VALUES ('OM-SLL', 'OM', 'صلالة', 'Salalah', 2, 'Y');
INSERT INTO POS_CITIES VALUES ('OM-OHS', 'OM', 'صحار', 'Sohar', 3, 'Y');

-- مدن دولة قطر (QA)
INSERT INTO POS_CITIES VALUES ('QA-DOH', 'QA', 'الدوحة', 'Doha', 1, 'Y');
INSERT INTO POS_CITIES VALUES ('QA-RYN', 'QA', 'الريان', 'Al Rayyan', 2, 'Y');
INSERT INTO POS_CITIES VALUES ('QA-WKR', 'QA', 'الوكرة', 'Al Wakrah', 3, 'Y');

-- مدن المملكة الأردنية الهاشمية (JO)
INSERT INTO POS_CITIES VALUES ('JO-AMM', 'JO', 'عمّان', 'Amman', 1, 'Y');
INSERT INTO POS_CITIES VALUES ('JO-IRB', 'JO', 'إربد', 'Irbid', 2, 'Y');
INSERT INTO POS_CITIES VALUES ('JO-ZAR', 'JO', 'الزرقاء', 'Zarqa', 3, 'Y');
INSERT INTO POS_CITIES VALUES ('JO-AQB', 'JO', 'العقبة', 'Aqaba', 4, 'Y');

COMMIT;
