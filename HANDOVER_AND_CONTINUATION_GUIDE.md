# 🏢 Enterprise POS & ERP — دليل التسليم واستئناف العمل على أي جهاز آخر
## Project Continuation & Handover Guide (Application 102)

---

## 🌟 1. نظرة عامة ورابط البيئة السحابية (OCI Autonomous Database)

قاعدة البيانات وتطبيق Oracle APEX كلاهما مستضافان على **سحابة أوراكل (Oracle Cloud Infrastructure - OCI Autonomous Database)**، مما يعني:
> **أنت لست بحاجة لنقل قاعدة البيانات أو تثبيت Oracle محلياً على جهازك الثاني!**
> كل البيانات والـ Packages والـ Triggers وشاشات APEX تعمل وتُحفظ مركزياً على السحابة مباشرة.

* **رابط APEX Workspace:**
  `https://ga06096b0992795-adminkemo.adb.us-ashburn-1.oraclecloudapps.com/ords`
* **Workspace Name:** `dev`
* **App ID:** `102` (Enterprise POS)
* **Database Schema:** `POS`
* **GitHub Repository:**
  `https://github.com/sbykemo/enterprise-pos-erp.git`

---

## 🚀 2. كيف تفتح المشروع وتكمل على جهازك الثاني؟

### أ) على مستوى الكود المصدري (Git):
1. في الجهاز الثاني، افتح الـ Terminal أو VS Code في المكان المطلوب، وشغّل:
   ```bash
   git clone https://github.com/sbykemo/enterprise-pos-erp.git
   cd enterprise-pos-erp
   ```
   (إذا كان المشروع منسوخاً بالفعل من قبل، فقط اكتب: `git pull origin main`).
2. ستجد كل مجلدات الـ DDL، والـ Packages المحدثة، ووثائق جميع الشاشات في مجلد `docs/`.

### ب) على مستوى Oracle APEX و OCI:
1. افتح المتصفح على جهازك الثاني وادخل على الرابط:
   `https://ga06096b0992795-adminkemo.adb.us-ashburn-1.oraclecloudapps.com/ords`
2. سجّل الدخول إلى Workspace: `dev`.
3. افتح **Application 102** لتجد كل الشاشات موجودة تماماً كما تركتها هنا!

---

## 📊 3. حالة شاشات النظام المنجزة (System Status)

| رقم الصفحة | اسم الصفحة | الحالة | ما تم إنجازه بالتفصيل |
|---|---|---|---|
| **Page 100** | Cashier POS Terminal | **100% مكتملة** | شاشة بيع بالباركود، سلة مشتريات ديناميكية، أزرار دفع نقدية وشبكة، شريط التحكم بالوردية في الأعلى، ونافذة إغلاق الوردية وجرد النقدية. |
| **Page 101** | Split Tender Modal | **100% مكتملة** | نافذة تقسيم الدفع بين الكاش والبطاقات المتعددة مع حساب المتبقي والفكة. |
| **Page 200** | Executive Dashboard | **100% مكتملة** | لوحة مؤشرات الأداء الحية للمبيعات والمخزون والورديات. |
| **Page 210** | Item Master & Variants | **100% مكتملة** | شجرة الأصناف والمتغيرات (Sizes, Colors, Barcodes) وإدارتها الكاملة. |
| **Page 220** | Pricing & Promotions | **100% مكتملة** | قوائم الأسعار المتعددة الفروع والخصومات والعروض الترويجية. |
| **Page 230** | Inventory Management | **100% مكتملة** | إدارة الأرصدة، شاشات استلام البضاعة (Insert Only + Reverse)، وتحويلات البضاعة بين الفروع (DRAFT -> APPROVED -> SHIPPED -> RECEIVED) وقفل السطور تلقائياً. |
| **Page 240** | GL Journals & Financials | **100% مكتملة** | دليل الحسابات الشجري (COA)، قيود اليومية، شاشة بنود القيد، الترحيل المحاسبي (POST)، والقيود العكسية (REVERSE) مع Compound Triggers للتوازن. |
| **Page 250** | Shift Audit & Z-Report | **100% مكتملة** | سجل مراجعة الورديات، تدقيق النقدية والعجز والزيادة، حركات النقدية التفصيلية، قسيمة Z-Report الحرارية مع CSS مخصص للطباعة فقط دون الصفحة، وخاصية إعادة فتح الوردية للمدير. |
| **Core Security** | Multi-Tenancy Matrix | **100% مكتملة** | منظومة العزل الأمني التلقائي على مستوى الشركة (`POS_USER_PERMITTED_LE_V`) والفرع (`POS_USER_PERMITTED_ORG_V`)، ومصادقة مخصصة من جدول `POS_APP_USERS` عبر `POS_AUTH_PKG`. |
| **Page 300** | Users & Access Control | **جاهزة للتطبيق في APEX** | موثقة بالكامل في `docs/page300_users_access_guide.md` (إدارة مستخدمي النظام والصلاحيات والفروع المقترنة). |
| **Page 310** | Org Setup & Hierarchy | **جاهزة للتطبيق في APEX** | موثقة بالكامل في `docs/page310_org_setup_guide.md` (الكيانات القانونية، وحدات التشغيل، الفروع، والمخازن ونقاط البيع). |
| **Page 320** | Customers (CRM) | **جاهزة للتطبيق في APEX** | موثقة بالكامل في `docs/page320_customers_guide.md` (بيانات العملاء والحدود الائتمانية والمديونيات). |
| **Page 330** | Suppliers & Purchase Orders | **جاهزة للتطبيق في APEX** | موثقة بالكامل في `docs/page330_suppliers_guide.md` (إدارة الموردين وأوامر الشراء وبنودها). |
| **Page 340** | Accounts Receivable (AR) | **جاهزة للتطبيق في APEX** | موثقة بالكامل في `docs/page340_ar_guide.md` (فواتير وسندات قبض وتطبيقات الذمم المدينة وتقارير الأعمار). |
| **Page 350** | Accounts Payable (AP) | **جاهزة للتطبيق في APEX** | موثقة بالكامل في `docs/page350_ap_guide.md` (فواتير الموردين وسندات الصرف والمطابقة الثلاثية 3-Way Match). |
| **Page 360** | Chart of Accounts & Periods | **جاهزة للتطبيق في APEX** | موثقة بالكامل في `docs/page360_coa_periods_guide.md` (شجرة دليل الحسابات وتصنيفات Segments والفترات المالية وإغلاقها). |
| **Page 370** | SLA Accounting Rules | **جاهزة للتطبيق في APEX** | موثقة بالكامل في `docs/page370_sla_rules_guide.md` (قواعد الترحيل الآلي للقيود المحاسبية بحسب العمليات والمصادر). |
| **Page 380** | Tax Engine Configuration | **جاهزة للتطبيق في APEX** | موثقة بالكامل في `docs/page380_tax_config_guide.md` (الأنظمة الضريبية والنسب وقواعد الاحتساب والإعفاءات). |
| **Page 390** | Cycle Count & Physical Audit | **جاهزة للتطبيق في APEX** | موثقة بالكامل في `docs/page390_cycle_count_guide.md` (أوامر الجرد الفعلي ومطابقة الفروقات واحتسابها آلياً). |
| **Page 400** | Loyalty Programs & Points | **جاهزة للتطبيق في APEX** | موثقة بالكامل في `docs/page400_loyalty_guide.md` (برامج الولاء وحسابات النقاط وحركات الاكتساب والاستبدال). |
| **Page 410** | Promotions & Coupons Builder | **جاهزة للتطبيق في APEX** | موثقة بالكامل في `docs/page410_promotions_guide.md` (العروض الترويجية BXGY والخصومات والكوبونات). |
| **Page 420 & 430** | System Settings & Audit Trail | **جاهزة للتطبيق في APEX** | موثقة بالكامل في `docs/page420_430_settings_audit_guide.md` (إعدادات النظام العامة وقوالب الطباعة وسجل التدقيق وطابور المزامنة). |

---

## 🗄️ 4. أهم الباكدجات والتريجرات في قاعدة البيانات

1. **`PKG_POS_CORE`** (`packages/PKG_POS_CORE.pks` & `.pkb`):
   - يحتوي على المحرك الكامل للمبيعات وحساب الضرائب والخصومات والمدفوعات.
   - يحتوي على دالة `GET_ITEM_PRICE` المحصنة التي تمنع أي خطأ سعري (Fallback Hierarchy).
   - يحتوي على إجراءات إدارة الورديات: `OPEN_SHIFT`, `RECORD_CASH_MOVEMENT`, `CLOSE_SHIFT`, و `REOPEN_SHIFT`.
2. **`POS_AUTH_PKG`** (`ddl/10_security_triggers_and_patches.sql`):
   - يتولى التحقق من المستخدم في `POS_APP_USERS` وملء الـ Application Items (`AI_USER_ID`, `AI_LE_LIST`, `AI_ORG_LIST`).
3. **`POS_INV_TXN_AFTER_INSERT`**:
   - يحدّث أرصدة المخزون تلقائياً بعد كل حركة (RECEIPT, TRANSFER_IN, SALE, TRANSFER_OUT...).
4. **`POS_GL_JOURNAL_LINES_CMP_TRG`**:
   - Compound Trigger ذكي يحدث إجمالي المدين والدائن في رأس القيد ويضبط تسلسل أرقام السطور ويمنع أخطاء Mutating Table نهائياً.

---

## 💬 5. رسالة موجهة للذكاء الاصطناعي (AI Prompt) عند فتح محادثة جديدة على الجهاز الثاني:

انسخ النص التالي وضعه للـ AI في المحادثة الجديدة إذا أردت متابعة العمل:

```text
أنا أعمل على مشروع Enterprise POS & ERP المبني على Oracle APEX 26.1 و OCI Autonomous Database.
المشروع متصل بمستودع GitHub الحالي، وقاعدة البيانات السحابية Schema = POS و Application ID = 102.
جميع الشاشات الأساسية (Page 100, 101, 200, 210, 220, 230, 240, 250) ومنظومة الصلاحيات والـ Packages (PKG_POS_CORE) مكتملة وموثقة بالكامل في ملف HANDOVER_AND_CONTINUATION_GUIDE.md ومجلد docs/.
يرجى قراءة الملفات والاستعداد لإكمال أي متطلبات أو ميزات جديدة أطلبها منك مع الحفاظ على نفس المعايير الاحترافية المطبقة.
```
