# Land of Khair: Story, Loop Check, and Hooks

> Approved by the owner on 2026-11-07.
> Same five people we already have: Jassim, the elder, the merchant, the carpenter, and the fisherman. No new characters.

## 1. Loop check: what works, what is missing

**The daily loop today:** wake at 6:00 → water and harvest → feed animals → gather wood, stone and copper → go to the village (sell, buy seeds, the day's request, gifts) → sleep to save.
One game day is about 14 real minutes.

**What works**
- There is always a next step: the quest line under the day, then the elder's five projects, then the festival ending.
- Money adds up properly. A turnip costs 10 and sells for 20. The five projects cost 6,800 dinars in total, which is several seasons of play.
- A daily request, letters, a fair every season, and friendship hearts mean every day is a bit different.

**Gaps (in order of how much they hurt)**

| # | Gap | Why it hurts | Fix |
|---|---|---|---|
| 1 | The field is big (24×14), but every square is watered by hand and costs hearts | A bigger field means more chores, not more fun, so players stop planting | **Sprinklers** made from copper (water the squares around them every morning) |
| 2 | The story only happens at the very start and the very end | The middle feels like paying bills to the elder | **Story chapters** tied to the five projects (section 2) |
| 3 | Nothing brings the player back after they close the game | Game time stops when the app is closed | **Hooks** (section 3) |
| 4 | Winter has only wheat | One season in four is thin | A winter crop (e.g. **onions** or **radish**) and the winter fair |
| 5 | Crops never regrow | Every harvest is a full replant | **Tomatoes regrow** 2 days after each harvest |
| 6 | After the ending there is nothing new | The farm is open but there is no goal | **Collections book** and grandfather's last page (section 3) |

## 2. The full story

**The thread:** the boy's grandfather, *Jaddi Saad*, kept a journal. He hid its pages around the village, one with each person he trusted. Each chapter returns one page, and each page explains something about the village's past and why it fell quiet. This gives a mystery to follow without adding new characters.

**Prologue: The farm (days 1–3)**
The boy arrives at his grandfather's farm. Jassim, the neighbor, meets him at the gate with a key and the first journal page: *"If you are reading this, the farm is yours. Plant something. Then go and meet the village."*
Play: the existing first quests (turnip, Jassim, the coop).

**Chapter 1: The well (water)**
The elder explains that the old well dried up the year Jaddi Saad fell ill. Since then, families have carried water from the river. Building the well again is the first project.
*Page 2 (from the elder):* Saad dug the first well with his own hands and wrote how deep the sweet water lies.
When it is done, villagers come to the well in the morning and the square comes back to life.

**Chapter 2: The palm grove (roots)**
The merchant says the old date palms were sold off during a hard year. Planting the grove brings back the orchard.
*Page 3 (from the merchant):* Saad never sold his palms, and he lent dates to anyone in need. Many still owe him a kindness. *"Pay it to my grandson instead,"* the page says.
Unlocks: dates in more requests, and the orchard harvest fair.

**Chapter 3: The market (trade)**
The carpenter builds new stalls. The caravan road opens again, and on some mornings a caravan brings rare seeds.
*Page 4 (from the carpenter):* a sketch of the diwaniya Saad wanted to build for the whole village. He never finished it.
Unlocks: a weekly **caravan day** with special seeds (watermelon early, the winter crop).

**Chapter 4: The dock (the sea)**
The fisherman tells how the dhows stopped going out after the old dock broke in a storm. Fixing it brings the boats back.
*Page 5 (from the fisherman):* Saad once went pearl diving and came home with one pearl. He gave it to the village to buy the first boat.
Unlocks: better fishing and the pearl divers' return (the summer fair).

**Chapter 5: The diwaniya (together)**
Everyone helps build Saad's unfinished diwaniya from the carpenter's sketch.
*Page 6 (the last one, from the boy's own chest at home):* *"A farm feeds a family. A village feeds a heart. Thank you for finishing what I started."*
→ the festival ending we already have. The farm stays open afterward.

**Small personal stories (from friendship hearts, 3 and 6 hearts)**
- **Jassim:** his hens keep escaping. Help him build a fence, and he sends eggs every week after that.
- **The elder:** he cannot read small writing anymore. The boy reads Saad's pages aloud to him.
- **The merchant:** he wants to sell something "from our own land". The boy brings his first perfect harvest.
- **The carpenter:** he is teaching himself to carve. He gives the boy a carved toy dhow (a decoration for the house).
- **The fisherman:** he is afraid of the sea since the storm. The boy goes out with him once at dawn (a calm fishing scene).

Each one is 2–3 short talks. No romance and no combat.

## 3. Hooks: what brings the player back

### A. Inside the game ("one more day")
1. **Tomorrow teaser at bedtime:** when the boy sleeps, one line shows what tomorrow brings, for example "Tomorrow: your tomatoes are ripe", "Tomorrow: caravan day" or "Tomorrow: the summer fair". This is the strongest "just one more day" hook in farming games.
2. **Ripe sparkle:** ripe crops shine, and the map shows a leaf mark on the farm when something is ready, like the "!" marks we already have.
3. **Journal pages:** a locked page shows as a silhouette in the menu ("Page 3: ask the merchant"). Curiosity keeps people going.
4. **Collections book:** every crop, fish, find and gift, shown as silhouettes until the player has found it. Finishing a row gives a small decoration. This gives players a goal after the ending.

### B. On the phone when the game is closed (notifications)
**Important:** today the game clock stops when the app is closed, so a crop can never finish while the player is away. A notification like "your crops are ready" needs one design decision first:

| Option | How it works | Notification examples | Fairness |
|---|---|---|---|
| **1. Gentle overnight (recommended)** | If the player is away for 8 real hours or more, the farm moves forward **one** night when they come back: crops grow one step and animals give their eggs and milk. Never more than one night, and nothing dies or wilts | "Your turnips are ready to harvest 🌱", "Jassim left a letter for you", "The caravan is here today" | No punishment for staying away and no streaks to lose |
| 2. Time stays paused | Nothing changes while the app is closed | Only real-world reminders: a new letter each real day, and prayer times (optional) | Safest, but a weaker hook |
| 3. Full real time | Crops grow by the real clock | "Ready" pushes every few hours | Feels like a mobile timer game, which goes against our "no exploitative timers" rule. Not recommended |

**Rules for every notification:** at most **one a day**, never at night (after 9 PM or before 8 AM), all can be turned off in Settings, and none ever says "you're losing" or "come back or else". Prayer reminders are separate and off by default.

**Building it:** iOS notifications while the game is closed need a small Godot iOS plugin for *local* notifications (no server, no account, free). Installing it means downloading the plugin, so the owner says yes first. This is the same piece that the planned prayer reminder needs when the game is closed.

## 4. Build order and status (2026-11-07)

Built: 1, 2, 3 and 4 (gentle overnight and phone notes with the Notification Scheduler plugin). Not built yet: friendship stories, the collections book, and the winter crop.

1. **Sprinklers + tomatoes regrow** (fixes the biggest loop problem, small)
2. **Tomorrow teaser + ripe sparkle on the map** (small, a strong hook)
3. **Journal pages + chapter talks** for the five projects (medium, mostly text)
4. **Notifications**, after the owner picks an option in section 3B (needs the plugin download)
5. **Friendship stories**, then the **collections book** and the **winter crop**
