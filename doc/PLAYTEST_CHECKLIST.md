# Land of Khair — Playtest checklist

Run this before every install on the iPhone. Part A runs on the Mac and must pass first; Part B is a short play on the phone (about fifteen minutes). Write down anything that fails, fix it, and run the failed part again. The game rules these checks protect are in `doc/LAND_OF_KHAIR_PLAN.md`, section 1a.

## A. On the Mac (before building)

1. **Godot is closed**, or was opened after `addons/khair_hd` existed. An older open editor turns HD pictures back into plain ones, and the game shows four times too big.
2. **Pictures are still HD:** `grep -rl 'importer="khair_hd"' assets --include='*.import' | wc -l` is not lower than last time (141 on 2026-11-04), and `git status --short -- '*.import'` shows no `.import` file changed by accident.
3. **Core test:** `KHAIR_SAVE=<scratch>/t.json Godot --headless --path . --script tests/core_loop.gd` ends with `failed=0`.
4. **Playthrough:** the same with `tests/playthrough.gd` ends with `PLAYTHROUGH passed=15 failed=0`.
5. **Renders:** render the farm, village, woods, harbor, orchard, road, and house from above and at play zoom (`shots/hd.gd`-style scratch tool). Look for: pictures too big or too small, white boxes (a picture freed before drawing), blocky ground edges, and anything floating or cut off.
6. **Menus:** render the burger menu's Bag, Settings, Quests, and Map tabs, a two-column choice menu (the workbench), and the prayer banner. Nothing spills past the wooden frame; Arabic text fits its button.
7. **File names match in case.** The phone cares about capital letters and the Mac does not, so every `res://` path must match its folder exactly (for example `assets/building/Mosque/`).
8. **Sounds:** any new sound is a real recording with a CC0 or similar free license, recorded in `tools/loop_nature.py` or `tools/make_audio.py`. No music.

## B. On the iPhone (about fifteen minutes)

Open the game from the home screen if the Mac cannot open it (the phone is usually locked).

| # | Check | Pass when |
| --- | --- | --- |
| 1 | Start | The splash shows once, the title screen appears, and Continue opens the saved farm |
| 2 | Screen | The game fills the screen, the HUD stays clear of the notch, and the zoom shows the boy at a comfortable size |
| 3 | Walk | Tap to walk works on grass, roads, and bridges; the boy stops at water, buildings, and the tree edges |
| 4 | Field | The fenced farm land below the house is easy to find; any square inside the fence can be hoed, planted, watered, and harvested, and the pickaxe clears an empty bed |
| 5 | Tools | Axe on a stump, pickaxe in the quarry, and the hand on dates and herbs each give one item and a small "+1" |
| 6 | Signs | Each exit has a wooden signpost whose name can be read, and walking past it opens the right place |
| 7 | Village | People walk and talk; the mosque door offers Pray; the merchant buys and sells |
| 8 | Menus | The workbench menu is short; the burger menu tabs open and close; the Bag shows only goods the boy has; the Map tab marks where the boy is, and pinch or + and - zoom it |
| 9 | Prayer times | Settings shows the next prayer time; turning it off hides it and stops the banner |
| 10 | Sound | Birds come and go with silence between; there is no hiss or static; Settings Full, Soft, and Off work; the waterfall plays in the woods and village |
| 11 | Rain | On a rainy day (or by sleeping until one), the screen looks rainy and the sound fades softly to rain |
| 12 | Sleep and save | Sleeping starts the next morning; closing the game fully and opening it again keeps the day, the field, and the bag |
| 13 | Feel | No stutter while walking, and the phone does not get hot after ten minutes |
| 14 | Touch answers | A tree tips over and drops leaves, a stump and a rock break into chips, the hoe puffs dust, the can splashes; each item jumps out and flies into the boy, and a "+1" note with its picture slides in beside the toolbar |
| 15 | Phone taps | Each tool swing gives a light tap, a fallen tree or broken rock a firmer one; sound effects Off turns the taps off too |
| 16 | Toolbar | The chosen tool's square pops; the bottom square shows the seed in hand with its count, and a tap picks the next seed |
| 17 | People and animals | A villager with a request shows "!", one with a birthday shows a gift; talking makes them hop, a gift shows a heart; hens peck and the others chew |
| 18 | Life outdoors | Small birds hop and fly off when the boy comes near; butterflies on spring and summer days, petals in spring, leaves in autumn, fireflies at night, rain streaks on rainy days, warm light before dusk |
| 19 | Surprises | Some mornings a villager's letter opens with a small gift; after sleeping, the note says tomorrow's weather; fresh soil sometimes gives seeds, a rock copper, a tree a nest |

## C. After the test

- Write the result in the plan's change log: the date, the build, and which checks passed or failed.
- A failed check is fixed and rechecked before the next feature starts.
- Commit only when the owner says "Yes, commit locally". Never push without asking.
