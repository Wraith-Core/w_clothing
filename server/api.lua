-- =====================================================================
--  server/api.lua  —  w_clothing public server API
-- =====================================================================

WCApi = {}
local Api = WCApi

local MAX_ID = 64
local fail, ok = WCResult.fail, WCResult.ok

local function playerId(src)
    src = tonumber(src)
    if not src or src <= 0 or src % 1 ~= 0 then return nil end
    src = math.tointeger(src)
    if not GetPlayerName(src) then return nil end
    return src
end

function Api.OpenClothingStore(src, locationId)
    src = playerId(src)
    if not src then return fail('INVALID_PAYLOAD') end
    if type(locationId) ~= 'string' or locationId == '' or #locationId > MAX_ID then return fail('INVALID_PAYLOAD') end
    if not WCServices.enabled('clothingStores') then return fail('STORE_DISABLED') end
    local loc = WCLocations.byId(locationId)
    if not loc or loc.type ~= 'clothing' then return fail('LOCATION_NOT_FOUND') end
    if loc.enabled == false then return fail('LOCATION_DISABLED') end
    if not WCLocations.isOpen(loc) then return fail('LOCATION_CLOSED_HOURS') end
    if not WCSessions.accessAllowed(src, loc) then return WCSessions.accessRefusal(src, loc) end
    if not WCSessions.withinRange(src, loc) then return fail('TOO_FAR') end
    TriggerClientEvent('w_clothing:client:openStore', src, locationId)
    return ok({ locationId = locationId })
end

function Api.OpenWardrobe(src, locationId)
    src = playerId(src)
    if not src then return fail('INVALID_PAYLOAD') end
    if locationId ~= nil and (type(locationId) ~= 'string' or locationId == '' or #locationId > MAX_ID) then
        return fail('INVALID_PAYLOAD')
    end
    if not WCServices.enabled('wardrobe') then return fail('WARDROBE_DISABLED') end
    if locationId == nil then
        if not (Config.Wardrobe and Config.Wardrobe.allowRemote == true) then return fail('REMOTE_WARDROBE_DISABLED') end
    elseif not locationId:match('^home:%d+$') then
        local loc = WCLocations.byId(locationId)
        if not loc or loc.type ~= 'wardrobe' then return fail('LOCATION_NOT_FOUND') end
        if loc.enabled == false then return fail('LOCATION_DISABLED') end
        if not WCLocations.isOpen(loc) then return fail('LOCATION_CLOSED_HOURS') end
        if not WCSessions.accessAllowed(src, loc) then return WCSessions.accessRefusal(src, loc) end
        if not WCSessions.withinRange(src, loc) then return fail('TOO_FAR') end
    end
    TriggerClientEvent('w_clothing:client:openWardrobe', src, locationId)
    return ok({ locationId = locationId })
end

function Api.GetOwnedClothes(src)
    src = playerId(src)
    local active = src and WCSessions.activeCharacter(src) or nil
    if not active then return nil end
    local list = WCOwnership.list(active.charid)
    return list
end

function Api.GetOutfits(src)
    src = playerId(src)
    local active = src and WCSessions.activeCharacter(src) or nil
    if not active then return nil end
    local app = WCAppearanceRepo.load(active.charid, { src = src })
    local list = WCOutfits.list(active.charid, app and app.sex or active.sex)
    return list
end

--- Called by w_barber when both run standalone without w_creators so one resource broadcasts remote sync.
function Api.SyncAppearanceFromExternal(src, app)
    src = playerId(src)
    if not src or type(app) ~= 'table' then return false end
    local active = WCSessions.activeCharacter(src)
    if active then WCAppearanceRepo.invalidate(active.charid) end
    WCSync.broadcast(src, app)
    TriggerClientEvent('w_clothing:client:applyAppearance', src, app)
    return true
end

function Api.IsBandanaUp(src)
    src = playerId(src)
    if not src or type(WCClothingActions) ~= 'table' then return false end
    return WCClothingActions.bandanaUp(src) == true
end

exports('OpenClothingStore', function(src, id) return Api.OpenClothingStore(src, id) end)
exports('OpenWardrobe', function(src, id) return Api.OpenWardrobe(src, id) end)
exports('GetOwnedClothes', function(src) return Api.GetOwnedClothes(src) end)
exports('GetOutfits', function(src) return Api.GetOutfits(src) end)
exports('IsBandanaUp', function(src) return Api.IsBandanaUp(src) end)
exports('SyncAppearanceFromExternal', function(src, app) return Api.SyncAppearanceFromExternal(src, app) end)
