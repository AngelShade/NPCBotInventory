# NPCBotManager Changelog

## 1.22

- **Full Combat Usability OVERHAUL**:
  - Converted the bot list selector buttons and navigation arrows (Prev/Next page) from `SecureActionButtonTemplate` to standard, non-secure buttons.
  - This completely bypasses Blizzard's strict combat lockdown rules that restrict moving, hiding, or resizing secure frames in combat.
  - Resolved the critical Lua crash error when opening the interface, searching, sorting, or scrolling the bot list during combat.
  - You can now inspect gear, view templates, check stats, navigate, and drag-and-drop items to equip/unequip in combat without any interface lockups.
- **Symmetric Character Panel Button Layout**:
  - Removed the custom button-alignment conflict code between `NPCBotManager` and `NetherBot` addons.
  - Decoupled both buttons so that `NPCBotManager` anchors directly below the bottom-left Wrist slot (`CharacterWristSlot`), while `NetherBot` anchors below the bottom-right Trinket 2 slot (`CharacterTrinket1Slot`).

## 1.21

- Fixed client-side crash in `HandleItemDrop` where the local variable `type` shadowed the global `type()` function, resolving issues with slot greyouts and missing 3D models.
- Implemented robust nil-safety checks when drawing and redrawing equipment slots to prevent errors when items are missing.
- Fixed server-side crash on `string.format` by adding default values (`or 0` and `or 0.0`) to character database stats query outputs.
- Removed a duplicate, malformed `OnBotManagerCommand` function from the server script that was causing syntax parsing failures.
- Fixed an asynchronous database stats refresh race condition by extending the update interval and increasing the retry cycle on equip/unequip events to guarantee real-time stat synchronization in the UI.
- Fixed core NPCBot C++ engine stats syncing by forcing the bot to immediately write updated stats (`_saveStats()`) to the database table `characters_npcbot_stats` upon recalculation in `SetStats()`. This guarantees real-time synchronization between the database and active gameplay stats without write-latency lag.
- Fixed dismissed bots showing up in the UI list even after `/reload` by implementing a `C;CLEAR` network packet protocol. The server now signals the client to clear all cached bot records from the local SavedVariables database at the start of a refresh, guaranteeing that dismissed bots are immediately and permanently removed.



## 1.2

- Added visible minimap launcher with tooltip, drag support, and `/bm minimap` recovery command.
- Added Interface > AddOns options panel for minimap visibility and window layout reset.
- Restored `/bm` as the reliable primary open/close command.
- Added `/bm options` and `/bm config` commands for addon settings.
- Improved Bot Manager window layout, docking, resizing, and Escape close behavior.
- Added bot roles and talent display to the 3D model identity area with stronger coloring.
- Added group dropdown modes for Class, Name, Roles, and Talent.
- Fixed loot distribution item color tags showing a stray `|c`.
- Tightened recommendation scoring so no-stat/proc-only gear is no longer treated as a role upgrade.
- Added recommendation explanation tooltips with target, slot, score comparison, and role/talent reason.
- Updated addon metadata to NPCBotManager by Chibisan with credits in notes.
