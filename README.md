# Dragon Boat Runner 🐉🚣

اپ تیم قایق اژدها – **یک کد مشترک (Flutter) برای Android و iOS**.
هر تغییری در پوشه‌ی `lib/` بدهید، خودبه‌خود در هر دو نسخه اعمال می‌شود.

---

## ۱) چه چیزهایی در اپ هست

| خواسته | کجا در اپ |
|---|---|
| نماد اژدها + نام «Dragon Boat Runner» | آیکون اپ (`assets/icon`)، صفحه‌ی ورود |
| ورود با ایمیل **یا** شماره موبایل (کد SMS) | صفحه‌ی ورود |
| نام (اجباری)، نام خانوادگی، سن، وزن، جنسیت (اختیاری) | پروفایل (بعد از اولین ورود + منوی «بیشتر») |
| ساخت گروه با نام دلخواه + **کد یکتای ۶ حرفی** | «ساخت تیم» → سازنده = Admin |
| پیوستن با کد یا با **لینک** (Android و iPhone) | تب «تیم» → «اشتراک لینک دعوت» |
| حداکثر **۶۰ عضو** در هر گروه | هم در اپ و هم در قوانین سرور (`firestore.rules`) |
| «نفر دوم» (Co-Admin) که Admin انتخاب می‌کند | تب «تیم» → منوی کنار هر عضو |
| تمرین / مسابقه / رویداد با تاریخ و ساعت شروع | تب «تقویم» (فقط Admin و Co-Admin می‌سازند، همه می‌بینند) |
| **نوتیفیکیشن** برای همه هنگام ثبت/تغییر/حذف | Cloud Function `notifySessionChange` |
| 👍 / 👎 / ❓ برای هر جلسه | کارت هر جلسه |
| ثبت نظر تا **۱ ساعت قبل** از شروع، **لغو (👎) تا لحظه‌ی آخر** | اپ + قوانین سرور |
| انتخاب سمت پارو زدن (چپ/راست) | کارت جلسه (بعد از 👍 یا ❓) |
| Admin جای نشستن و سمت را تغییر می‌دهد → **آبی** | تب «قایق» و لیست حضور |
| تصویر قایق: تا ۱۲ نفر = **۵ ردیف + طبال + سکان‌دار**، بیشتر = **۱۰ ردیف + طبال + سکان‌دار** | تب «قایق» |
| چیدمان متعادل بر اساس وزن (چپ/راست و جلو/عقب) | دکمه‌ی «Auto-Balance» |
| ذخیره و اعمال **چیدمان پیش‌فرض** | «Als Standard speichern» / «Standard anwenden» |
| صفحه‌ی اول: عکس و نام تیم، زیر آن عکس عضو و «Hallo + نام» | تب «Start» |
| ۵ تمرین نزدیک + حضور + سمت پارو + «چه کسانی می‌آیند؟» | تب «Start» |
| فرم نظرات → ایمیل به `mohsen.khanmohammadi.electrical@gmail.com` (کاربر آدرس را نمی‌بیند) | «بیشتر» → «Feedback» |
| زمان‌گیری با GPS: 100/200/250/500/1000/2600 متر + مسافت دلخواه | تب «زمان‌گیری» در هر جلسه |
| START → «Achtung, started» → ۱ ثانیه → «Are you ready?» → ۱ ثانیه → «Go!» | صفحه‌ی زمان‌گیری |
| زمان دقیق تا **صدم ثانیه** + **بوق کشتی** در پایان مسافت | صفحه‌ی زمان‌گیری |
| حداکثر/حداقل سرعت، سرعت میانگین، زمان ۵۰۰ متر، Tempo (تعداد ضربه در دقیقه) | نتیجه |
| نقشه‌ی گوگل با مسیر رنگی (کند=قرمز، سریع=سبز) + نشانگر Max و Min | «Auf Karte zeigen» – فقط اعضای همان تیم |
| زبان Deutsch / English (با پرچم) | صفحه‌ی ورود و «بیشتر» |
| **یادآوری خودکار ۳ ساعت قبل از هر تمرین** برای کسانی که هنوز جواب نداده‌اند | Cloud Function `trainingReminder` |
| **واگذاری مدیریت** به عضو دیگر و **حذف تیم** | تب «تیم» (فقط Admin) |
| **جدول بهترین زمان‌ها** برای هر مسافت (همه / فقط مسابقه / فقط تمرین) | تب «Bestzeiten» |
| **حالت دمو**: اپ بدون Firebase با داده‌های نمونه اجرا می‌شود | خودکار، تا وقتی `flutterfire configure` اجرا نشده |

---

## ۰) فایل APK برای تست روی گوشی Android (حالت دمو)

**راه ۱ – ساخت در ابر GitHub (بدون نصب هیچ برنامه‌ای):**
1. این پوشه را در یک repository در GitHub بگذارید (یا از Claude بخواهید آن را push کند).
2. GitHub خودش در تب **Actions** اپ را می‌سازد (حدود ۱۰ دقیقه).
3. در Actions → آخرین اجرا → **Artifacts** → `DragonBoatRunner-android` را دانلود کنید و فایل `DragonBoatRunner-demo.apk` را به گوشی بدهید.

**راه ۲ – ساخت روی همین کامپیوتر:** بعد از نصب Flutter و Android Studio (بخش ۲):
```powershell
powershell -ExecutionPolicy Bypass -File .\build_test_apk.ps1
```

**نصب روی گوشی:** فایل APK را (با کابل، ایمیل یا Google Drive) به گوشی بفرستید، بازش کنید و «نصب از منابع ناشناس» را اجازه دهید.
در حالت دمو شما Admin تیم «Drachenboot Demo Team» با ۱۵ عضو نمونه هستید؛ همه‌ی صفحه‌ها، چیدمان قایق، جدول زمان‌ها و زمان‌گیری GPS واقعی کار می‌کنند. داده‌ها فقط روی همان گوشی هستند و با بستن اپ از نو شروع می‌شوند. نوتیفیکیشن، ایمیل نظرات و آپلود عکس در دمو کار نمی‌کنند. نقشه بدون کلید Google Maps خالی (خاکستری) دیده می‌شود.

## ۲) نصب ابزارها (یک‌بار)

1. **Flutter SDK** (آخرین نسخه‌ی stable): https://docs.flutter.dev/get-started/install/windows
2. **Android Studio** (برای Android SDK و شبیه‌ساز)
3. **Node.js 22**: https://nodejs.org
4. در PowerShell:
   ```powershell
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   ```
5. برای نسخه‌ی **iOS** یک **Mac با Xcode** لازم است (یا یک سرویس ابری مثل Codemagic). روی ویندوز فقط Android ساخته می‌شود.

## ۳) آماده‌سازی پروژه

در همین پوشه PowerShell را باز کنید:
```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```
این اسکریپت پوشه‌های `android/` و `ios/` را کامل می‌کند (فایل‌های تنظیم‌شده‌ی ما حفظ می‌شوند)، پکیج‌ها را دانلود و آیکون اژدها را می‌سازد.

## ۴) Firebase (سرور، ورود، دیتابیس، نوتیفیکیشن)

1. در https://console.firebase.google.com یک پروژه بسازید (مثلاً `dragon-boat-runner`).
2. پلن **Blaze** را فعال کنید (برای Cloud Functions لازم است؛ برای یک تیم ۶۰ نفره هزینه عملاً صفر است).
3. **Authentication → Sign-in method**: فعال‌سازی **Email/Password** و **Phone**.
4. **Firestore Database** بسازید، محل: **europe-west3 (Frankfurt)**.
5. **Storage** را فعال کنید.
6. در پوشه‌ی پروژه:
   ```powershell
   firebase login
   firebase use --add          # پروژه را انتخاب کنید
   flutterfire configure       # Android و iOS را انتخاب کنید
   ```
   (این دستور فایل `lib/firebase_options.dart` را می‌سازد.)

### ارسال ایمیل نظرات
یک حساب Gmail برای ارسال لازم است (می‌تواند همان حساب خودتان باشد):
Google Account → Security → 2-Step Verification → **App passwords** → یک رمز ۱۶ حرفی بسازید.
```powershell
cd functions
npm install
cd ..
firebase functions:secrets:set GMAIL_USER           # آدرس Gmail فرستنده
firebase functions:secrets:set GMAIL_APP_PASSWORD   # همان رمز ۱۶ حرفی
firebase deploy
```
`firebase deploy` قوانین امنیتی، Cloud Functions و صفحه‌ی لینک دعوت را منتشر می‌کند.

## ۵) Google Maps
در https://console.cloud.google.com (همان پروژه‌ی Firebase):
**Maps SDK for Android** و **Maps SDK for iOS** را فعال و یک **API key** بسازید، سپس جایگزین `YOUR_GOOGLE_MAPS_API_KEY` کنید در:
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/AppDelegate.swift`

## ۶) لینک دعوت
- اگر نام پروژه‌ی Firebase شما `dragon-boat-runner` نیست، `dragon-boat-runner.web.app` را با `<project-id>.web.app` جایگزین کنید در: `lib/config.dart` و `AndroidManifest.xml`.
- بعد از انتشار در فروشگاه‌ها، لینک Play Store و App Store را در `hosting/public/join.html` بگذارید.
- برای اینکه لینک **مستقیم** اپ را باز کند (بدون صفحه‌ی وسط):
  - Android: اثر انگشت SHA-256 کلید امضا (`cd android; .\gradlew signingReport` یا Play Console → App integrity) را در `hosting/public/.well-known/assetlinks.json` بگذارید.
  - iOS: Team ID اپل را به جای `APPLETEAMID` در `apple-app-site-association` بگذارید و در Xcode قابلیت **Associated Domains** با `applinks:<project-id>.web.app` اضافه کنید.
- حتی بدون این دو مرحله، لینک کار می‌کند: صفحه‌ی وب دکمه‌ی «در اپ باز کن» دارد، و اگر اپ نصب نباشد به فروشگاه می‌رود (کد هم کپی می‌شود تا بعد از نصب وارد شود).

## ۷) iOS (روی Mac)
```bash
./setup.sh            # اگر پروژه را روی Mac از نو آماده می‌کنید
open ios/Runner.xcworkspace
```
در Xcode → Runner → **Signing & Capabilities**: Team را انتخاب و این قابلیت‌ها را اضافه کنید: **Push Notifications**، **Background Modes → Remote notifications**، (اختیاری) **Associated Domains**.
- در Apple Developer یک **APNs Key (.p8)** بسازید و در Firebase → Project settings → Cloud Messaging آپلود کنید (بدون آن نوتیفیکیشن روی iPhone نمی‌آید).
- ورود با موبایل در iOS: در Firebase → Project settings → اپ iOS، مقدار **Encoded App ID** را به‌عنوان URL Scheme به `ios/Runner/Info.plist` (کنار `dragonboatrunner`) اضافه کنید.

## ۸) اجرا و ساخت
```powershell
flutter run                    # روی گوشی متصل یا شبیه‌ساز
flutter build appbundle        # Android → Google Play
flutter build ipa              # iOS → App Store (روی Mac)
```

---

## نکات و تصمیم‌ها
- **قایق:** با طبال، قایق کوچک ۱۲ جا دارد (۱۰ پاروزن + طبال + سکان‌دار) و قایق بزرگ ۲۲ جا. تا ۱۲ نفر حاضر → قایق کوچک، بیشتر → بزرگ. Admin می‌تواند دستی ۱۰/۲۰ را انتخاب کند. نفرات اضافه «ذخیره» نمایش داده می‌شوند.
- **تعادل وزن:** سنگین‌ترها در ردیف‌های وسط، چپ و راست تا حد ممکن برابر، با رعایت سمت دلخواه هر نفر. اعضای بدون وزن در آخر و بدون محاسبه جا داده می‌شوند. وزن‌ها را فقط Admin و Co-Admin می‌بینند.
- **دقت زمان:** ساعت تا صدم ثانیه نمایش می‌دهد و لحظه‌ی رسیدن به مسافت بین دو نقطه‌ی GPS درون‌یابی می‌شود؛ ولی دقت GPS گوشی حدود ۳ تا ۵ متر است، پس در مسافت‌های کوتاه (۱۰۰ متر) خطای واقعی ممکن است چند دهم ثانیه باشد.
- **Tempo** (ضربه در دقیقه) با سنسور حرکت گوشی **تخمین** زده می‌شود؛ بهترین نتیجه وقتی است که گوشی به بدن پاروزن بسته باشد.
- **Admin** (سازنده‌ی تیم) نمی‌تواند تیم را ترک کند؛ Co-Admin و اعضا می‌توانند.
- زمان نوتیفیکیشن‌ها با منطقه‌ی زمانی `Europe/Berlin` نوشته می‌شود (`functions/index.js`).
