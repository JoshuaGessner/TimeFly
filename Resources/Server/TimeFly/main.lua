-- TimeFly — BeamMP environment-sync server plugin
-- Syncs time of day, fog, and gravity to all connected players.
-- Admins can control all settings via chat commands.

local config = {}
local timeState = {}
local ticksSinceSync = 0

local CONFIG_PATH = "Resources/Server/TimeFly/config.json"

-- ─── Configuration ───────────────────────────────────────────────────────────

local function loadConfig()
    local file = io.open(CONFIG_PATH, "r")
    if file then
        local content = file:read("*all")
        file:close()
        local ok, decoded = pcall(MP.JsonDecode, content)
        if ok and decoded then
            config = decoded
        end
    end
    -- Apply defaults for any missing fields
    config.syncInterval = config.syncInterval or 30
    config.dayLength    = config.dayLength    or 1200
    config.startTime    = config.startTime    or 0.0
    config.timeFrozen   = config.timeFrozen   or false
    config.fogDensity   = config.fogDensity   or 0.0
    config.gravity      = config.gravity      or -9.81
    config.adminList    = config.adminList    or {}
end

local function initState()
    timeState.time      = config.startTime
    timeState.dayLength = config.dayLength
    timeState.frozen    = config.timeFrozen
    timeState.fogDensity = config.fogDensity
    timeState.gravity   = config.gravity
end

local function saveConfig()
    local file = io.open(CONFIG_PATH, "w")
    if file then
        file:write(jsonEncode(config))
        file:close()
    else
        print("[TimeFly] WARNING: Could not write config to " .. CONFIG_PATH)
    end
end

-- ─── Helpers ─────────────────────────────────────────────────────────────────

-- MP.JsonEncode may be absent in some BeamMP builds; fall back to a simple
-- recursive serialiser that covers all types used in this plugin.
local _jsonEscape = {
    ['\\'] = '\\\\', ['"'] = '\\"',
    ['\b'] = '\\b',  ['\f'] = '\\f',
    ['\n'] = '\\n',  ['\r'] = '\\r', ['\t'] = '\\t',
}
local function jsonEncode(val)
    if type(MP.JsonEncode) == "function" then
        return MP.JsonEncode(val)
    end
    local t = type(val)
    if t == "number" then
        return string.format("%.10g", val)
    elseif t == "boolean" then
        return tostring(val)
    elseif t == "string" then
        return '"' .. val:gsub('[\\"\b\f\n\r\t]', _jsonEscape) .. '"'
    elseif t == "table" then
        if #val > 0 then
            local parts = {}
            for _, v in ipairs(val) do
                table.insert(parts, jsonEncode(v))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local keys = {}
            for k in pairs(val) do table.insert(keys, k) end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            local parts = {}
            for _, k in ipairs(keys) do
                table.insert(parts, '"' .. tostring(k) .. '":' .. jsonEncode(val[k]))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end


-- Returns true when the named player is in config.adminList
local function isAdmin(playerID)
    local players = MP.GetPlayers()
    if type(players) ~= "table" then return false end
    local name = players[playerID]
    if not name then return false end
    for _, adminName in ipairs(config.adminList) do
        if adminName == name then return true end
    end
    return false
end

-- BeamNG time convention: 0.0 = noon (12:00), 0.5 = midnight (00:00)
-- Convert a game-time value (0-1) to a human-readable "HH:MM" string
local function timeToHHMM(t)
    local realHours = (t * 24 + 12) % 24
    local h = math.floor(realHours)
    local m = math.floor((realHours - h) * 60)
    return string.format("%02d:%02d", h, m)
end

-- Convert an "HH:MM" string to a game-time value (0-1).
-- Returns nil when the inputs are non-numeric or out of range.
local function HHMMToTime(h, m)
    local hours = tonumber(h)
    local mins  = tonumber(m)
    if not hours or not mins then return nil end
    if hours < 0 or hours > 23 or mins < 0 or mins > 59 then
        return nil
    end
    return ((hours + mins / 60 - 12) % 24) / 24
end

-- Build the JSON payload that clients receive on each sync
local function buildPayload()
    return jsonEncode({
        time       = timeState.time,
        dayLength  = timeState.dayLength,
        frozen     = timeState.frozen,
        fogDensity = timeState.fogDensity,
        gravity    = timeState.gravity,
    })
end

-- Send the current environment state to one player, or all when playerID == -1
local function syncPlayer(playerID)
    MP.TriggerClientEvent(playerID, "TimeFly_sync", buildPayload())
end

local function syncAll()
    syncPlayer(-1)
    ticksSinceSync = 0
end

-- ─── Event handlers (must be global for MP.RegisterEvent) ────────────────────

-- Sync state to a freshly joined player
function TimeFly_onPlayerJoining(playerID)
    syncPlayer(playerID)
end

-- Advance the server-side clock once per second, then broadcast on schedule
function TimeFly_onTick()
    if not timeState.frozen and timeState.dayLength > 0 then
        timeState.time = (timeState.time + 1.0 / timeState.dayLength) % 1.0
    end

    ticksSinceSync = ticksSinceSync + 1
    if ticksSinceSync >= config.syncInterval then
        syncAll()
    end
end

-- Handle slash-commands sent in chat
function TimeFly_onChatMessage(playerID, playerName, message)
    if message:sub(1, 1) ~= "/" then return end

    local args = {}
    for word in message:gmatch("%S+") do
        table.insert(args, word)
    end
    local cmd = args[1]:lower()

    -- ── Help (everyone) ──────────────────────────────────────────────────────
    if cmd == "/timefly" then
        MP.SendChatMessage(playerID,
            "[TimeFly] Commands:\n" ..
            "  /time [HH:MM|0-1]       - Get or set time of day\n" ..
            "  /freeze                  - Freeze time          (admin)\n" ..
            "  /unfreeze                - Unfreeze time        (admin)\n" ..
            "  /dayspeed <secs>         - Seconds per in-game day (admin)\n" ..
            "  /fog <0-1>               - Fog density          (admin)\n" ..
            "  /gravity <m/s²>          - Gravity              (admin)\n" ..
            "  /addadmin <playerName>   - Grant admin rights   (admin)\n" ..
            "  /removeadmin <playerName> - Revoke admin rights  (admin)\n" ..
            "  /timefly                 - Show this help")
        return 1
    end

    -- ── Time query (everyone) ─────────────────────────────────────────────────
    if cmd == "/time" and #args == 1 then
        MP.SendChatMessage(playerID,
            "[TimeFly] Current time: " .. timeToHHMM(timeState.time) ..
            (timeState.frozen and " [FROZEN]" or ""))
        return 1
    end

    -- ── Admin-only commands ───────────────────────────────────────────────────
    if not isAdmin(playerID) then return end

    if cmd == "/time" and #args >= 2 then
        local val = args[2]
        local h, m = val:match("^(%d+):(%d+)$")
        if h and m then
            local newTime = HHMMToTime(h, m)
            if newTime == nil then
                MP.SendChatMessage(playerID,
                    "[TimeFly] Invalid time. Hours must be 00-23, minutes 00-59.")
                return 1
            end
            timeState.time = newTime
        else
            local t = tonumber(val)
            if t and t >= 0 and t <= 1 then
                timeState.time = t
            else
                MP.SendChatMessage(playerID,
                    "[TimeFly] Usage: /time HH:MM  or  /time 0.0-1.0")
                return 1
            end
        end
        syncAll()
        MP.SendChatMessage(-1,
            "[TimeFly] Time set to " .. timeToHHMM(timeState.time) .. " by " .. playerName)
        return 1

    elseif cmd == "/freeze" then
        timeState.frozen = true
        syncAll()
        MP.SendChatMessage(-1, "[TimeFly] Time frozen by " .. playerName)
        return 1

    elseif cmd == "/unfreeze" then
        timeState.frozen = false
        syncAll()
        MP.SendChatMessage(-1, "[TimeFly] Time unfrozen by " .. playerName)
        return 1

    elseif cmd == "/dayspeed" then
        if #args < 2 then
            MP.SendChatMessage(playerID,
                "[TimeFly] Day length: " .. timeState.dayLength .. "s per in-game day")
            return 1
        end
        local val = tonumber(args[2])
        if val and val > 0 then
            timeState.dayLength = val
            syncAll()
            MP.SendChatMessage(-1,
                string.format("[TimeFly] Day length set to %ds by %s", val, playerName))
        else
            MP.SendChatMessage(playerID,
                "[TimeFly] Day length must be a positive number of seconds.")
        end
        return 1

    elseif cmd == "/fog" then
        if #args < 2 then
            MP.SendChatMessage(playerID,
                string.format("[TimeFly] Fog density: %.2f", timeState.fogDensity))
            return 1
        end
        local val = tonumber(args[2])
        if val and val >= 0 and val <= 1 then
            timeState.fogDensity = val
            syncAll()
            MP.SendChatMessage(-1,
                string.format("[TimeFly] Fog set to %.2f by %s", val, playerName))
        else
            MP.SendChatMessage(playerID, "[TimeFly] Fog density must be between 0 and 1.")
        end
        return 1

    elseif cmd == "/gravity" then
        if #args < 2 then
            MP.SendChatMessage(playerID,
                string.format("[TimeFly] Gravity: %.2f m/s²", timeState.gravity))
            return 1
        end
        local val = tonumber(args[2])
        if val then
            timeState.gravity = val
            syncAll()
            MP.SendChatMessage(-1,
                string.format("[TimeFly] Gravity set to %.2f m/s² by %s", val, playerName))
        else
            MP.SendChatMessage(playerID, "[TimeFly] Gravity must be a number (e.g. -9.81).")
        end
        return 1

    elseif cmd == "/addadmin" then
        if #args < 2 then
            MP.SendChatMessage(playerID, "[TimeFly] Usage: /addadmin <playerName>")
            return 1
        end
        local targetName = args[2]
        for _, adminName in ipairs(config.adminList) do
            if adminName == targetName then
                MP.SendChatMessage(playerID,
                    "[TimeFly] " .. targetName .. " is already an admin.")
                return 1
            end
        end
        table.insert(config.adminList, targetName)
        local saved = pcall(saveConfig)
        MP.SendChatMessage(-1,
            "[TimeFly] " .. targetName .. " was granted admin rights by " .. playerName)
        if not saved then
            MP.SendChatMessage(playerID,
                "[TimeFly] WARNING: Admin list could not be saved to disk.")
        end
        return 1

    elseif cmd == "/removeadmin" then
        if #args < 2 then
            MP.SendChatMessage(playerID, "[TimeFly] Usage: /removeadmin <playerName>")
            return 1
        end
        local targetName = args[2]
        local removed = false
        for i, adminName in ipairs(config.adminList) do
            if adminName == targetName then
                table.remove(config.adminList, i)
                removed = true
                break
            end
        end
        if removed then
            local saved = pcall(saveConfig)
            MP.SendChatMessage(-1,
                "[TimeFly] " .. targetName .. " had admin rights revoked by " .. playerName)
            if not saved then
                MP.SendChatMessage(playerID,
                    "[TimeFly] WARNING: Admin list could not be saved to disk.")
            end
        else
            MP.SendChatMessage(playerID,
                "[TimeFly] " .. targetName .. " is not in the admin list.")
        end
        return 1
    end
end

-- ─── Startup ─────────────────────────────────────────────────────────────────

loadConfig()
initState()

MP.RegisterEvent("onPlayerJoining", "TimeFly_onPlayerJoining")
MP.RegisterEvent("onChatMessage",   "TimeFly_onChatMessage")
MP.CreateEventTimer("TimeFly_tick", 1000)
MP.RegisterEvent("TimeFly_tick",    "TimeFly_onTick")

print("[TimeFly] Loaded. Starting time: " .. timeToHHMM(timeState.time) ..
      " | Day length: " .. timeState.dayLength .. "s" ..
      " | Frozen: " .. tostring(timeState.frozen))
