# Land of Khair — Playtest checklist

Run this before every install on the iPhone. Part A runs on the Mac and must pass first; Part B is a short play on the phone. Write down anything that fails, fix it, and run the failed part again. The game rules these checks protect are in `doc/LAND_OF_KHAIR_PLAN.md`, section 1a.

## A. On the Mac (before building)

1. **Godot is closed**, or was opened after `addons/khair_hd` existed. An older open editor turns HD pictures back into plain ones, and the game shows four times too big.
2. **Pictures are still HD:** `grep -rl 'importer="khair_hd"' assets --include='*.import' | wc -l` is not lower than last time (141 on 2026-11-04), and `git status --short -- '*.import'` shows no `.import` file changed by accident.
3. **Core test:** `KHAIR_SAVE=<scratch>/t.json Godot --headless --path . --script tests/core_loop.gd` ends with `failed=0`.
4. **Playthrough:** the same with `tests/playthrough.gd` ends with `PLAYTHROUGH passed=15 failed=0`.
5. **Renders:** render the farm, village, woods, harbor, orchard, road, and house from above and at play zoom (`shots/hd.gd`-style scratch tool). Look for: pictures too big or too small, white boxes (a picture freed before drawing), blocky ground edges, and anything floating or cut off.
6. **Menus:** render the burger menu's Bag, Settings, Quests, and Map tabs, a two-column choice menu (the workbench), and the prayer banner. Nothing spills past the wooden frame; Arabic text fits its button.
7. **File names match in case.** The phone cares about capital letters and the Mac does not, so every `res://` path must match its folder exactly (for example `assets/building/Mosque/`).
8. **Sounds:** any new sound is a real recording with a CC0 or similar free license, recorded in `tools/loop_nature.py` or `tools/make_audio.py`. No music.

## B. On the iPhone (about ten minutes)

Open the game from the home screen if the Mac cannot open it (the phone is usually locked).

| # | Check | Pass when |
| --- | --- | --- |
| 1 | Start | The splash shows once, the title screen appears, and Continue opens the saved farm |
| 2 | Screen | The game fills the screen, the HUD stays clear of the notch, and the zoom shows the boy at a comfortable size |
| 3 | Walk | Tap to walk works on grass, roads, and bridges; the boy stops at water, buildings, and the tree edges |
| 4 | Field | The fenced field by the house is easy to find; hoe, plant, water, and harvest each work on a square |
| 5 | Tools | Axe on a stump, pickaxe in the quarry, and the hand on dates and herbs each give one item and a small "+1" |
| 6 | Signs | Each exit has a wooden signpost whose name can be read, and walking past it opens the right place |
| 7 | Village | People walk and talk; the mosque door offers Pray; the merchant buys and sells |
| 8 | Menus | The workbench menu is short; the burger menu tabs open and close; the Map tab marks where the boy is |
| 9 | Prayer times | Settings shows the next prayer time; turning it off hides it and stops the banner |
| 10 | Sound | Birds come and go with silence between; there is no hiss or static; Settings Full, Soft, and Off work; the waterfall plays in the woods and village |
| 11 | Rain | On a rainy day (or by sleeping until one), the screen looks rainy and the sound fades softly to rain |
| 12 | Sleep and save | Sleeping starts the next morning; closing the game fully and opening it again keeps the day, the field, and the bag |
| 13 | Feel | No stutter while walking, and the phone does not get hot after ten minutes |

## C. After the test

- Write the result in the plan's change log: the date, the build, and which checks passed or failed.
- A failed check is fixed and rechecked before the next feature starts.
- Commit only when the owner says "Yes, commit locally". Never push without asking.
