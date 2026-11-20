# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Godot **4.7** project named "Saint": a 2D real-time small-squad battle game (title → prep → battle → result, 5-stage campaign). All art is placeholder shapes. `todo.md` is the roadmap.

## Architecture

Data lives in three places; scenes read from them rather than hard-coding values.

- `scripts/UnitTypes.gd` — single source of truth for unit types (label, shape, preferred row, projectile/kiting flags, price, per-team stats). **Add a unit type by adding one entry to `TYPES` and its id to `ORDER`**; battle, stage placement, hire list, roster and save validation all read from it. Do not branch on type ids elsewhere.
- `scripts/Stages.gd` — stage data (battlefield rect, reward, `player_<row>` spawn slots, enemies) plus helpers (`get_stage`, `deploy_cap`, `assign_slots`).
- `scripts/GameState.gd` (autoload) — campaign state: stage index, money, roster, save/load, and the campaign rules in `conclude_battle()` (reward, permanent losses, stage advance, game over, save).
- `scripts/Scenes.gd` — scene paths; change scenes with `Scenes.go(get_tree(), Scenes.PREP)`.

Battle scene (`scenes/Main.tscn`) is split by responsibility:

- `Main.gd` — stage load, spawning, countdown, win/lose detection.
- `SelectionController.gd` — selection, squads, move/stop/attack-move input. Talks to `Main` only through `enabled`, `restore_squad_member()`, `forget_unit()` and `selection_changed`.
- `ResultPanel.gd` — result overlay; emits `primary_pressed` / `secondary_pressed`.
- `Unit.gd` / `Projectile.gd` — per-unit AI, combat, movement. Projectiles are added to the `Projectiles` node, units to `Units`.

UI font (Korean-capable system font) comes from the project-wide theme `ui/theme.tres` (`gui/theme/custom`); do not add per-node font overrides.

## Running / editing

- Open the project by pointing the Godot 4.7 editor at `project.godot` (or `godot --path . -e` from this directory).
- Run the main scene with `godot --path .` once a main scene is configured in `project.godot` under `[application] run/main_scene`.
- Headless / CI run: `godot --headless --path . --quit` (useful for import-only passes).

There is no build system, test runner, or lint tool configured — Godot handles builds through its export system, invoked from the editor or via `godot --headless --export-release "<preset>" <output>` once export presets exist.

## Project-wide settings that affect code

From `project.godot` — these are non-default choices worth preserving:

- **Renderer: `gl_compatibility`** (desktop and mobile). Code that assumes Forward+ / Vulkan-only features (e.g. certain `RenderingDevice` compute paths, SDFGI, volumetric fog) will not work. Prefer techniques compatible with the GL Compatibility backend.
- **3D physics: Jolt** (`3d/physics_engine="Jolt Physics"`). Godot Physics quirks do not apply; Jolt-specific behavior (contact reporting, layer/mask semantics) does.
- **Windows rendering driver: D3D12**.
- **Stretch: `canvas_items` + `expand`** — UI is designed to scale rather than letterbox; anchor/margin choices should assume a variable viewport aspect ratio.

## Repo conventions

- `.gitattributes` enforces `eol=lf` on all text files.
- `.editorconfig` sets UTF-8.
- `.godot/` and `/android/` are gitignored (editor cache and Android export template output — never commit).
