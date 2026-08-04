# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Godot **4.7** project named "Saint". At the time of writing there are no scripts (`.gd`), scenes (`.tscn`), or resources beyond the default icon — the repo is a freshly-initialized project shell.

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
