Read PLAN.md before starting work.

## Trello tasks

The owner tracks every project's tasks on the Trello board "All Projects" (https://trello.com/b/57ED1jPJ/all-projects), through the Trello connector. Lists: To do, In progress, Waiting on me, Done.

- This project's cards start with `[Land of Goodness]` and use the green label. Only touch cards with this prefix.
- Before starting work, read this project's cards. The owner adds and edits cards in Trello, so a new or changed card is a request.
- When you finish, start or plan something, update Trello right away, without being asked: move the card, or add a new card with the prefix and the green label. Put things the owner must do or decide in "Waiting on me".
- Keep the project's "[Land of Goodness] Done so far" card in Done up to date with a short list of finished work.

## Laptop memory and disk

This Mac has only 8 GB of RAM and little disk space. When you finish testing, close what you opened: iPhone simulator (`xcrun simctl shutdown all`, then quit the Simulator app), Android emulator (`adb emu kill`), and any dev server or Metro bundler you started. Before starting a simulator or emulator, check whether one is already running and reuse it. Don't leave anything running in the background.

## Two laptops

Daily work happens on the ASUS (Windows, 32 GB) at `C:\Projects\ard-al-khair`, with Godot 4.7.2 at `C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`. The chat stays on the Mac and runs commands there with `ssh asus "<PowerShell command>"` (Tailscale). Filter the post-quantum SSH warning lines from the output.

- Edit, test and commit on the ASUS, then push to GitHub (branch production-v1).
- The Mac copy is only for iPhone builds: `git pull`, export from Godot on the Mac, build in Xcode, install on the iPhone 16e.
- Hand-off: when a version is ready for the iPhone, add a Trello card "[Land of Goodness] Mac: build <commit>" in To do.
