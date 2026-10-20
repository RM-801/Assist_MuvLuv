# DMM automation fork

This fork extends LaunchLee's Assist_MuvLuv for the DMM desktop game. It is a work in progress; the upstream README describes the original version.

## Setup

Install AutoIt 3 (64-bit) and extract the entire repository, including the bundled upstream OpenCV libraries. Run `Game_MuvLuv.au3` using the 64-bit AutoIt interpreter from the repository directory. Windows OCR with Japanese and English recognition languages is needed for area selection and shop counters. Keep the game visible and unobstructed while automation runs; screen capture does not include the operating-system cursor, but other windows can cover the game.

The UI templates use the original 1264 x 712 window reference. Scaling is supported, but a substantially different layout may require new templates. Refer to the upstream README for window sizing.

`Data/MazeShop.ini` is generated on first launch from `Data/MazeShop.defaults.ini`. It stores local settings and observations and is excluded from Git. No player progress or purchase history is shipped. Keep the defaults file with the application, including on a fresh clone.

## Added behavior

- Main quests: wait for stage-unlock animations, retry start actions, and enter scenario stages.
- Story scenes: expand the controls, enable fast-forward when inactive, choose the first dialogue option, and handle reward and tap-to-continue screens. No held Ctrl key is used.
- Maze: target-area input, faster wheel navigation, and preference for visible diamond rewards, known ore relics and the ore-pickup event.
- Final shop: selected-tab recognition, level and area-cap observations, daily counters with a 05:00 JST reset, selectable skill-report attribute priority, and a stop check for exhausted purchases and upgrades.
- OpenCV: safer resizing of captured images and templates.

## Limits and verification

This is an experimental snapshot, not a fully validated release. End-to-end shop purchasing still needs further live validation, including reported cases where upgrades are missed. The ore selector recognizes specific templates; it does not rank every multiplier or percentage bonus or optimize the entire route graph. Some area numbers depend on OCR; direct templates currently include 100, 130 and 190. The 190 template avoids the observed Windows OCR misreading of its stylized digits. Unknown UI states can require manual intervention.

The offline test `Tests/ShopDetails.au3` covers fresh cache initialization, preservation of existing settings, the JST reset boundary, daily remaining counters, per-area caps, invalidation after purchase attempts, and attribute mapping. Run it with the 64-bit AutoIt interpreter; it does not operate the game. A zero exit code indicates success. Run Au3Check on `Game_MuvLuv.au3` for syntax checking.

The upstream license and notices are preserved. Game UI crops are recognition templates from the game, as in the upstream project.

The offline test `Tests/MazeAreaTemplates.au3` uses a saved area-number crop to check 190 at three scales, distinguish 100/130, and reject unrelated or conflicting matches. It does not operate the game.
