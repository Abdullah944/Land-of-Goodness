## Trello tasks

The owner tracks every project's tasks on the Trello board "All Projects" (https://trello.com/b/57ED1jPJ/all-projects), through the Trello connector. Lists: To do, In progress, Waiting on me, Done.

- This project's cards start with `[Land of Goodness]` and use the green label. Only touch cards with this prefix.
- Before starting work, read this project's cards. The owner adds and edits cards in Trello, so a new or changed card is a request.
- When you finish, start or plan something, update Trello right away, without being asked: move the card, or add a new card with the prefix and the green label. Put things the owner must do or decide in "Waiting on me".
- Keep the project's "[Land of Goodness] Done so far" card in Done up to date with a short list of finished work.

## Laptop memory and disk

This Mac has only 8 GB of RAM and little disk space. When you finish testing, close what you opened: iPhone simulator (`xcrun simctl shutdown all`, then quit the Simulator app), Android emulator (`adb emu kill`), and any dev server or Metro bundler you started. Before starting a simulator or emulator, check whether one is already running and reuse it. Don't leave anything running in the background.
