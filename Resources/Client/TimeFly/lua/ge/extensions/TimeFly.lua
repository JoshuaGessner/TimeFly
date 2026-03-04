-- TimeFly — BeamMP environment-sync client extension
-- Receives time-of-day, fog, and gravity from the server and applies them
-- to the BeamNG.drive scene using the core_environment API.
--
-- BeamNG time convention: 0.0 = noon (12:00), 0.5 = midnight (00:00)

local M = {}

print("[TimeFly] Client extension loading")

local pendingState    = nil   -- state received before a map was loaded
local missionActive   = false
local fogWarnedOnce   = false
local gravWarnedOnce  = false
local timeWarnedOnce  = false
local syncDecodeWarned = false
local syncReceiveLogged = false

local function decodePayload(rawData)
    if type(rawData) ~= "string" then return nil end

    local parts = {}
    for token in rawData:gmatch("([^|]+)") do
        parts[#parts + 1] = token
    end

    if #parts ~= 5 then return nil end

    local time = tonumber(parts[1])
    local dayLength = tonumber(parts[2])
    local frozenToken = parts[3]
    local fogDensity = tonumber(parts[4])
    local gravity = tonumber(parts[5])
    if not time or not dayLength or not fogDensity or not gravity then
        return nil
    end

    return {
        time = time,
        dayLength = dayLength,
        frozen = (frozenToken == "1"),
        fogDensity = fogDensity,
        gravity = gravity,
    }
end

-- ─── Apply helpers ────────────────────────────────────────────────────────────

local function applyTimeOfDay(state)
    local applied = false

    if core_environment and core_environment.setTimeOfDay then
        local ok, err = pcall(core_environment.setTimeOfDay, {
            time = state.time,
            play = not state.frozen,
            dayLength = state.dayLength,
        })
        if ok then
            applied = true
        elseif not timeWarnedOnce then
            print("[TimeFly] Warning: core_environment.setTimeOfDay failed: " .. tostring(err))
            timeWarnedOnce = true
        end
    end

    if not applied and scenetree and scenetree.tod then
        local ok, err = pcall(function()
            scenetree.tod.time = state.time
            scenetree.tod.dayLength = state.dayLength
            if scenetree.tod.setPlay then
                scenetree.tod:setPlay(not state.frozen)
            end
        end)
        if not ok and not timeWarnedOnce then
            print("[TimeFly] Warning: scenetree.tod time apply failed: " .. tostring(err))
            timeWarnedOnce = true
        end
    end
end

local function applyFog(state)
    if not state.fogDensity then return end
    -- Try the documented API first; fall back to direct TOD property.
    if core_environment and core_environment.setFog then
        local ok, err = pcall(core_environment.setFog, state.fogDensity)
        if not ok and not fogWarnedOnce then
            print("[TimeFly] Warning: could not apply fog via core_environment.setFog: " .. tostring(err))
            fogWarnedOnce = true
        end
    elseif scenetree and scenetree.tod then
        local ok, err = pcall(function()
            scenetree.tod.fogAtmosphereHeight = state.fogDensity * 10000
        end)
        if not ok and not fogWarnedOnce then
            print("[TimeFly] Warning: could not apply fog via scenetree.tod: " .. tostring(err))
            fogWarnedOnce = true
        end
    end
end

local function applyGravity(state)
    if state.gravity == nil then return end
    -- core_environment.setGravity is available in BeamNG 0.28+
    if core_environment and core_environment.setGravity then
        local ok, err = pcall(core_environment.setGravity, state.gravity)
        if not ok and not gravWarnedOnce then
            print("[TimeFly] Warning: could not apply gravity via core_environment.setGravity: " .. tostring(err))
            gravWarnedOnce = true
        end
    elseif be then
        -- Gravity vector: BeamNG uses Z-up world space
        local ok, err = pcall(be.setGravity, be, 0, 0, state.gravity)
        if not ok and not gravWarnedOnce then
            print("[TimeFly] Warning: could not apply gravity via be:setGravity: " .. tostring(err))
            gravWarnedOnce = true
        end
    end
end

local function applyState(state)
    applyTimeOfDay(state)
    applyFog(state)
    applyGravity(state)
end

-- ─── Server event handler ─────────────────────────────────────────────────────

local function onTimeFlySync(rawData)
    local data = decodePayload(rawData)
    if type(data) ~= "table" then
        if not syncDecodeWarned then
            print("[TimeFly] Warning: could not decode TimeFly_sync payload")
            syncDecodeWarned = true
        end
        return
    end

    if not syncReceiveLogged then
        print("[TimeFly] Received first TimeFly_sync payload")
        syncReceiveLogged = true
    end

    if missionActive or core_environment then
        applyState(data)
    else
        -- Mission not yet loaded; cache and apply once the map is ready
        pendingState = data
    end
end

-- ─── BeamNG extension lifecycle ──────────────────────────────────────────────

function M.onExtensionLoaded()
    if type(AddEventHandler) == "function" then
        AddEventHandler("TimeFly_sync", onTimeFlySync)
        print("[TimeFly] Registered AddEventHandler for TimeFly_sync")
    end
    print("[TimeFly] Client extension ready")
end

-- BeamMP v3.x calls extensions.hook("TimeFly_sync", data) on all loaded
-- extensions when the server fires TriggerClientEvent("TimeFly_sync", data).
M.TimeFly_sync = onTimeFlySync

function M.onClientStartMission(missionPath)
    missionActive = true
    if pendingState then
        applyState(pendingState)
        pendingState = nil
    end
end

function M.onClientEndMission()
    missionActive = false
end

return M
