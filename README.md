# NPCBotInventory — Bot Manager for AzerothCore

> A full in-game Bot Manager UI and server-side extension for [AzerothCore](https://www.azerothcore.org/) with [NPCBots](https://github.com/trickerer/AzerothCore-wotlk-with-NPCBots).  
> **Author:** AngelShade (Chibisan) | **Addon Version:** 1.22 | **Core:** WotLK 3.3.5a

---

## What This Is

This repository contains both the **client-side WoW addon** and the **server-side C++ changes** needed to run the NPCBot Manager on your AzerothCore private server.

It is forked from [Day36512/AzerothCore-wotlk-with-NPCBots](https://github.com/Day36512/AzerothCore-wotlk-with-NPCBots) which itself builds on [trickerer's NPCBots](https://github.com/trickerer/AzerothCore-wotlk-with-NPCBots) and the [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) core.

---

## Features

- 📦 **Full in-game equipment manager** — drag and drop gear directly onto your bots
- 🧍 **Real-time 3D bot model preview** — see your bot wearing its gear live in the UI
- 📊 **Live stat display** — HP, mana, role, talent spec per bot
- ⭐ **Gear recommendation engine** — scored suggestions with tooltip explanations
- ⚔️ **Full combat usability** — open, sort, scroll and equip during combat with no lockouts
- 🗺️ **Minimap launcher** — with `/bm minimap` recovery command
- 👥 **Group bots by** Class, Name, Role, or Talent spec

---

## Repository Structure

```
.
├── addons/
│   └── NPCBotInventory/          ← WoW client addon (install this)
│       ├── NPCBotInventory.lua   ← Main bot manager UI
│       ├── BotManagerUI_Editor.lua
│       ├── NPCBotInventory.toc
│       └── CHANGELOG.md
└── src/server/game/AI/NpcBots/   ← Server-side changes
    ├── bot_ai.cpp / bot_ai.h     ← Equip logic, item restrictions
    └── botcommands.cpp           ← .npcbot equip / updatevisual commands
```

---

## Client Addon Installation

1. Copy the `addons/NPCBotInventory/` folder into:
   ```
   World of Warcraft\Interface\AddOns\NPCBotInventory\
   ```
2. Launch WoW, go to **AddOns** on the character select screen and enable **NPCBotManager**.
3. In-game, type `/bm` to open the Bot Manager window.

### Commands
| Command | Description |
|---|---|
| `/bm` | Open/close Bot Manager |
| `/bm minimap` | Restore the minimap button if lost |
| `/bm options` or `/bm config` | Open addon settings |

---

## Server Setup

This repo is a fork of AzerothCore + NPCBots with custom changes to support the addon's features.

### Requirements
- [AzerothCore](https://www.azerothcore.org/wiki/installation) (WotLK 3.3.5a)
- [NPCBots module](https://github.com/trickerer/AzerothCore-wotlk-with-NPCBots)

### Building
Follow the standard [AzerothCore compilation guide](https://www.azerothcore.org/wiki/compilation).  
This fork's custom changes are in `src/server/game/AI/NpcBots/` and are already integrated — no extra patching needed.

### Key Server Changes
- **`botcommands.cpp`** — `.npcbot equip` with downgrade support, item restrictions, and `updatevisual` command
- **`bot_ai.h`** — Item restriction flags for the equip system
- **`bot_ai.cpp`** — Core equip/unequip logic synced with the addon's network protocol

---

## Comparing Changes vs Upstream

To see exactly what this fork changes vs Day36512's base:  
[`AngelShade/NPCBotInventory` vs `Day36512/AzerothCore-wotlk-with-NPCBots`](https://github.com/AngelShade/NPCBotInventory/compare/npcbots_3.3.5...Day36512:AzerothCore-wotlk-with-NPCBots:npcbots_3.3.5)

---

## Changelog

See [`addons/NPCBotInventory/CHANGELOG.md`](addons/NPCBotInventory/CHANGELOG.md) for full addon version history.

---

## Credits

- **AngelShade (Chibisan)** — NPCBotInventory addon & server-side bot manager extensions
- **Day36512** — NPCBots AzerothCore fork base
- **trickerer** — Original NPCBots implementation
- **Belgarth & Dinkledork** — Legendary mentions in the addon
- **AzerothCore team** — The WotLK server core
