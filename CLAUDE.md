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

**M1 — done pending user review:** 12×12 board, 2×2 castle, camera zoom/pan, hover cell info.
Next: **M2** — land pieces (data, rotation, ghost preview, connection rule, overwrite rule, key cells). See GDD §4.
