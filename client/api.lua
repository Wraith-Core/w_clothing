-- =====================================================================
--  client/api.lua  —  w_clothing public client API
-- =====================================================================

WCClientApi = {}
local Api = WCClientApi

local MAX_ID = 64
local BODY_PARTS = {
    heads = { 'head', 'head' }, eyes = { 'head', 'eyes' }, teeth = { 'head', 'teeth' },
    BODIES_UPPER = { 'body', 'upper' }, BODIES_LOWER = { 'body', 'lower' },
    hair = { 'hair', 'style' }, mustache = { 'hair', 'facial' }, beards_complete = { 'hair', 'facial' },
}

function Api.appearance()
    return WCState.get()
end

function Api.currentOutfit()
    local app = WCState.get()
    if type(app) ~= 'table' or type(app.clothing) ~= 'table' then return nil end
    local c = app.clothing
    return {
        outfit = c.outfit,
        equipped = WCUtil.copy(type(c.equipped) == 'table' and c.equipped or {}),
        tints = WCUtil.copy(type(c.tints) == 'table' and c.tints or {}),
        states = WCUtil.copy(type(c.states) == 'table' and c.states or {}),
    }
end

function Api.equippedCategory(category)
    if type(category) ~= 'string' or category == '' or #category > MAX_ID then return nil end
    local app = WCState.get()
    if type(app) ~= 'table' then return nil end
    local part = BODY_PARTS[category]
    if part then
        local section = app[part[1]]
        local value = type(section) == 'table' and WCUtil.u32(section[part[2]]) or nil
        if not value or value == 0 then return nil end
        return value
    end
    local clothing = type(app.clothing) == 'table' and app.clothing or {}
    local equipped = type(clothing.equipped) == 'table' and clothing.equipped or {}
    local hash = WCUtil.u32(equipped[category])
    if not hash or hash == 0 then return nil end
    local tints = type(clothing.tints) == 'table' and clothing.tints or {}
    local tint = type(tints[category]) == 'table' and WCUtil.copy(tints[category]) or nil
    return hash, tint
end

function Api.isBusy()
    return WCState.inEditor() or (WCServiceFlow and WCServiceFlow.busy()) or (WCBoard and WCBoard.isOpen())
        or (WCClothing and WCClothing.busy()) or false
end

exports('OpenClothingStore', function(locationId, look)
    CreateThread(function() WCStore.open(locationId, look) end)
    return true
end)
exports('GetAppearance', function() return Api.appearance() end)
exports('GetCurrentOutfit', function() return Api.currentOutfit() end)
exports('GetEquippedCategory', function(category) return Api.equippedCategory(category) end)
exports('IsBusy', function() return Api.isBusy() end)
