-- =====================================================================
--  client/core/state.lua  —  WCState (ARCHITECTURE.md §3.2)
--  The local client's character state: the active character, its saved v3 appearance, and the
--  named client locks that keep two flows (editor, selection, spawn, respawn, clothing action,
--  service visit) from running at the same time.
-- =====================================================================

WCState = {
    character = nil,  -- { charid, sex } or nil
    appearance = nil, -- the saved v3 appearance of the local character (never the editor's working copy)
}

--- The named client locks. Any string is accepted; these are the ones the contract names.
WCState.LOCKS = {
    editor = true, selection = true, spawn = true, respawn = true, clothingAction = true,
    service = true, -- a store / wardrobe / barber / surgery visit (WCServiceFlow.LOCK)
}

local locks = {}

--- Store the saved appearance of the local character (a copy: callers keep their own table).
--  The character's sex follows the appearance.
---@param app table|nil
function WCState.set(app)
    if type(app) ~= 'table' then
        WCState.appearance = nil
        return
    end
    WCState.appearance = WCUtil.copy(app)
    if WCState.character and type(app.sex) == 'string' then
        WCState.character.sex = app.sex
    end
end

--- The saved appearance (a copy), or nil.
--  When running alongside w_creators, initializes local state from w_creators' active character appearance
--  without overwriting w_clothing's own runtime/saved clothing states on subsequent reads.
function WCState.get()
    if not WCState.appearance and GetResourceState('w_creators') == 'started' then
        local ok, ext = pcall(function() return exports.w_creators:GetAppearance() end)
        if ok and type(ext) == 'table' then
            WCState.appearance = WCUtil.copy(ext)
        end
    end
    if not WCState.appearance then return nil end
    return WCUtil.copy(WCState.appearance)
end

-- Keep local state warm whenever w_creators applies/reloads the character's appearance,
-- preserving w_clothing's current clothing states when the equipped items are unchanged.
RegisterNetEvent('w_creators:client:applyAppearance', function(app)
    if type(app) == 'table' and not WCState.inEditor() then
        local prevStates = WCState.appearance and WCState.appearance.clothing and WCState.appearance.clothing.states
        local prevEq = WCState.appearance and WCState.appearance.clothing and WCState.appearance.clothing.equipped
        local nextApp = WCUtil.copy(app)
        if type(prevStates) == 'table' and type(prevEq) == 'table' and type(nextApp.clothing) == 'table' then
            nextApp.clothing.states = type(nextApp.clothing.states) == 'table' and nextApp.clothing.states or {}
            local nextEq = type(nextApp.clothing.equipped) == 'table' and nextApp.clothing.equipped or {}
            if WCUtil.deepEqual(prevEq, nextEq) then
                for k, v in pairs(prevStates) do
                    nextApp.clothing.states[k] = v
                end
            end
        end
        WCState.set(nextApp)
    end
end)

-- Standalone mode (without w_creators): reload & apply saved appearance after framework character load.
local function onFrameworkLoaded()
    if GetResourceState('w_creators') == 'started' then return end
    if Config.Standalone and Config.Standalone.restoreOnSpawn == false then return end
    CreateThread(function()
        Wait(1500)
        if GetResourceState('w_creators') == 'started' then return end
        local ok, res = pcall(w.callback.await, 'w_clothing:appearance:reload', false)
        if ok and type(res) == 'table' and res.ok and type(res.data) == 'table' and type(res.data.appearance) == 'table' then
            if Appearance and Appearance.Sync and Appearance.Sync.applyOwn then
                Appearance.Sync.applyOwn(res.data.appearance, { keepRuntime = true })
            else
                WCState.set(res.data.appearance)
            end
        end
    end)
end

for _, ev in ipairs({
    'RSGCore:Client:OnPlayerLoaded',
    'QBCore:Client:OnPlayerLoaded',
    'vorp:SelectedCharacter',
    'w_core:client:playerLoaded',
}) do
    RegisterNetEvent(ev, onFrameworkLoaded)
end

--- Set (or clear with nil) the active character { charid, sex }.
function WCState.setCharacter(charid, sex)
    if charid == nil then
        WCState.character = nil
        return
    end
    WCState.character = { charid = charid, sex = sex }
end

--- Forget the character and its appearance (character switch, logout).
function WCState.clear()
    WCState.character = nil
    WCState.appearance = nil
end

--- A named client lock.
--    busy(name)         -> boolean: is it held?
--    busy(name, true)   -> boolean: acquired (false when it was already held)
--    busy(name, false)  -> true: released
---@param name string
---@param value? boolean
---@return boolean
function WCState.busy(name, value)
    if type(name) ~= 'string' then return false end
    if value == nil then return locks[name] == true end
    if value then
        if locks[name] then return false end
        locks[name] = true
        return true
    end
    locks[name] = nil
    return true
end

--- Is any appearance editor open (the editor lock, or an open WCEditor session)?
function WCState.inEditor()
    if locks.editor then return true end
    local editor = WCEditor
    if type(editor) == 'table' and type(editor.session) == 'function' then
        local ok, session = pcall(editor.session)
        if ok and session then return true end
    end
    return false
end
