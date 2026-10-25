# Kingdom And Tetris — Project Rules

Single-player, turn-based 2D pixel-art kingdom strategy game. Godot 4.5, GDScript.
The full design lives in `docs/GDD.md` (Vietnamese). Read it before designing a new system.

The user is a beginner-to-intermediate developer working with AI assistance. Talk to them in Vietnamese; code, identifiers and code comments are in English.

## Running

- Godot: `C:\Users\MyPC\Desktop\Godot_v4.5.1-stable_win64_console.exe` (console build, prints to stdout).
- Re-import after adding scripts with a new `class_name`: `<godot> --headless --path . --import`
- Tests: `<godot> --headless --path . -s res://tests/run_tests.gd` (exit code 0 = all passed).
- Visual check: `<godot> --path . --write-movie <scratch>/frame.png --quit-after 5` then look at the PNG.

## Git

- GitHub repo: `koyomikotori/KingdomTiles-RiseOfRealms`. Push as `koyomikotori` (the remote URL carries the username).
- Commit author is set in this repo's `.git/config` (`koyomikotori`). Don't change the global git identity; it belongs to another account used for other projects.
- One branch per milestone (`mN/<topic>`); the user merges it into `main` with a pull request.

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
- **M7 — done**: `BattleScreen` (built in code, 10/80/10 with `BattleView` split 18/44/18) plays a `BattleSimulator` through `BattlePlayback` (speed x1/x2/x4, pause, skip, retreat with two-click confirm), `BattleInfoPanel` per side; raids now come back from `end_turn()` as `pending_raid` and are applied with `KingdomState.finish_raid(record)` after the screen closes. Window opens at 1920×1080 over a 1280×720 design size (`aspect = expand`).
- **M8 — done**: `ClanData` (6 clans in `data/clans/`, 4 neighbours with a board direction + 2 distant), `Diplomacy` (relation −100..100 with 5 tiers, drift to base per turn, gifts with a +15/turn cap, one-off trades priced by value/relation/personality/surplus/deficit with a 40-value/turn capacity, long-term trade agreements: `propose` rolls `agreement_chance` with `KingdomState.rng`, `run_agreements` at end of turn, `cancel_agreement` −20), `WorldMapScreen` = `WorldMapView` (tap a clan) + `ClanPanel`; opened by the "Ngoại giao" top-bar button. Resource `trade_value` in `data/resources/`. See GDD §9.
- **M9 — done** (branch `m9/war`): `Wars` (per-clan `Front`: at war, strength that regrows, truce, annexed, direction that can change), player and AI war declarations, invasions via `end_turn()` → `pending_invasion` → `finish_invasion` (lose up to 6 cells on the clan's edge with `BoardData.lose_edge_cells`), player attacks via `start_attack`/`finish_attack` (loot, or lose the army + 25% compensation), peace talks, annexation below 15% strength (`BoardData.expand` + `resized` signal, distant clans become neighbours). Shared loss rules in `BattleOutcome`. Clan wariness: `KingdomState.get_threat()` → `Diplomacy.threat` lowers `target_relation`; aggressive clans may declare war when Tense; lost invasions plunder 40%. `BattleReport.show_battle` is the generic report. See GDD §9.6.
- **M9b — done pending user review** (branch `m9b/alliances`): `Alliances` (owned by `KingdomState`; treaty state on `Diplomacy.ClanState`: `alliance_turns`, `pact_turns`, `alliance_cooldown`). Relation is no longer stored: `ClanState.relation` is a getter summing lasting factors (base, −`wariness` which ramps toward `Diplomacy.wariness_target`, +15 agreement, +30 alliance, +10 pact) and `memories` (per-source recent events, `Diplomacy.MEMORY_*`, each fading by `DRIFT_PER_TURN`); `change_relation(clan, amount, source)` moves the shown value; `relation_factors()` feeds the "Chi tiết quan hệ" toggle/tooltip in `ClanPanel`; agreements live on `ClanState.agreement`. Alliance at Close with an acceptance chance, 20 turns (renewable in the last 5), breaks below Friendly, cancel −30; non-aggression pact at Friendly, 10 turns, blocks AI war declarations. Lent soldiers: `BattleSide.Unit.ally` (the lending `ClanData`), added by `Wars.add_clan_units(..., lent)`; `KingdomState.create_kingdom_side(enemy_clan)` adds allies (30% strength) to raids/invasions/attacks, `start_attack` adds the target's `ClanData.friends`; `Alliances.apply_battle` takes lent losses from each clan's strength (+5/−10 relation for allies). `BattleOutcome` skips lent units in the kingdom's/target's own losses. Declaring war: friends −15, breaking an alliance/pact −20/−10 extra for everyone (`Wars.declare_penalty`). Allied units get a banner tint + pennant in `BattleView`. See GDD §9.7.
- **M9c — done pending user review** (branch `m9c/diplomacy-ui`): Shogun 2 style diplomacy UI. `ClanPanel` is now a summary + one command button per action (disabled with the reason underneath; peaceful actions hidden during a war); each opens a modal `DiplomacyDialog` subclass in `scripts/diplomacy/dialogs/` (`TradeDialog`, `GiftDialog`, `AgreementDialog`, `AllianceDialog`, `PactDialog`, `DeclareWarDialog`, `AttackDialog` → `attack_confirmed`, `PeaceDialog`) added to `ClanPanel.dialog_host` (the world map screen). The base builds the frame (title, optional stockpile line, `_build`/`_build_actions`/`_refresh` hooks, status line, Esc to close). See GDD §9.1.
- Known issue: since M9 the headless test run prints "ObjectDB instances leaked at exit" (GDScript resources held by a script reference cycle at shutdown). Harmless for gameplay; not yet tracked down.
- Later: M10 save/load, M11 events + heroes, M12 touch + APK, M13 art and release (GDD §11).

Each milestone goes on its own branch (`mN/<topic>`); the user merges it into `main` on GitHub.
