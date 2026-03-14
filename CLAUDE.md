# ClickCastCheatSheet

## What This Is

A World of Warcraft addon that displays a visual cheat sheet of the player's Click Cast bindings as spell icons on screen. It shows up to 15 icons in a compact cluster: 5 mouse buttons (Left, Right, Middle, Button4, Button5) x 3 modifier states (none, SHIFT, CTRL). Icons update automatically on spec change.

This is for WoW healers/players who use Blizzard's built-in Click Casting system and want a quick visual reminder of what spell is bound to each mouse button + modifier combo.

## How It Works

- **Single Lua file** (`ClickCastCheatSheet.lua`) — no XML, no external libs, no dependencies
- Reads click bindings at runtime via `C_ClickBindings.GetProfileInfo()`
- Resolves both direct spell bindings (type 1) and macro bindings (type 2, via `GetMacroSpell`)
- Creates icon frames parented to a movable container, with cooldown overlays
- Cooldowns are event-driven (`SPELL_UPDATE_COOLDOWN`), not polled
- Settings panel registered via `Settings.RegisterCanvasLayoutCategory`
- Position, scale, and debug mode saved per-character in `ClickCastCheatSheetDB`
- Auto-refreshes icons on spec change (`ACTIVE_TALENT_GROUP_CHANGED`)
- Slash command: `/cccs debug` (toggle debug), `/cccs reload` (refresh bindings)

## How to Test

This addon folder IS the live WoW addon directory. To test changes:
1. Edit the `.lua` file
2. In WoW: `/reload`
3. Check for errors in chat or with `/cccs debug`
4. Open settings: ESC > Options > AddOns > ClickCastCheatSheet

## Workflow: Versioning & Releases

When work is completed and merged to `main`, always:
1. Tag the commit with a version increment using `git tag X.Y.Z` (no `v` prefix)
2. Push the tag with `git push origin X.Y.Z`
3. Use semantic versioning:
   - **Patch** (1.2.X): Bug fixes, small tweaks, layout adjustments
   - **Minor** (1.X.0): New features, new settings, new event handling
   - **Major** (X.0.0): Breaking changes, major rewrites, architecture changes
4. Check existing tags with `git tag --sort=-v:refname | head -5` before incrementing

## WoW API Lookup

Two MCP servers are configured in `.mcp.json` for WoW API documentation:

### wow-api (primary — structured data)
Use this FIRST for any API questions. Tools:
- `lookup_api(name)` — function details by exact/partial name
- `search_api(query)` — full-text search across API names and descriptions
- `get_namespace(name)` — all functions in a C_ namespace
- `get_widget_methods(widget_type)` — UI widget class methods
- `get_enum(name)` — enum definitions
- `get_event(name)` — event payload parameters
- `list_deprecated(filter?)` — deprecated functions with replacements

### wow-dev (secondary — wiki content & strings)
Use when structured data isn't enough:
- Fuzzy search of global API names
- Fetches Warcraft Wiki page content for detailed documentation
- Global string search across locales

### When to use what
- **Quick API check** (function signature, event args): `wow-api` tools
- **Behavioral questions** (when does X event fire, how does Y interact with Z): `wow-dev` wiki fetch
- **Deprecation check**: `wow-api` `list_deprecated`
- **Last resort**: Web search warcraft.wiki.gg

## Project Structure

- Single-file Lua addon: `ClickCastCheatSheet.lua`
- TOC file uses `@project-version@` and `@project-author@` tokens (CurseForge BigWigs packager)
- `pkgmeta.yaml` for CurseForge packaging config
- SavedVariables: `ClickCastCheatSheetDB` (per-character)

## WoW API Notes

- Target client: WoW Retail (Midnight / 12.x)
- `OptionsSliderTemplate` is deprecated but still works in 12.0 — use it until it breaks
- Cooldown values (`startTime`, `duration`, `modRate`) are secret values in 12.0 — use `pcall` when passing to `SetCooldown`
- `isOnGCD` field on `SpellCooldownInfo` is reliably accessible (non-secret)
- `ACTIVE_TALENT_GROUP_CHANGED` is the most reliable event for detecting player spec changes
- Do NOT assume APIs are removed without checking via MCP tools or warcraft.wiki.gg first
