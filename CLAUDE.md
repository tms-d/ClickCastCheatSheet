# ClickCastCheatSheet - Project Instructions

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
