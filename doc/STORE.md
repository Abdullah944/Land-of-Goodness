# Land of Goodness — Store sheet

Written 2026-11-11, updated 2026-11-14. This text is filled into App Store Connect for the owner to read; nothing is submitted to Apple without the owner's yes.

## App facts

| Field | Value |
| --- | --- |
| Bundle ID | `com.abdullah.landofkhair` |
| Version | 1.0.0 (build 11 submitted for review on 2026-11-14; raise the build number for every upload) |
| Team | NBCQF98255 |
| Lowest iOS | 15.0 |
| Screen | Landscape, iPhone only (archive with TARGETED_DEVICE_FAMILY=1, or Apple asks for iPad pictures) |
| Languages | Arabic and English (switch in Settings) |
| Price | Free, no ads, no purchases |
| Category | Games: Simulation (second: Family) |

## Store text (English)

- **Name (30 letters at most):** Land of Goodness
- **Subtitle (30 at most):** A quiet farm by the Gulf
- **Promotional line:** Bring your grandfather's farm back to life, and the village with it.
- **Keywords (100 at most):** farm,farming,village,kuwait,gulf,cozy,calm,fishing,harvest,family,arabic,quran,offline,kids
- **Description:**

Your grandfather left you a small farm at the edge of a village by the sea. The well is dry, the market is quiet, and the neighbors are waiting to see what you will do.

Dig, plant and water. Grow turnips, tomatoes, wheat, watermelons and winter onions through four seasons. Keep chickens, goats, sheep and a cow. Fish for five kinds of Gulf fish, look for pearls, and dig copper in the cave.

Five neighbors each have a story. Help them, bring them food, and give to the village works: the well, the palm grove, the market, the dock and the diwaniya. When the last one is finished, the whole village comes together for a festival.

- A calm game: no fighting, no timers that punish you, no ads and no purchases
- Listen to the Quran, recited by Mishary Alafasy, while you farm
- Works without the internet; only the Quran recitation downloads each sura once, when you choose it
- Arabic and English
- Nature sounds only: rain, wind, birds and the sea
- A collections book to fill, a caravan at the end of each season, and letters from the neighbors

## Store text (Arabic) — the owner should read this before use

- **الاسم:** أرض الخير
- **العنوان الفرعي:** مزرعة هادئة على ساحل الخليج
- **النص الترويجي:** أعد الحياة إلى مزرعة جدّك، ومعها القرية كلها.
- **الكلمات المفتاحية (100 حرف على الأكثر):** مزرعة,زراعة,قرية,الكويت,الخليج,هادئة,صيد,حصاد,عائلة,قرآن,لؤلؤ,أطفال,بدون إنترنت
- **الوصف:**

ترك لك جدّك مزرعة صغيرة على طرف قرية قرب البحر. البئر جافة، والسوق هادئ، والجيران ينتظرون ما ستفعله.

احفر وازرع واسقِ. ازرع اللفت والطماطم والقمح والبطيخ وبصل الشتاء في أربعة فصول. ربِّ الدجاج والماعز والخراف وبقرة. اصطد خمسة أنواع من سمك الخليج، وابحث عن اللؤلؤ، واستخرج النحاس من الكهف.

لكل جار من الجيران الخمسة قصة. ساعدهم، وقدّم لهم الطعام، وشارك في أعمال القرية: البئر وبستان النخيل والسوق والمرسى والديوانية. وحين يكتمل آخرها تجتمع القرية كلها في مهرجان.

- لعبة هادئة: لا قتال ولا إعلانات ولا مشتريات
- استمع إلى القرآن الكريم بصوت مشاري العفاسي وأنت تعمل في المزرعة
- تعمل بلا إنترنت، إلا تلاوة القرآن: تُحمَّل كل سورة مرة واحدة حين تختارها
- بالعربية والإنجليزية
- أصوات الطبيعة فقط: المطر والريح والطيور والبحر

## Privacy answers (App Store Connect → App Privacy)

- **Data collected:** none. The game has no accounts, no analytics and no ads. The save file stays on the phone. The only network use: when the player chooses a sura in the mosque, the game downloads that recitation once from cdn.islamic.network (Mishary Alafasy) and keeps it on the phone. Nothing about the player is sent.
- **Tracking:** no.
- **Privacy policy link:** Apple asks for one even when nothing is collected. A one-page text saying the above is enough; it needs a web address the owner controls.
- **Notifications:** local only, at most one a day between 8 AM and 9 PM, and they can be turned off in Settings. Prayer times are worked out on the phone for Kuwait City; the game does not read the phone's location.
- **Encryption question:** no. The store preset already sets `ITSAppUsesNonExemptEncryption` to false.

## Age rating answers

All "None": violence, sexual content, profanity, drugs, gambling, horror, contests, unrestricted web access, user-made content, messaging. Expected rating: the lowest one (4+).

The game shows a mosque and a prayer reminder. Step 11 of the plan (a reviewer for these) should be done before the upload.

## Pictures

- **Icon:** `assets/appIcon/icon_1024.png` (1024 x 1024, set in both iPhone presets).
- **Screenshots:** Apple needs the 6.9-inch size, 2868 x 1320 in landscape, 3 to 10 pictures for each language. `tools/store_shots.gd` takes seven in English and seven in Arabic (farm, village, merchant, harbor, book, map, Quran) into `build/store_screenshots/` on the Mac. Retaken on 2026-11-14 with the bigger field, the new quests page and the Quran window. They come from the Mac, not a phone, so the clock's colon can look different from the phone's.

## How to make the store build (on the Mac)

1. `git pull`, then open no editor.
2. Raise `application/version` in the "iOS Store" preset in `export_presets.cfg` (this file is not in git; it lives on the Mac).
3. `Godot --headless --path . --import`
4. `Godot --headless --path . --export-release "iOS Store" build/ios_store/LandOfKhair.xcodeproj`
5. Archive and upload from the command line (used for build 11):
   `xcodebuild -project LandOfKhair.xcodeproj -scheme LandOfKhair -configuration Release -destination 'generic/platform=iOS' -archivePath LandOfKhair.xcarchive -allowProvisioningUpdates DEVELOPMENT_TEAM=NBCQF98255 CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" TARGETED_DEVICE_FAMILY=1 archive`
   then `xcodebuild -exportArchive -archivePath LandOfKhair.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath export -allowProvisioningUpdates` (method app-store-connect, destination upload).
   The signing identity must be "Apple Development" for the archive; the upload step re-signs for distribution.

The "iOS Store" preset is the same as "iOS" but leaves out `tests/`, `tools/` and `doc/`, signs for distribution, and answers the encryption question. The phone check (`tests/phone_check.gd`) only runs in debug builds, so leaving it out is safe.

## Only the owner can do these

1. Create the app record in App Store Connect with the bundle ID above, and accept Apple's agreements.
2. Find the reviewer for the mosque and prayer reminder (plan step 11).
3. Read the Arabic text above and choose the word for dhow.
4. Put the privacy text on a web page and give its address.
5. Say yes to the upload to TestFlight.
