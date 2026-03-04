# TimeFly Build Bible

This document is the source of truth for how TimeFly is built, tested, released, and extended.

## 1) Project Mission

TimeFly is a BeamMP environment sync mod that keeps all players on the same:

- time of day
- fog density
- gravity

The server is authoritative. Clients only apply state received from the server.

## 2) Current Repository Layout

- `Resources/Server/TimeFly/main.lua` — BeamMP server plugin (authority + admin chat commands)
- `Resources/Server/TimeFly/config.lua` — runtime defaults and admin list
- `Resources/Client/TimeFly/lua/ge/extensions/TimeFly.lua` — BeamNG client extension that applies incoming state
- `.github/workflows/release.yml` — CI release packaging + GitHub Release publishing
- `README.md` — user-facing install/config/commands

## 3) Runtime Architecture (As Implemented)

### Server responsibilities

`main.lua` currently:

1. Loads `config.lua` on startup.
1. Initializes `timeState` (`time`, `dayLength`, `frozen`, `fogDensity`, `gravity`).
1. Registers events:
   - `onPlayerJoining` -> sync joining player
   - `onChatMessage` -> parse commands
   - timer `TimeFly_tick` every 1000 ms -> tick clock and periodic sync
1. Broadcasts state via `MP.TriggerClientEvent(playerID, "TimeFly_sync", payloadString)`.

### Client responsibilities

`TimeFly.lua` currently:

1. Listens for `TimeFly_sync`.
1. Decodes payload.
1. If mission/map is active, applies state immediately.
1. If mission/map is not active, caches state and applies on mission start.
1. Applies values through BeamNG APIs:
   - time/day speed/freeze via `core_environment.setTimeOfDay`
   - fog via `core_environment.setFog` (fallback to `scenetree.tod`)
   - gravity via `core_environment.setGravity` (fallback to `be:setGravity`)

## 4) Configuration Contract

`config.lua` keys currently used by server code:

- `syncInterval` (seconds, default 30)
- `dayLength` (seconds per in-game day, default 1200)
- `startTime` (0.0-1.0, default 0.0)
- `timeFrozen` (bool, default false)
- `fogDensity` (0.0-1.0, default 0.0)
- `gravity` (number, default -9.81)
- `adminList` (array of exact player display names)

Important behavior:

- Runtime admin changes (`/addadmin`, `/removeadmin`) are persisted back to `config.lua`.
- Admin checks are name-based, not BeamMP account-ID-based.

## 5) Chat Command Surface (Current)

User:

- `/timefly`
- `/time`

Admin:

- `/time HH:MM`
- `/time 0-1`
- `/freeze`
- `/unfreeze`
- `/dayspeed <secs>`
- `/fog <0-1>`
- `/gravity <value>`
- `/addadmin <name>`
- `/removeadmin <name>`

## 6) Build + Packaging Rules

### Local packaging (manual)

1. Build client zip from source:

```sh
cd Resources/Client/TimeFly
zip -r ../TimeFly_client.zip lua/ scripts/
```

1. Build final server install archive:

```sh
mkdir -p release_build/Resources/Server/TimeFly
mkdir -p release_build/Resources/Client
cp Resources/Server/TimeFly/main.lua release_build/Resources/Server/TimeFly/
cp Resources/Server/TimeFly/config.lua release_build/Resources/Server/TimeFly/
cp Resources/Client/TimeFly_client.zip release_build/Resources/Client/TimeFly.zip
cd release_build
zip -r ../TimeFly.zip Resources/
```

Output: `TimeFly.zip` (extract into BeamMP server root).

### CI/CD release flow

GitHub Action in `.github/workflows/release.yml`:

- Trigger: tag push matching `v*` or manual dispatch
- Builds both zip artifacts
- Publishes `TimeFly.zip` to GitHub Releases

Release policy:

- Use semver-like tags (`v1.0.0`, `v1.1.0`, `v1.1.1`)
- Tag should point at a commit where README and config defaults are accurate

## 7) Dev Environment + Source Control Guardrails

- Never commit machine-local files.
- `.gitignore` intentionally ignores local editor/macOS artifacts and generated archives.
- `.gitattributes` normalizes line endings to reduce cross-platform diffs.
- Keep generated artifacts (`TimeFly.zip`, `Resources/Client/TimeFly_client.zip`, `release_build/`) out of commits unless intentionally needed.

## 8) Coding Standards for This Repo

### Lua style

- Prefer explicit, descriptive local names.
- Keep server authoritative; avoid client-side decision logic for shared state.
- Treat BeamMP/BeamNG API calls as failure-prone; use guarded fallbacks where practical.
- Preserve backward compatibility for existing commands/config keys unless versioning changes are planned.

### Command changes

When adding or changing commands, update all of:

1. command handling in server `main.lua`
1. server help text (`/timefly` output)
1. `README.md` command table
1. this Build Bible (if workflow/contract changes)

### Config changes

When adding config keys, update all of:

1. defaults in `loadConfig()`
1. runtime state initialization in `initState()`
1. `config.lua` checked-in defaults
1. README config table
1. migration note in release notes

## 9) Test Checklist (Manual, Required)

For every behavior change, verify on a test server with at least 2 clients:

1. Startup:
   - plugin logs loaded message
   - initial time/fog/gravity match config
1. Join sync:
   - new player receives current server environment immediately
1. Tick sync:
   - time advances correctly when unfrozen
   - periodic sync still updates clients
1. Command permissions:
   - non-admin cannot mutate state
   - admin can run all write commands
1. State changes:
   - `/time`, `/freeze`, `/unfreeze`, `/dayspeed`, `/fog`, `/gravity` all apply for every player
1. Persistence:
   - `/addadmin` + `/removeadmin` survive server restart
1. Regression:
   - no script errors in server/client logs during normal play

## 10) Known Risks / Improvement Backlog

These are not blockers, but should be considered near-term tasks:

1. **Admin identity robustness**
   - Current admin auth is by display name, which can change/spoof.
   - Preferred direction: ID-based admin auth if BeamMP API allows stable identifiers.

1. **Command arg parsing for names with spaces**
   - `/addadmin` and `/removeadmin` currently read a single token argument.
   - Multi-word display names may not work correctly.

1. **Input clamping/validation consistency**
   - Some values are range-checked (`fog`, `/time`), others are only type-checked (`gravity`).
   - Decide policy and apply consistently.

1. **Observability**
   - Add concise debug logging mode for sync payload/events when diagnosing desyncs.

1. **Release ergonomics**
   - Optional: add a local release script (`scripts/release.sh`) to mirror CI steps exactly.

## 11) Recommended Work Sequence Going Forward

When implementing a feature/fix:

1. Define behavior contract first (commands/config/events).
1. Implement server changes (`main.lua`) first.
1. Implement client apply path changes (`TimeFly.lua`) second.
1. Update docs (`README.md` + Build Bible).
1. Run manual multiplayer checklist.
1. Tag release when stable.

## 12) Definition of Done for Any Task

A task is complete only when:

- Code changes are minimal and focused.
- Server and client logs are clean in test session.
- README and/or Build Bible are updated when contract changes.
- No local/dev artifacts are introduced into git status.

---

Owner note: this file should evolve with each meaningful architecture/process change. If this document and code disagree, update this document in the same PR.
