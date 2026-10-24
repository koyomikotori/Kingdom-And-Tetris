# Kingdom And Tetris — Project Rules

Single-player, turn-based 2D pixel-art kingdom strategy game. Godot 4.5, GDScript.
The full design lives in `docs/GDD.md` (Vietnamese). Read it before designing a new system.

The user is a beginner-to-intermediate developer working with AI assistance. Talk to them in Vietnamese; code, identifiers and code comments are in English.

## Running

- Godot: `C:\Users\MyPC\Desktop\Godot_v4.5.1-stable_win64_console.exe` (console build, prints to stdout).
- Re-import after adding scripts with a new `class_name`: `<godot> --headless --path . --import`
- Tests: `<godot> --headless --path . -s res://tests/run_tests.gd` (exit code 0 = all passed).
- Visual check: `<godot> --path . --write-movie <scratch>/frame.png --quit-after 5` then look at the PNG.

## Architecture

- `scripts/<system>/*_data.gd`, `board_data.gd` etc.: pure logic, `RefCounted`, no Node dependency, unit-tested headless.
- `*_view.gd`: Nodes that draw state. They read data and emit input signals; they never mutate game state.
- Scene scripts (e.g. `kingdom.gd`) wire data, views and UI together.
- Static content is `Resource` files under `data/` loaded by directory (see `TerrainLibrary`). Adding content should mean adding a `.tres`, not adding `if` branches.
- Grid coordinates: `Vector2i(x, y)`, x right, y down, `(0,0)` top-left. Mouse ↔ grid conversion only through `BoardView.local_to_cell` / `cell_to_local`.
- Save files (later): JSON with `save_version`; never `ResourceSaver` for saves.
- Don't name classes after Godot built-ins (`TileData`, `TileMap`, …).

## Rules

1. Godot 4 APIs only.
2. Invalid actions must not modify state or consume resources/pieces.
3. Battle simulation stays independent from animation: simulator outputs an event list, presenter replays it.
4. No third-party addons without discussing it first.
5. Stay inside the requested milestone; don't rewrite working systems outside scope.
6. No placeholder buttons that look functional but do nothing.
7. Add or update tests in `tests/` for every logic change, and run them.
8. Never claim something works without running it.

## Current milestone

- **M1 — done:** 12×12 board, 2×2 castle, camera zoom/pan, hover cell info.
- **M2 — done:** shapes in `data/pieces/`, each rotation is its own draw (player cannot rotate), hand of 3, ghost preview, connection rule, overwrite replaces terrain and key cell, castle protected. See GDD §4. Playtested: OK.
- **M3 — done:** `KingdomState` owns board/hand/stockpile/turn; terrain `yields` + key cell ×2 (`Economy`), `Stockpile` with all-or-nothing `spend`, end turn collects yield and deals a fresh hand (unplaced pieces discarded), resource bar, yield-change preview. See GDD §5.
- **M4 — done:** `BuildingData` + `BuildRules` (barracks), `UnitData` + `RecruitmentRules` + `Army` (swordsman, spearman, archer needs 3 forest), food upkeep with desertion in `KingdomState.end_turn()` (returns a report dict), side-panel tabs with `BuildPanel` / `ArmyPanel`. See GDD §8.
- **M5 — done, playtested OK** (branch `m5/battle-and-bandits`): phase-based `BattleSimulator` (guns → arrows → melee rounds, rows, rout at 40%) producing a `BattleRecord` with per-step HP/alive snapshots; bandit raids (`RaidData`, `RaidSystem`, enemy units in `data/enemy_units/`) rolled at the start of a turn; watchtower with building upkeep (`buildings_supplied`); `BattleReport` modal. See GDD §7.
- **M6 — done pending user review** (branch `m6/combat-v2`, based on `m5/battle-and-bandits`): one recruitment = one squad (`Army.Squad`, `UnitData.squad_size`); v2 stats (melee attack/defense, armor, charge, morale, range attack, reload); `BattleSimulator` is now tick-based and steppable (`new` + `step()` / `simulate()`, `retreat(side)`), with morale breaking at 0, one gun volley, timed arrow volleys; `BattleRecord` holds events + snapshots; `RaidSystem.apply_outcome` (loser: broken squads lost, others keep 50%). Squad management: capacity = 2 + 4 per barracks (max 3 barracks), free 25% replenishment per turn with a barracks, disband (two-click confirm in `ArmyPanel`). Balance numbers in GDD §8.
- Next: **M7** — cinematic battle screen driving `BattleSimulator.step()` (GDD §7.5): pause, speed-up, retreat button, then the existing `BattleReport`. Raids currently auto-resolve with `RaidSystem.resolve`.
- Later: M8 world map + clans, M9 invasions / conquest, M10 save/load, M11 events + heroes, M12 art and release (GDD §11).

Each milestone goes on its own branch (`mN/<topic>`); the user merges it into `main` on GitHub.
