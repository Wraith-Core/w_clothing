-- =====================================================================
--  server/scene.lua  —  WCScene: fitting-room routing bucket isolation for w_clothing
--  Only isolates players holding an active store session at a shop with a fitting stand.
--  Always restores the exact previous bucket (never overrides jail / housing buckets).
-- =====================================================================

WCScene = {}
local Scene = WCScene

local tracked = {} -- [src] = { src, bucket, previous, at }

local function valid(src)
    src = tonumber(src)
    if not src or src <= 0 or src % 1 ~= 0 then return nil end
    src = math.tointeger(src)
    if not GetPlayerName(src) then return nil end
    return src
end

local function fittingSession(src)
    local session = WCSessions and WCSessions.current(src)
    if type(session) ~= 'table' or session.kind ~= 'store' then return nil end
    if type(session.location) ~= 'table' or session.location.preview == nil then return nil end
    if type(WCSessions.withinRange) ~= 'function' or not WCSessions.withinRange(src, session.location) then
        return nil
    end
    return session
end

function Scene.isIsolated(src)
    local entry = tracked[tonumber(src) or -1]
    return entry ~= nil and GetPlayerRoutingBucket(entry.src) == entry.bucket
end

function Scene.isolate(src)
    src = valid(src)
    if not src then return WCResult.fail('INVALID_PAYLOAD') end
    if not WCSecurity.rate(src, 'scene:isolate', 6, 10000) then return WCResult.fail('RATE_LIMITED') end

    local current = GetPlayerRoutingBucket(src)
    local entry = tracked[src]
    if entry and current == entry.bucket then
        return WCResult.ok({ bucket = entry.bucket, reason = 'fitting' })
    end

    if not fittingSession(src) then
        WCSecurity.violation(src, 'scene_isolation', { bucket = current })
        return WCResult.fail('SESSION_NOT_FOUND')
    end

    -- Use offset bucket id (100000 + src) so it never collides with w_creators' bucket = src
    local bucket = 100000 + src
    tracked[src] = { src = src, bucket = bucket, previous = current, at = GetGameTimer() }
    pcall(SetRoutingBucketPopulationEnabled, bucket, false)
    SetPlayerRoutingBucket(src, bucket)
    return WCResult.ok({ bucket = bucket, reason = 'fitting' })
end

function Scene.release(src)
    src = valid(src)
    if not src then return WCResult.fail('INVALID_PAYLOAD') end
    local entry = tracked[src]
    tracked[src] = nil
    if not entry then return WCResult.ok({ released = false }) end
    if GetPlayerRoutingBucket(src) == entry.bucket then
        SetPlayerRoutingBucket(src, entry.previous or 0)
    end
    return WCResult.ok({ released = true })
end

function Scene.check()
    for src, entry in pairs(tracked) do
        if not GetPlayerName(src) then
            tracked[src] = nil
        elseif not fittingSession(src) then
            Scene.release(src)
        end
    end
end

w.callback.register('w_clothing:scene:prepare', function(src)
    return Scene.isolate(src)
end)

w.callback.register('w_clothing:scene:release', function(src)
    return Scene.release(src)
end)

if WCSessions and WCSessions.onClose then
    WCSessions.onClose(function(session)
        if session and session.src and tracked[session.src] then
            Scene.release(session.src)
        end
    end)
end

AddEventHandler('playerDropped', function()
    tracked[source] = nil
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for src in pairs(tracked) do pcall(Scene.release, src) end
end)

CreateThread(function()
    while true do
        Wait(5000)
        pcall(Scene.check)
    end
end)
