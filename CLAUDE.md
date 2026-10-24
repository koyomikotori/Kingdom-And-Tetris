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
- **M4 — done pending user review** (branch `m4/buildings-and-army`): `BuildingData` + `BuildRules` (barracks), `UnitData` + `RecruitmentRules` + `Army` (swordsman, spearman, archer needs 3 forest), food upkeep with desertion in `KingdomState.end_turn()` (returns a report dict), side-panel tabs with `BuildPanel` / `ArmyPanel`. See GDD §8.
- Next: **M5** — auto-battle (GDD §7): `BattleSimulator` producing an event list from `UnitData` stats, `BattlePresenter` replaying it, enemy waves on fixed turns.

Each milestone goes on its own branch (`mN/<topic>`); the user merges it into `main` on GitHub.
