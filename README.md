# ClickCastCheatSheet

Displays up to 15 spell icons in a compact, clustered layout:

* 5 primary icons for mouse buttons (Left, Right, Middle, Button4, Button5)
* 5 SHIFT modifier icons (above each primary)
* 5 CTRL modifier icons (below each primary)

Reads the player's click bindings at runtime using the Click Bindings API (supports direct spells and macro-based spell lookups).

Movable, persistent container:

* The whole icon group is draggable with the mouse.
* Position is saved per-character via `ClickCastCheatSheetDB` and restored on login.

Lightweight, Lua-only implementation:

* No external assets required; uses WoW's spell icon textures (falls back to a question mark icon if missing).
* Minimal configuration constants at the top of `ClickCastCheatSheet.lua` (icon sizes, spacing, zoom, and screen offset).

Clean visual presentation:

* Each icon is framed with a thin border to improve readability.
* Icons are zoomed slightly into their center for better visibility (`ZOOM_MIN_COORD` / `ZOOM_MAX_COORD`).

Safe initialization:

* Waits for `PLAYER_LOGIN` and required WoW APIs (e.g., `C_Spell`, `C_ClickBindings`) before constructing UI.
* Uses protected initialization (pcall) to avoid breaking game load if something is unavailable.

Simple, extensible configuration:

* `SPELL_CONFIG` and `BASE_ANCHORS` tables let you change which mouse buttons, modifiers, positions, and sizes are shown without changing core logic.

Fallback handling:

* Handles both direct spell bindings and macro bindings (resolves macro spell IDs when needed).
