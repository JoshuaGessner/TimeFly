# TimeFly
An environment sync mod for BeamMP servers.  
TimeFly keeps every player's day/night cycle in lock-step and lets admins
control time of day, fog, and gravity from the in-game chat.

---

## Features

| Feature | Description |
|---|---|
| **Day/night sync** | All players share the same time of day at all times |
| **Configurable day speed** | Choose how many real seconds equal one full in-game day |
| **Time freeze** | Admins can pause or resume the clock |
| **Manual time set** | Admins can jump to any time using `HH:MM` or a 0–1 value |
| **Fog control** | Admins can set fog density (0 = clear, 1 = pea-soup) |
| **Gravity control** | Admins can change world gravity (default −9.81 m/s²) |
| **Auto-sync on join** | Newly connected players are immediately caught up |

---

## Installation

### Server side

1. Copy `Resources/Server/TimeFly/` into your BeamMP server's `Resources/Server/` folder.
2. Edit `Resources/Server/TimeFly/config.json` to set your preferred defaults
   (see [Configuration](#configuration) below).
3. Restart the BeamMP server.  
   You should see `[TimeFly] Loaded.` in the server log.

### Client side

BeamMP automatically distributes the client mod to every connecting player.

1. Copy `Resources/Client/TimeFly/` into your BeamMP server's `Resources/Client/` folder.
2. No client-side installation is required by players.

> **Tip — packaging as a zip**  
> Some BeamMP server versions require the client folder to be a `.zip` archive.
> If automatic distribution does not work, zip the `Resources/Client/TimeFly/`
> folder (keeping the internal path `lua/ge/extensions/BeamMP/TimeFly.lua`)
> and place the resulting `TimeFly.zip` file in `Resources/Client/`.

---

## Configuration

`Resources/Server/TimeFly/config.json`

| Key | Type | Default | Description |
|---|---|---|---|
| `syncInterval` | integer | `30` | How often (in seconds) to broadcast the current state to all players |
| `dayLength` | integer | `1200` | How many real-world seconds make up one full in-game day |
| `startTime` | float | `0.0` | Starting time of day (0.0 = noon, 0.5 = midnight — see [Time values](#time-values)) |
| `timeFrozen` | boolean | `false` | Start with the clock frozen |
| `fogDensity` | float | `0.0` | Starting fog density (0 = none, 1 = maximum) |
| `gravity` | float | `-9.81` | Starting gravity in m/s² |
| `adminList` | array | `[]` | List of player **display names** that may use admin commands |

**Example config:**

```json
{
    "syncInterval": 30,
    "dayLength": 600,
    "startTime": 0.0,
    "timeFrozen": false,
    "fogDensity": 0.0,
    "gravity": -9.81,
    "adminList": ["YourUsername", "FriendUsername"]
}
```

---

## Admin chat commands

All commands are typed in the in-game BeamMP chat.

| Command | Who | Description |
|---|---|---|
| `/timefly` | everyone | Show command help |
| `/time` | everyone | Display the current time |
| `/time HH:MM` | admin | Set time using 24-hour clock (e.g. `/time 06:30`) |
| `/time 0-1` | admin | Set time using a raw 0–1 value (e.g. `/time 0.75`) |
| `/freeze` | admin | Pause the clock |
| `/unfreeze` | admin | Resume the clock |
| `/dayspeed <secs>` | admin | Set day length in real seconds (e.g. `/dayspeed 300` = 5-minute days) |
| `/fog <0-1>` | admin | Set fog density (e.g. `/fog 0.4`) |
| `/gravity <value>` | admin | Set gravity in m/s² (e.g. `/gravity -1.6` for Moon-like gravity) |

---

## Time values

BeamNG.drive uses the following time-of-day convention:

| Value | Real time |
|---|---|
| `0.0` | 12:00 (noon) |
| `0.25` | 18:00 (6 PM) |
| `0.5` | 00:00 (midnight) |
| `0.75` | 06:00 (6 AM) |

---

## Repository structure

```
Resources/
  Server/
    TimeFly/
      main.lua        ← BeamMP server-side Lua plugin
      config.json     ← Server configuration
  Client/
    TimeFly/          ← Distributed to clients by BeamMP automatically
      lua/ge/extensions/BeamMP/
        TimeFly.lua   ← BeamNG.drive client extension
```

---

## License

MIT
