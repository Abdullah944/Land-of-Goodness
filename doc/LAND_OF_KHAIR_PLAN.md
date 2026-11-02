# أرض الخير — Land of Khair

> **Living development plan** · Version 1.0 · Updated 2026-10-31  
> Status: Active planning and iterative development  
> Repository: `Abdullah944/Land-of-Goodness`  
> Engine: Godot 4.7.x · Targets: iOS and Android

## 1. Vision

Create an original, peaceful **2D top-down / 3/4-view cozy farming and village-life game** rooted in Kuwaiti and Gulf culture. Players cultivate a farm, gather resources, build their home, trade, meet neighbors, help the community, and develop their land over many in-game days.

The long-term identity includes **optional** Islamic experiences (prayer times, Quran listening/reading, dhikr) and potentially family cooperation. Worship is not a score, currency, competitive leaderboard, or paywall.

### Design pillars

1. **Enjoyable first:** satisfying touch-friendly farming, exploration, and progression.
2. **Kuwaiti identity:** traditional architecture, palm groves, Gulf fishing, markets, and local characters.
3. **Peaceful and family-friendly:** no required combat, no dark or violent theme.
4. **Faith with respect:** accurate optional religious features, reviewed before release, never gamified as a paid reward.
5. **Small and testable:** build one complete feature at a time, test on iPhone, and preserve working systems.

### Inspirations, not assets to copy

- **Stardew Valley (mobile):** broad farming-RPG loop, touchscreen interaction, day structure, social exploration.
- **Roots of Pacha:** community-oriented progression and peaceful atmosphere.
- Reference footage: [Stardew Valley mobile Day 1 gameplay](https://youtu.be/2Dfk4Dw213I).
- AI-assisted development workflow reference: [Reverse-engineering-inspired game development video](https://youtu.be/6MpHBHw30OE).

Use observations, timing measurements, and public documentation to inform **original** implementations. Do not copy other games' protected artwork, music, maps, dialog, or code. Only apply reverse-engineering tools to targets the project is authorized to analyze.

## 2. Technical and art decisions

| Area | Current decision |
| --- | --- |
| Engine | Godot 4.7.x; maintain existing project rather than restarting |
| Rendering | 2D pixel art, nearest-neighbor, crisp edges, landscape on mobile |
| World tile | 16×16 pixels |
| Character target | Chibi, approximately 32×48 pixels in idle view |
| Controls | Tap-to-move, drag movement, pinch zoom; desktop controls for development |
| Palette | Cream `#FFF3DC`, beige `#E7C99A`, deep brown `#3F2D27`, date brown `#7A4F32`, palm green `#5E9B62`, sage `#8EAD72`, Gulf blue `#55AFC4`, teal `#4F9F9A`, terracotta `#C96F4A`, gold `#D9A441` |
| Artwork | Test AI reference art (Higgsfield, etc.), then verify transparency, size, palette, pixel grids, and animation consistency; retain existing assets unless replacements are approved |
| Source control | GitHub `main`, review and test changes before pushing |
| iPhone testing | TestFlight builds; automate approved builds later |
| Coding style | One focused responsibility per script, short file header comments, readable code, data-driven content; avoid unnecessary changes |

## 3. Confirmed state of the existing prototype

The following are **reported by Cursor**; verify again after meaningful changes.

- [x] Character can walk by touch or keyboard; transitions among farm, house exterior/interior, and cave.
- [x] Hoe, watering can, axe, and pickaxe interactions.
- [x] A 3×3 field of independent squares, one turnip, rain and winter behavior.
- [x] Jassim NPC quest and turnip sale.
- [x] Basic fishing, cave mining, tree chopping, seed crafting.
- [x] Clock, seasons, sleep, hearts, and JSON save in `user://`.
- [x] Inventory and wooden HUD are functional.
- [x] Godot iOS export, app icon, and HUD resource compatibility configured.
- [x] Initial game build reached TestFlight and appeared on iPhone.
- [ ] Document actual device-test results for startup, display, movement, gameplay, and saves.
- [ ] Verify current startup branding and make sure it appears only once.
- [ ] Verify that adding an Arabic project name did not strand existing desktop save data.

**Known limitations:** Four crops (turnip, tomato, wheat, watermelon) on a 3×3 field. Jassim sells one seed at a time and still buys turnips only. Fishing and mining stay simple. The bag scrolls, but it is not a full slot grid. No sound, animals, or girl character yet. Some art is unused. Preserve progress instead of rebuilding everything.

## 4. Development phases

### Phase 0 — Stabilize the current mobile build

**Goal:** Reliable baseline on iPhone before more gameplay changes.

- [ ] Test splash, orientation, display scaling, touch input, inventory, and saves on TestFlight.
- [ ] Record and fix blockers only; avoid cosmetic scope creep.
- [ ] Confirm Git status and back up current working build with a reviewed commit/tag.

**Done when:** One complete farming day runs and saves successfully on iPhone without critical errors.

### Phase 1 — Complete farming-day loop **(complete)**

**Player loop:** prepare land → plant → water → advance days → harvest → sell → buy seeds → improve farm → repeat.

- [x] **1.1 Multi-tile field:** reusable tile-based till/plant/water/harvest states; start small, expand later.
- [x] **1.2 Multiple crops:** at least three with data-driven growth, purchase/sale values, and season rules.
- [x] **1.3 Seed purchasing:** simple shop interaction and understandable prices.
- [x] **1.4 Harvest feedback:** animation/effect, item collection, inventory count, and clear action feedback.
- [x] **1.5 Persistence:** all farm tiles, growth stages, seeds, inventory, and money save/reload correctly.
- [x] **1.6 Device validation:** finish at least three in-game days on iPhone.

**Done when:** The player can repeatedly farm, harvest, sell, buy, sleep, and continue without a dead end or lost progress.

### Phase 2 — Resources, crafting, animals, and farm expansion

- [x] **2.1 Repeatable gathering:** a chopped tree and a mined rock return the next morning. Fishing stays once each day and resets at morning. Dates and forage are Phase 2.2.
- [x] **2.2 Dates and forage:** one date palm and one wild herb on the farm. A tap picks one item with the hand. Both return the next morning. Counts are saved. They are not sold or crafted yet. Passed on iPhone in TestFlight build 8, including bag scrolling.
- [ ] **2.3 Storage chest:** one wooden chest inside the house. Store or take one item at a time. Dinars, hearts, and tools stay with the player. Old saves open an empty chest. Local tests passed. The chest artwork and the iPhone test are still required.
- [ ] Expand gathering: wood, stone, dates, forage, and fishing.
- [ ] Replace single-resource interactions with repeatable, balanced resource systems.
- [ ] Build expandable inventory and storage.
- [ ] Introduce basic crafting recipes and simple structures.
- [ ] Add chickens, sheep/goats, cows, and animal-product loops incrementally.
- [ ] Expand farm plots and upgrade tools/buildings.

**Done when:** Farming and gathering support meaningful choices and upgrades over multiple days.

### Phase 3 — Original Kuwaiti village and characters

- [ ] Design a coherent map: farm, house, market, harbor, palm orchard, mosque, and cave.
- [ ] Introduce distinct NPCs with schedules, simple dialogue, and meaningful requests.
- [ ] Add a local market economy and village-service tasks.
- [ ] Design seasons and culturally fitting community events.

**Done when:** Leaving the farm feels rewarding and makes farm progress matter.

### Phase 4 — Long-term progression and polish

- [ ] Farm upgrades, unlocks, shops, and optional decoration.
- [ ] Good tutorial and clear first-time player guidance.
- [ ] UI accessibility, mobile responsiveness, sound, music, animation polish.
- [ ] Balancing and game-feel tuning based on device tests.

### Phase 5 — Islamic and family systems

- [ ] Optional prayer times with location/accuracy settings and notification controls.
- [ ] Quran reading/listening interface with vetted content and audio permissions.
- [ ] Optional dhikr and reflective features; no worship leaderboards or paid religious access.
- [ ] Islamic calendar/event support with content review.
- [ ] Explore asynchronous family visits/shared goals before committing to real-time multiplayer.

### Phase 6 — Monetization and release

- [ ] Validate demand with real testers before committing to pricing.
- [ ] Prefer free core play, no ads, and optional one-time Premium for non-essential cosmetic/expansion content.
- [ ] No pay-to-win mechanics, exploitative timers, or paid religious essentials.
- [ ] Release readiness: crash monitoring, privacy, store assets, age rating, platform testing.
- [ ] Optional approval-gated automated TestFlight releases.

## 5. Standard workflow for every feature

1. **Research:** Observe reference gameplay, gather known facts, and mark estimates as estimates.
2. **Specify:** Describe the mechanic, inputs, states, outputs, save data, and acceptance criteria.
3. **Art:** Produce only necessary original assets; verify technical sprite quality before import.
4. **Implement:** Cursor modifies a small, reviewed portion of the Godot project.
5. **Validate:** Godot script checks, in-editor playthrough, and targeted regression tests.
6. **Test on iPhone:** Build through TestFlight when a meaningful milestone is ready.
7. **Review:** Confirm results, update this plan, then move to the next item.

**Gate:** Cursor should not install packages, replace large art sets, rewrite architecture, commit, push, or upload builds without explicit approval for that step.

## 6. Next action

Local branch `production-v1` holds the production work. `main` was not changed. Nothing was pushed or uploaded.

**Milestone 1 (commit 54a4d9b):** crafting, animals, selling every good, a 4×4 field upgrade, a watering-can upgrade, and paths to the village, harbor, and orchard. Arabic first, English in Settings.

**Milestone 2 (this commit), tested on side saves only:**

- The village, harbor, orchard, and cave are built from `tools/build_places.py`. They have textured ground, Gulf houses, market stalls, a dock with dhows, an oasis, cave walls, and solid props. Invisible walls keep the boy inside each place and off deep water.
- The elder, merchant, carpenter, and fisherman walk between daily spots by the hour and stop while talking.
- Chickens, goats, sheep, and cows wander beside the coop and barn. Unfed animals look paler. The coop and barn block walking once built.
- A title screen offers Continue, New game (with a confirmation), and language. A new game keeps a dated copy of the old save and never deletes it.
- The pause menu stops the clock. A Quests tab lists every step of the main goal with a check mark.
- Herbs alone make feed, and the merchant sells feed for 10 dinars, so animals can be fed before the wheat season.
- Reaching the main goal pays 300 dinars once.
- Saves write to a temporary file, then replace the old one. The last good save is kept as a backup. A damaged save is kept aside and the backup loads instead. Negative or broken values load as safe defaults.
- A tap the boy cannot reach (behind a wall or stall) now stops him instead of pushing forever.
- Android: a local preset exports a debug APK signed with the local debug keystore. The project icon is set.

**Tests:**

- `tests/core_loop.gd`: 64 of 64 passed.
- `tests/playthrough.gd`: a brand-new farm with an ordinary daily routine reaches the main goal on day 19. Dinars never go negative, and the first sale is on day 4.
- Both tests refuse to run without a side save in `KHAIR_SAVE`. The real save was checked by hash before and after every run and was unchanged.
- Screenshots of the farm, village, harbor, orchard, and cave were taken and viewed.

**Known issues found by the playthrough:** The farm ends the goal with about 2,300 dinars. Income outpaces what there is to buy, so more money sinks are needed (sheep and cow upgrades, house upgrades, decorations, a second coop). Date sell price was lowered from 25 to 15. Wood (two trees a day) is the slowest step before the barn.

**Not release-ready yet.**
- The fisherman and other villagers are small sprites and need better art.
- Arabic lines still need a native review.
- There is no reviewed Quran or adhan content, so prayer and reading are not in the game.
- A release Android keystore needs your approval.
- No iPhone or Android run has been done for this branch. The APK was built, but no Android device or emulator was available.

Phase 2.3 is still open until the iPhone test of the chest in build 9 passes.

**Milestone 3, tested on side saves and desktop renders only:**

- The game fills wide phones and iPads. The panels pin to the screen edges, and the HUD stays clear of the notch. The notch margin still needs an iPhone check.
- Long dialogue menus show pages with More and Cancel. Before this, the top of the animals menu ran off the screen, so Buy chicken could not be tapped.
- The village Khair meter sits under the hearts. Share one food with each neighbor per day (+2), give 10 dinars through the elder once per day (+3), and feed animals (+1 once per day). It never falls, stops at 100, and gives seeds at 10, 30, 60, and 100. Old saves start at 0.
- `tests/core_loop.gd`: 86 of 86 passed. `tests/playthrough.gd`: 7 of 7 passed, goal on day 19.
- A signed debug build was installed by cable on the iPhone 16e. On 2026-11-01 the owner confirmed that it opens and fills the screen. The notch margin, old save, gift, and Buy chicken checks were not separately reported.
- Check on iPhone: the "E" bubble is a keyboard letter that means nothing on a touch screen.

**Milestone 4, content complete, tested on side saves and desktop renders:**

- The single-player story now has an ending. After the farm is established, the elder asks for five village projects in order: well, palm grove, market, harbor dock, and diwaniya. Each one appears in the world and has an effect (new daily date palms, goods sell for a tenth more, pearls while fishing at the harbor).
- A neighbor asks for goods each day and pays dinars and Khair. When all projects are done and the Khair meter is full, the next morning opens the village festival and credits. The farm stays open afterward.
- Money sinks: bigger house (7 hearts), second coop and barn (double animals), largest field (5x5), best watering can, four house decorations, and wood and stone bundles from the carpenter.
- Hearts now matter. Each tool swing costs a tenth of a heart. The Eat button in the bag restores one heart, and sleep restores all.
- Phone fixes: the "E" bubble became a speech bubble, the clock waits during talk and the chest, the game saves when sent to the background, and the camera stays on the map.
- The empty field now shows soil, and watered soil looks darker. The house moved from past the top of the map to just above the field. Exits show a gold arrow and the place name. Menu tabs are text in the chosen language.
- A bug where hidden map markers counted as people was fixed. Tapping near one could stop the boy or open Jassim's talk.
- Refused actions say what is missing. Every line exists in Arabic and English.
- Original music and sound effects come from `tools/make_audio.py`, with separate Music and Effects settings. Small pictures come from `tools/draw_items.py`.
- `tests/core_loop.gd`: 132 of 132 passed, including walks that use the same call as a screen tap. `tests/playthrough.gd`: 15 of 15 passed. An ordinary routine establishes the farm on day 19 and reaches the festival on day 48.

**Not done on purpose:** prayer, Quran, and dhikr (need a named reviewer), the mosque, and family play (decided for after the single-player game proves fun). The villagers, animals, coop, barn, and well were generated with SpriteCook, and their asset ids are in `spritecook-assets.json`. The pearl, rug, and soil are still script drawings.

**Look pass after studying the Stardew Valley mobile Day 1 video (ideas only, no art or text copied):**

- The camera shows more of the world and the boy is smaller. Paths, fences, flowers, stones, and weeds fill the ground. New grass, pond, and date palm came from SpriteCook.
- Talk boxes are warm wood, show a portrait and a name, and reveal text letter by letter.
- Jassim, the elder, the merchant, and the carpenter have eight-frame idle animations. The fisherman breathes by code. Palms sway, water moves, and people, trees, and animals have soft shadows. Daylight is brighter.
- The farm starts with twigs, stones, and weeds that clear for good and pay one item each. The cleared list is saved with the farm.
- The world darkens with a tint at night, and lanterns and torches glow. Picking something up shows a small "+1", and tools throw a puff of dust, water, or chips.
- The house is a real room with walls, a floor, and furniture cut from `house_interior.png` by `tools/cut_interior.gd`. The title screen shows the app art. Villagers lean as they walk.
- Scale pass measured from the video: people are about 13% of the screen height and houses about four times a person's height. The boy and villagers drew at three quarters of their old size, the camera shows the full view by default, and buildings grew. The farm is 1040 by 680 (it was 512 by 288), and the village, harbor, and orchard are twice as wide and tall. Paths, trees, and details fill the new space.
- World pass after the owner's Stardew map and farm pictures: the farm ground is painted once by `tools/bake_farm_ground.gd` as a natural clearing of grass and dirt inside dark forest, with more ponds, tree groups, and about 60 pieces of debris. The farm now has two exits: east to a new caravan road and south to new ghaf woods, and both lead to the village. The menu has a Map tab with a mark on the boy's place.
- Farm zones, from the owner's notes on Stardew farm types: each corner of the farm has a daily job. The northwest quarry gives stone and copper, the southern woodlot gives wood from stumps, the eastern patch gives herbs, and each farm pond gives one fish a day. A crate on the harbor shore holds one find each morning.
- World rebuild after the owner's full Stardew world map (ideas and proportions only, original layout): `src/scripts/World/world_shapes.gd` holds each place's edge, roads, water, and bridges, and `tools/bake_farm_ground.gd` paints every outdoor ground from it. The farm is 80 by 65 tiles, the village is a town of about 100 by 78 with a plaza, 11 homes, and a sea inlet with two bridges, and the woods are about 94 by 81 with a lake. Places join edge to edge: farm east to road to village, farm south to woods to village, village south to harbor with open sea, and village north to orchard. The boy walks faster to match.
- Characters: the owner's reference shows small, matching sprites with big heads, dark outlines, and clear hair and clothes. Villagers and animals now get hard edges, fewer colors, and a dark outline by code. True matching redraws need about 12 SpriteCook credits each, and 7 remain.
- Not done: redrawn villagers, true walking frames, cliffs like the reference maps, fishing at the woods lake, and choosing a farm type at the start.
- The iPhone install waits until the owner raises it. The certificate expired on 2026-11-01, and Xcode rejects the login.
- SpriteCook credits left: 7.

**Exact next action:** The owner plays a new game and reports problems. Then have a native speaker review the Arabic, and ask before any push, TestFlight upload, or Android release signing.

## 7. Open decisions

| Question | Current leaning | Decide by |
| --- | --- | --- |
| Final art generator | Seedream Lite is promising; test Nano Banana consistency | Before bulk asset production |
| Sprite pipeline | AI concepts + pixel-editor cleanup and exact-size verification | Before animation sheets |
| Game language | Arabic-first is preferred; verify audience and localization needs | Before UI content expansion |
| Family gameplay | **Decided 2026-11-01:** separate phones sharing a family farm and goals, each playing at their own time; build after the single-player loop proves fun | Decided |
| Good meter | **Decided 2026-11-01:** counts in-game kindness only. Prayer and Quran stay optional and unscored. The game does not claim real reward or heaven | Decided |
| 2D or 3D | **Decided 2026-11-01:** stay 2D | Decided |
| Everyday testing | **Decided 2026-11-01:** real iPhone, because the simulator is heavy on the 8 GB MacBook Air | Decided |
| Religious content reviewer | A scholar or teacher must review Quran, prayer times, and Arabic lines, including the Khair meter's "جزاك الله خيراً" lines; no reviewer named yet | Before any religious feature ships |
| Revenue model | **Decided 2026-11-01:** free, no ads, one optional purchase; recheck after player validation | Before release |
| Build automation | Approval-gated macOS/GitHub workflow | After reliable manual releases |

## 8. Change log

| Date | Change |
| --- | --- |
| 2026-11-02 | World pass: natural farm clearing with forest edge and ponds, caravan road and ghaf woods areas, a world Map tab, and Stardew-like scale. Not yet played by hand. |
| 2026-11-02 | Look pass after studying the Stardew Valley mobile video: SpriteCook villagers, animals, and buildings, idle animations, ground details, debris to clear, night lamps, a furnished house, portrait talk boxes, and a new title screen. Core test 150 of 150 and playthrough 15 of 15 passed on side saves. Not yet played on a phone. |
| 2026-11-02 | Production branch milestone 4: village projects, daily requests, festival ending, money sinks, working hearts, original music and sounds, visible field, house moved onto the map, and exit signs. Core test 132 of 132 and playthrough 15 of 15 passed on side saves. Full play on the iPhone is still required. |
| 2026-11-01 | Production branch milestone 3: full-screen layout for wide phones and iPads, paged long menus, and the village Khair meter. Core test 86 of 86 and playthrough 7 of 7 passed on side saves. The iPhone test is still required. |
| 2026-10-30 | Created the master plan from our agreed 2D Kuwaiti farming direction; marked existing prototype work and defined milestones. |
| 2026-10-30 | Phase 1.1: added a visible 3×3 farm. Each square tills, plants, waters, grows, and harvests on its own. Old saves still load; planted squares now store an optional turnip id. |
| 2026-10-30 | Confirmed there is one master plan, at `doc/LAND_OF_KHAIR_PLAN.md`. No `docs/` copy exists. |
| 2026-10-30 | Phase 1.2: tomato, wheat, and watermelon join the turnip in one catalog. The bag scrolls and the chosen seed is saved. Old saves keep turnip seeds and receive starter seeds for the new crops. |
| 2026-10-30 | Phase 1.3: Jassim offers sell, buy, or cancel. One seed costs the catalog price. A short purse changes nothing. Turnip sales still pay 20 dinars and complete the quest. |
| 2026-10-30 | Phase 1.4: a ripe crop shows a short picked message, then the quest or the previous note returns. The square stays tilled and the bag gains one item. |
| 2026-10-30 | Phase 1.5: checked save and load for the field, seeds, crops, dinars, quest, and day. Old saves keep their turnips and receive starter seeds only once. |
| 2026-10-31 | Selling turnips opens a short wooden receipt with the item, quantity, dinars earned, turnips left, and the balance. The empty-bag line appears only when there is nothing to sell. Bag rows show an icon, a name, and a right-hand count. The open bag shows the dinar balance. |
| 2026-10-31 | Phase 1.6 passed on iPhone: three farming days were completed on TestFlight. Phase 1 is complete. Phase 2 has not started. |
| 2026-10-31 | Phase 2.1: chopped trees and mined rocks return the next morning. Fishing remains once each day. The same spot cannot pay twice, and a reload or a cave trip does not bring it back early. Old saves still load. |
| 2026-10-31 | Phase 2.2: a date palm and a wild herb on the farm each give one item, then wait until morning. The bag saves dates and herbs. Local tests passed. The iPhone playtest is still required, so Phase 2.2 stays open. Phase 2.3 has not started. |
| 2026-10-31 | Phase 2.2 passed on iPhone in TestFlight build 8. Dates, herbs, repeatable gathering, and bag scrolling worked on the phone. Phase 2.2 is complete. Phase 2.3 has not started. |
| 2026-10-31 | Phase 2.3: a chest inside the house stores or returns one item at a time. The bag and the chest save together. An old save keeps its bag and starts with an empty chest. Local tests passed. The chest artwork and the iPhone test are still required, so Phase 2.3 stays open. Phase 2.4 has not started. |
| 2026-11-01 | Production branch milestone 2: built places with walls, walking villagers, visible animals, title screen, quest list, safe saves with backup, herb feed, and a debug Android APK. Core test 64 of 64 and new-farm playthrough passed. The real save was not changed. |
| 2026-11-01 | Production branch: crafting, animals, selling every good, a larger field, and paths to the village, harbor, and orchard. Side-save tests passed 38 of 38. The real save was not changed. The new maps are still simple grounds. Arabic copy, device tests, and Android signing are still open. |

### How to maintain this file

- The single master plan lives at `doc/LAND_OF_KHAIR_PLAN.md`. Do not create a second copy under `docs/`.
- After each approved milestone, mark completed checkboxes and add a dated change-log entry.
- Document changed decisions under **Open decisions** or add a short new section; do not silently remove earlier reasoning.
- Use this as a planning guide, not as permission for Cursor to execute every future phase automatically.
