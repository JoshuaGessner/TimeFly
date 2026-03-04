# TimeFly

An environment sync mod for BeamMP servers.
TimeFly keeps every player's day/night cycle in lock-step and lets admins
control time of day, fog, and gravity from the in-game chat.

---

## Features

| Feature | Description |
| --- | --- |
| **Day/night sync** | All players share the same time of day at all times |
| **Configurable day speed** | Choose how many real seconds equal one full in-game day |
| **Time freeze** | Admins can pause or resume the clock |
| **Manual time set** | Admins can jump to any time using `HH:MM` or a 0–1 value |
| **Fog control** | Admins can set fog density (0 = clear, 1 = pea-soup) |
| **Gravity control** | Admins can change world gravity (default −9.81 m/s²) |
| **Auto-sync on join** | Newly connected players are immediately caught up |

---

## Installation

1. Download `TimeFly.zip` from the [latest release](../../releases/latest).
1. Extract the zip into your BeamMP server's root folder.

    The archive mirrors the `Resources/` layout, so the files will land in the correct locations automatically:

    - `Resources/Server/TimeFlyS/main.lua`
    - `Resources/Server/TimeFlyS/config.lua`
    - `Resources/Client/TimeFly.zip` *(client mod — distributed to players automatically by BeamMP)*

1. Edit `Resources/Server/TimeFlyS/config.lua` to set your preferred defaults (see [Configuration](#configuration) below).
1. Restart the BeamMP server.

    You should see `[TimeFly] Loaded.` in the server log.

**Folder naming note:**
You can rename the server plugin folder (for example `Resources/Server/TimeFlyS`) as long as `main.lua` and `config.lua` stay together in that folder. The server script resolves `config.lua` relative to its own location.

---

## Configuration

`Resources/Server/TimeFlyS/config.lua`

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `syncInterval` | integer | `30` | How often (in seconds) to broadcast the current state to all players |
| `dayLength` | integer | `1200` | How many real-world seconds make up one full in-game day |
| `startTime` | float | `0.0` | Starting time of day (0.0 = noon, 0.5 = midnight — see [Time values](#time-values)) |
| `timeFrozen` | boolean | `false` | Start with the clock frozen |
| `fogDensity` | float | `0.0` | Starting fog density (0 = none, 1 = maximum) |
| `gravity` | float | `-9.81` | Starting gravity in m/s² |
| `adminList` | array | `{}` | List of player **display names** that may use admin commands |

**Example config:**

```lua
return {
    syncInterval = 30,
    dayLength = 600,
    startTime = 0.0,
    timeFrozen = false,
    fogDensity = 0.0,
    gravity = -9.81,
    adminList = {"YourUsername", "FriendUsername"},
}
```

---

## Admin chat commands

All commands are typed in the in-game BeamMP chat.

| Command | Who | Description |
| --- | --- | --- |
| `/timefly` | everyone | Show command help |
| `/time` | everyone | Display the current time |
| `/time HH:MM` | admin | Set time using 24-hour clock (e.g. `/time 06:30`) |
| `/time 0-1` | admin | Set time using a raw 0–1 value (e.g. `/time 0.75`) |
| `/freeze` | admin | Pause the clock |
| `/unfreeze` | admin | Resume the clock |
| `/dayspeed <secs>` | admin | Set day length in real seconds (e.g. `/dayspeed 300` = 5-minute days) |
| `/fog <0-1>` | admin | Set fog density (e.g. `/fog 0.4`) |
| `/gravity <value>` | admin | Set gravity in m/s² (e.g. `/gravity -1.6` for Moon-like gravity) |
| `/addadmin <name>` | admin | Grant admin rights to a player at runtime (change is saved to config) |
| `/removeadmin <name>` | admin | Revoke admin rights from a player at runtime (change is saved to config) |

---

## Time values

BeamNG.drive uses the following time-of-day convention:

| Value | Real time |
| --- | --- |
| `0.0` | 12:00 (noon) |
| `0.25` | 18:00 (6 PM) |
| `0.5` | 00:00 (midnight) |
| `0.75` | 06:00 (6 AM) |

---

## Repository structure

```text
Resources/
  Server/
    TimeFlyS/
      main.lua        ← BeamMP server-side Lua plugin
      config.lua      ← Server configuration
  Client/
    TimeFly/          ← Source for the client zip (see below)
      lua/ge/extensions/
        TimeFly.lua   ← BeamNG.drive client extension

TimeFly.zip           ← Release archive (extract into BeamMP server root)
```

The release `TimeFly.zip` contains:

```text
Resources/
  Server/
    TimeFlyS/
      main.lua
      config.lua
  Client/
    TimeFly.zip       ← Pre-built client archive for BeamMP auto-distribution
```

---

## License

MIT
