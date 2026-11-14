# Land of Goodness — Plan

Short status of the project. Updated 2026-11-13. The long design reference is `doc/LAND_OF_KHAIR_PLAN.md`; the store sheet is `doc/STORE.md`.

## Goal

A calm farming and village game set in a Kuwaiti village by the Gulf, in Arabic and English, for iPhone first.
The boy brings his grandfather's farm back to life, helps five neighbors, and repairs the village until the festival.
No fighting, no ads, no purchases, nature sounds only.

## Done

- The full game from the first day to the festival ending (about six weeks of game days)
- Five crops (turnip, tomato, wheat, watermelon, onion), animals, five Gulf fish, the cave, the collections book
- Five neighbors with stories, village works, a caravan each season, letters and gifts
- Game feel, sound check, Arabic read-through, balance (steps 2 to 9 of the A to Z plan)
- iPhone check on the 16e: 60 frames a second, safe saves (step 10)
- Art check: nothing out of style in 10 places (step 6)
- Store preparation: store text, privacy and age answers, store build setting, 12 store pictures (step 12, the part that needs no owner)
- Menu tidy: every tab fits inside the wooden frame, the open tab is marked (2026-11-13)
- Every window has the menu's look; big talking portraits of the five neighbors in the talk box (2026-11-13)
- Quran listening: the 114 suras recited by Mishary Alafasy, from the Quran shelf in the mosque; each sura downloads once when the player asks, no text shown (2026-11-14)
- Art check 2: animals by the barn, clearer rain, seasonal grass and trees, a centerpiece for each festival (2026-11-13)
- App Store: version 1.0 (build 11, iPhone only) submitted for Apple review on 2026-11-14, "Waiting for Review"; Made for Kids, ages 6-8; privacy and support pages on GitHub Pages. Listing: Arabic and English text, 7 pictures per language, age rating 4+, Data Not Collected, free in all countries, Games / Simulation and Family
- Prayer together, pathfinding around obstacles, tap anywhere on a tree or rock (2026-11-14, in build 11)
- UX pass from ~/.claude/DESIGN.md (2026-11-14, for 1.0.1, not in build 11): a ring answers every tap at once; tool work lands on the swing's impact frame and the hoe and can swing faster (the hoe tills about 0.35 s after a tap); toolbar slots tap across the whole toolbar width; small stones and herbs have a tap area of at least 32 game units (about 44 points)
- Android debug APK (2026-11-14): build/android/LandOfKhair-debug.apk on the ASUS, copy on the NAS; not run yet (no emulator image or Android phone); notifications are iPhone only

## Now

- The game is finished. Waiting for the owner (3 cards in "Waiting on me" on Trello):
  1. Play the latest build on the iPhone and note anything odd
  2. Find a reviewer for the mosque and prayer reminder
  3. Watch for Apple's review email (up to 48 hours); South Korea still needs a game rating number (RCN) before sale there

## Next

1. Fix what the owner reports from the iPhone
2. Change anything the reviewer asks for
3. Answer anything Apple's review asks

## Ideas / later

- Owner, no rush (Trello "Later"): pick the word for dhow, OK to download sea and wind sounds, SpriteCook credits
- Footsteps and animal sounds
- Replace pictures if any look wrong (SpriteCook: 8 credits left)
- Short frame dips on the iPhone: one place now and then drops to 42-47 frames a second for a moment, in any place and any weather (simplest road included), so not the game's load. Checked twice on 2026-11-13 with the 44x24 field fully planted: the farm holds 59-60.
- Android: run the APK on a phone or emulator; notifications need the plugin's Android files and a Gradle build

## Security check (~/.claude/SECURITY.md), 2026-11-14

- Passed: no keys, tokens or passwords in the code or anywhere in the git history (76 commits); no key or settings files ever committed; export_presets.cfg and build/ stay out of git.
- Passed: the store build is a release export; the phone speed check only runs in debug builds; the game prints nothing to the log; the app bundle holds only the normal files.
- Passed: no accounts, servers or database, so the sign-in, API, database and rate-limit rules do not apply. The only network use is the Quran download over HTTPS from cdn.islamic.network; nothing about the player is sent (App Store label: Data Not Collected).
- Fixed for 1.0.1: spritecook-assets.json (art IDs, not secret) was packed into the game; every export now leaves out spritecook-assets.json and docs/. The test-only switches (KHAIR_SAVE, KHAIR_SKIP_TITLE) now work only in debug builds.
- Website rule 14 (security headers): the privacy and support pages on GitHub Pages are plain text pages with no forms or scripts; GitHub Pages does not allow custom headers.
- Plugins: Notification Scheduler 6.0 and GMPShared 1.0 (local notifications only, no network). Not yet checked for newer versions.

## Design guide: where a rule does not fit

- Harvests flying to the bag: everyday actions stay calm (frequency of use), and items already jump and fly to the boy in an arc, so no bigger show was added.
- Talk-box choice rows are 30 game units high (about 41 points), a little under 44; making them taller would push long menus off the box. Menus already show 4 or fewer choices.
- Toolbar slots: the hit area is the toolbar's full width but only the gap between slots high (about 37 points), since the slots sit close together.

## Owner notes

