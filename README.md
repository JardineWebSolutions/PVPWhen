# PVPWhen

**Automatic Battleground & Arena queue addon for Turtle WoW (1.12.1)**

Written by **Suzqt | Solutions @ Nordraanar**

---

## What It Does

PVPWhen keeps you queued for your chosen Battlegrounds and Arenas automatically. Select which PvP modes you want, and the addon handles the rest — queueing on login, after leaving a match, and whenever your queue status changes.

## Features

- **Automatic Queuing** — Continuously re-queues for any checked Battlegrounds and Arenas.
- **Battleground Support** — Warsong Gulch, Arathi Basin, Alterac Valley, Thorn Gorge.
- **Arena Support** — Skirmish, Rated 2v2, Rated 3v3, Rated 5v5.
- **Persistent Settings** — Your checkbox selections are saved between sessions.
- **Party/Raid Awareness** — Will not auto-queue while you are in a party or raid group.
- **Draggable Minimap Icon** — Right-click and drag to reposition around the minimap.
- **Draggable Settings Panel** — Left-click and drag the panel to move it anywhere on screen.
- **Minimap Addon Compatibility** — Works with minimap icon merging addons like MinimapBag.

## Installation

- **Option A** — Add the GitHub repo directly to your launcher's addon list.
- **Option B** — Download and place the `PVPWhen` folder into your `Interface\AddOns` directory.

## Usage

### Opening the Settings Panel

- **Left-click** the minimap icon, or
- Type `/pvpwhen` in chat.

### Queueing

1. Open the settings panel.
2. Check the Battlegrounds and/or Arenas you want to queue for.
3. The addon will immediately begin queueing for your selections.
4. Checking a new box while already queued will add that mode to your queue.
5. Use the **Queue All** button at the bottom of the panel to manually re-queue for all checked modes.

### Minimap Icon

- **Left-click** — Toggle the settings panel.
- **Right-click drag** — Move the icon around the minimap edge.

## How It Works

PVPWhen uses the native Battleground and Arena queue APIs (`JoinBattlegroundQueue`, `JoinArenaQueue`) rather than simulating UI clicks, making it reliable and efficient. It processes one queue request at a time to avoid conflicts, and automatically suppresses the Battlefield confirmation frame during auto-queuing so it doesn't interrupt your gameplay.

## Saved Variables

Settings are stored in `PVPWhenDB` and persist across sessions. If you need to reset your settings, delete the `PVPWhenDB` entry from your `WTF\Account\<account>\SavedVariables\PVPWhen.lua` file.
