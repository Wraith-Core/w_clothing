-- =====================================================================
--  server/appearance/sync.lua  —  WCSync (ARCHITECTURE.md §9.4, §16.5)
--  RedM does not replicate MetaPed components: every client renders the other players' peds itself.
--  The server keeps the last broadcast appearance of every player so a player who joins later (or a
--  client whose scope watcher lost a ped) receives it, and pushes clothing state changes as small
--  deltas.
--
--    WCSync.broadcast(src, app)               cache + w_clothing:client:applyRemoteAppearance to all
--    WCSync.broadcastState(src, group, value) cache + w_clothing:client:remoteClothingState to all
--    WCSync.forget(src)                       drop the cache + w_clothing:client:forgetRemote to all
--    WCSync.withRuntimeStates(src, app, charid) the saved look + the runtime (non-persisting) states
--    WCSync.get(src)                          a copy of the cached appearance, or nil
--
--  Net events / callbacks:
--    w_clothing:server:requestAppearances          (legacy, rate limited) the cached appearances of
--                                                  the other players, sent to the requester only
--    w_clothing:appearance:reload                  callback -> Result { appearance } + re-broadcast
--    PersonaCreatorHandler.reloadCharacterAppearance legacy net event: same, answered with
--                                                  w_clothing:client:applyAppearance
--  Both reload paths share one rate limit (1 per 10 s).
-- =====================================================================

WCSync = {}
local Sync = WCSync

local cache = {} -- [src] = v3 appearance (the last broadcast)

local RELOAD_KEY, RELOAD_MAX, RELOAD_WINDOW = 'appearance:reload', 1, 10000
local REQUEST_KEY, REQUEST_MAX, REQUEST_WINDOW = 'appearance:request', 2, 10000

local function playerId(src)
    src = tonumber(src)
    if not src or src <= 0 or src % 1 ~= 0 then return nil end
    return math.tointeger(src)
end

local function standardClothes(app)
    local clothes = {}
    local equipped = type(app.clothing) == 'table' and app.clothing.equipped or {}
    local tints = type(app.clothing) == 'table' and app.clothing.tints or {}
    for category, hash in pairs(equipped) do
        local entry = { hash = hash }
        local tint = tints[category]
        if type(tint) == 'table' then
            entry.palette, entry.tint0, entry.tint1, entry.tint2 = tint.palette, tint.tint0, tint.tint1, tint.tint2
        end
        clothes[category] = entry
    end
    return clothes
end

local function pushFrameworkClothes(src, app)
    if GetResourceState('w_creators') == 'started' then return end
    if Config.Standalone and Config.Standalone.syncToFramework == false then return end
    if w and w.framework and type(w.framework.updateUserClothes) == 'function' then
        pcall(function() w.framework:updateUserClothes(src, standardClothes(app), true) end)
    end
end

--- Cache a player's appearance and send it to every client (delegates to w_creators when running).
---@return boolean sent
function Sync.broadcast(src, app)
    src = playerId(src)
    if not src or type(app) ~= 'table' then return false end
    cache[src] = WCUtil.copy(app)
    local active = WCSessions and WCSessions.activeCharacter and WCSessions.activeCharacter(src)
    TriggerEvent('w_appearance:updated', src, active and active.charid or nil, app)
    if GetResourceState('w_creators') == 'started' then
        local ok = pcall(function() exports.w_creators:SyncAppearanceFromExternal(src, app) end)
        if ok then return true end
    end
    pushFrameworkClothes(src, app)
    TriggerClientEvent('w_clothing:client:applyRemoteAppearance', -1, src, app)
    return true
end

--- A copy of a saved appearance with the player's runtime (non-persisting) clothing states added
--  (WCClothingActions: e.g. a raised bandana), for a state whose item the look still wears. A
--  re-send of the saved look that is not a change of the look (a grooming stage, a reload, the
--  ApplyCharacterAppearance export) carries them, so the cache, the other players and a late
--  joiner keep drawing them (the saved look alone has only the persisting states).
function Sync.withRuntimeStates(src, app, charid)
    if type(app) ~= 'table' or type(WCClothingActions) ~= 'table' or type(WCClothingActions.states) ~= 'function'
        or charid == nil then
        return app
    end
    local out = WCUtil.copy(app)
    out.clothing = type(out.clothing) == 'table' and out.clothing or {}
    out.clothing.states = type(out.clothing.states) == 'table' and out.clothing.states or {}
    -- without an appearance: only the runtime states of this character
    for group, value in pairs(WCClothingActions.states(src, nil, tostring(charid))) do
        local def = WCClothingStates.byId[group]
        if def and not def.persist and WCClothingStates.isValid(group, value)
            and WCClothingStates.applicable(out, group) then
            out.clothing.states[group] = value
        end
    end
    return out
end

--- Update one clothing state of a player's cached appearance and send the delta to every client.
---@return boolean sent
function Sync.broadcastState(src, group, value)
    src = playerId(src)
    if not src or type(group) ~= 'string' then return false end
    local app = cache[src]
    if app then
        app.clothing = type(app.clothing) == 'table' and app.clothing or {}
        app.clothing.states = type(app.clothing.states) == 'table' and app.clothing.states or {}
        app.clothing.states[group] = value
    end
    if GetResourceState('w_creators') == 'started' then
        local ok = pcall(function() exports.w_creators:SyncClothingStateFromExternal(src, group, value) end)
        if ok then return true end
    end
    TriggerClientEvent('w_clothing:client:remoteClothingState', -1, src, group, value)
    return true
end

--- Forget a player's appearance (disconnect, character switch) on the server and every client.
function Sync.forget(src)
    src = playerId(src)
    if not src then return false end
    cache[src] = nil
    TriggerClientEvent('w_clothing:client:forgetRemote', -1, src)
    return true
end

--- A copy of the cached appearance of a player, or nil.
function Sync.get(src)
    src = playerId(src)
    local app = src and cache[src]
    return app and WCUtil.copy(app) or nil
end

-- ---------------------------------------------------------------------
--  Late joiners
-- ---------------------------------------------------------------------
RegisterNetEvent('w_clothing:server:requestAppearances', function()
    local src = playerId(source)
    if not src or not WCSecurity.rate(src, REQUEST_KEY, REQUEST_MAX, REQUEST_WINDOW) then return end
    for other, app in pairs(cache) do
        if other ~= src then
            TriggerClientEvent('w_clothing:client:applyRemoteAppearance', src, other, app)
        end
    end
end)

-- ---------------------------------------------------------------------
--  Reload (the player's ped lost its look: re-read the saved appearance and re-apply it)
-- ---------------------------------------------------------------------

--- Load the active character's appearance and re-broadcast it. Result { appearance }.
function Sync.reload(src)
    src = playerId(src)
    if not src then return WCResult.fail('INVALID_PAYLOAD') end
    if not WCSecurity.rate(src, RELOAD_KEY, RELOAD_MAX, RELOAD_WINDOW) then return WCResult.fail('RATE_LIMITED') end
    local active = WCSessions.activeCharacter(src)
    if not active then return WCResult.fail('NO_CHARACTER') end
    -- An open preview session renders its own working copy; a commit in flight owns the appearance.
    if WCSessions.current(src) or CreatorAppearanceLocks[active.charid] then return WCResult.fail('BUSY') end

    local ok, app, meta = pcall(WCAppearanceRepo.load, active.charid, { src = src })
    if not ok then
        WCDebug.warn('sync', 'reloading %s failed: %s', active.charid, tostring(app))
        app, meta = nil, { error = 'DATABASE_ERROR' }
    end
    CreatorLogs.Emit('appearance_loaded', { playerSource = src, charid = active.charid, found = app ~= nil })
    if not app then
        return WCResult.fail(type(meta) == 'table' and meta.error or 'CHARACTER_NOT_FOUND')
    end
    -- not a change of the look: the runtime states (a raised bandana) stay drawn remotely
    Sync.broadcast(src, Sync.withRuntimeStates(src, app, active.charid))
    return WCResult.ok({ appearance = app })
end

w.callback.register('w_clothing:appearance:reload', function(src)
    return Sync.reload(src)
end)

AddEventHandler('playerDropped', function()
    local src = playerId(source)
    if src and cache[src] then Sync.forget(src) end
end)
