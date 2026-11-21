-- =====================================================================
--  client/clothing/escort.lua  —  WCEscort: the tailor escort to the fitting room
--  (Config.Clothing.escort, Config.Locations[].doorRoom / exitWardrobe)
--
--  When a player opens a clothing store, the store's tailor NPC steps out from behind the counter
--  and walks toward the fitting room door while the player follows behind him (the classic RDR2 /
--  VORP tailor escort sequence). Under the screen fade, the tailor is returned cleanly to his
--  counter spot, the invisible waypoint ped is deleted, and the player enters the fitting room.
--  Every wait is bounded, and death, abort or resource stop cleans up immediately without yielding.
-- =====================================================================

WCEscort = {}
local Esc = WCEscort

local state = nil -- { npc, npcHome, target, spectator, hud, radar }

local function cfg()
    return Config.Clothing and type(Config.Clothing.escort) == 'table' and Config.Clothing.escort or {}
end

local function pedExists(ped)
    -- BOOL natives answer 1 (not true) on this runtime: never compare them with == true
    return type(ped) == 'number' and ped ~= 0 and not not DoesEntityExist(ped)
end

local function isDead(ped)
    local ok, dead = pcall(IsEntityDead, ped)
    return ok and (dead == true or dead == 1)
end

local function call(name, ...)
    local fn = _ENV[name]
    if fn == nil then return false end
    return (pcall(fn, ...))
end

local function fallbackLoc(loc)
    local map = type(cfg().locations) == 'table' and cfg().locations or nil
    if not map or type(loc) ~= 'table' or type(loc.id) ~= 'string' then return nil end
    return map[loc.id]
end

--- Is the tailor escort feature enabled?
function Esc.enabled()
    return cfg().enabled == true
end

--- The fitting room door target for a clothing store: x, y, z, or nil.
function Esc.door(loc)
    if type(loc) ~= 'table' or loc.type ~= 'clothing' then return nil end
    local raw = loc.doorRoom
    if raw == nil then
        local fb = fallbackLoc(loc)
        raw = fb and fb.doorRoom or nil
    end
    if raw == nil then return nil end
    local x, y, z = CreatorScene.coords(raw)
    if not x then return nil end
    return x, y, z
end

--- The exit spot outside the fitting room door: { x, y, z, h }, or nil.
function Esc.exitSpot(loc)
    if not Esc.enabled() or cfg().useExitCoords == false then return nil end
    if type(loc) ~= 'table' or loc.type ~= 'clothing' then return nil end
    local raw = loc.exitWardrobe
    if raw == nil then
        local fb = fallbackLoc(loc)
        raw = fb and fb.exitWardrobe or nil
    end
    if raw == nil then return nil end
    local x, y, z, h = CreatorScene.coords(raw)
    if not x then return nil end
    return { x, y, z, h }
end

--- Is an escort currently active (for diagnostics and tests)?
function Esc.active()
    return state ~= nil
end

--- Clean up everything enter() started (never yields). Call under the fade or on abort / stop.
function Esc.release(restoreHud)
    local s = state
    if not s then return end
    state = nil
    local playerPed = PlayerPedId()
    if s.spectator then
        call('NetworkSetInSpectatorMode', false, playerPed)
    end
    if s.target and pedExists(s.target) then
        pcall(w.entity.delete, s.target)
    end
    if s.npc and pedExists(s.npc) and s.npcHome then
        local h = s.npcHome
        call('ClearPedTasksImmediately', s.npc)
        call('SetEntityCoords', s.npc, h[1], h[2], h[3], false, false, false, false)
        call('SetEntityHeading', s.npc, h[4])
        call('FreezeEntityPosition', s.npc, true)
    end
    if restoreHud ~= false then
        if s.hud and type(SetPlayerHudVisible) == 'function' then pcall(SetPlayerHudVisible, true) end
        if s.radar and type(w) == 'table' and type(w.setRadarVisible) == 'function' then
            pcall(w.setRadarVisible, true)
        end
    end
end

local function distanceSq(ped, tx, ty, tz)
    local ok, at = pcall(GetEntityCoords, ped)
    if not ok or not at then return math.huge end
    local dx, dy, dz = at.x - tx, at.y - ty, at.z - tz
    return dx * dx + dy * dy + dz * dz
end

--- Play the tailor escort walk to the fitting room door. Yields until the player reaches the door
--  or the bounded timeout elapses. Leaves spectator / beacon / tailor state active until
--  Esc.release() is called under the fade (or releases immediately on abort).
---@param loc table
---@param isAborted? fun(): boolean
---@return boolean escorted
function Esc.enter(loc, isAborted)
    Esc.release(true)
    if not Esc.enabled() then return false end
    local dx, dy, dz = Esc.door(loc)
    if not dx then return false end
    local playerPed = PlayerPedId()
    if not pedExists(playerPed) or isDead(playerPed) then return false end

    local c = cfg()
    local targetModel = type(c.targetModel) == 'string' and c.targetModel ~= '' and c.targetModel or 'S_M_M_Tailor_01'
    local okTarget, target = pcall(w.entity.create, targetModel, vector4(dx, dy, dz, 0.0), false)
    if not okTarget or type(target) ~= 'number' or target == 0 or not pedExists(target) then
        WCDebug.warn('escort', 'beacon ped for %s failed: %s', tostring(loc.id), tostring(target))
        return false
    end

    pcall(WCNative.ped.updateVariation, target)
    call('SetEntityAlpha', target, 0, true)
    call('SetEntityVisible', target, false)
    call('SetEntityCollision', target, false, false)
    call('SetEntityCanBeDamaged', target, false)
    call('SetEntityInvincible', target, true)
    call('SetBlockingOfNonTemporaryEvents', target, true)
    call('FreezeEntityPosition', target, true)

    local npc = type(WCServicePoints) == 'table' and type(WCServicePoints.npcOf) == 'function'
        and WCServicePoints.npcOf(loc.id) or nil
    local npcHome = nil
    if npc and pedExists(npc) then
        local nx, ny, nz, nh
        if type(loc.npc) == 'table' and loc.npc.coords then
            nx, ny, nz, nh = CreatorScene.coords(loc.npc.coords)
        end
        if not nx then
            local at = GetEntityCoords(npc)
            if at then nx, ny, nz, nh = at.x, at.y, at.z, GetEntityHeading(npc) end
        end
        if nx then npcHome = { nx, ny, nz, nh } end
    else
        npc = nil
    end

    local s = { target = target, npc = npc, npcHome = npcHome }
    state = s

    if type(SetPlayerHudVisible) == 'function' then
        pcall(SetPlayerHudVisible, false)
        s.hud = true
    end
    if type(IsRadarShown) == 'function' and IsRadarShown() and type(w) == 'table' and type(w.setRadarVisible) == 'function' then
        pcall(w.setRadarVisible, false)
        s.radar = true
    end

    call('NetworkSetInSpectatorMode', true, playerPed)
    s.spectator = true

    local function stopped()
        if state ~= s then return true end
        if isDead(playerPed) or not pedExists(playerPed) then return true end
        if type(isAborted) == 'function' and isAborted() then return true end
        return false
    end

    local arriveDist = WCUtil.number(c.arriveDistance, 0.8, 5.0, 1.8)
    local arriveSq = arriveDist * arriveDist

    if npc and pedExists(npc) then
        call('SetEntityNoCollisionEntity', playerPed, npc, false)
        call('ClearPedTasksImmediately', npc)
        call('FreezeEntityPosition', npc, false)
        Wait(150)
        if stopped() then
            Esc.release(true)
            return false
        end
        local npcSpeed = WCUtil.number(c.npcSpeed, 0.5, 2.5, 1.1) + 0.0
        call('TaskGoToEntity', npc, target, 15000, 0.5, npcSpeed, 1.0, 1)
        local leadMs = WCUtil.int(c.leadMs, 0, 10000, 3000)
        if leadMs > 0 then
            WCUtil.waitUntil(function()
                if stopped() then return true end
                if not pedExists(npc) or distanceSq(npc, dx, dy, dz) <= arriveSq then return true end
                return nil
            end, leadMs, 100)
        end
    end

    if stopped() then
        Esc.release(true)
        return false
    end

    local playerSpeed = WCUtil.number(c.playerSpeed, 0.5, 2.0, 0.85) + 0.0
    call('TaskGoToEntity', playerPed, target, 10000, 0.5, playerSpeed, 1.0, 1)
    local walkMs = WCUtil.int(c.walkMs, 0, 15000, 5500)
    if walkMs > 0 then
        WCUtil.waitUntil(function()
            if stopped() then return true end
            if distanceSq(playerPed, dx, dy, dz) <= arriveSq then return true end
            return nil
        end, walkMs, 100)
    end

    if stopped() then
        Esc.release(true)
        return false
    end

    return true
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    pcall(Esc.release, true)
end)
