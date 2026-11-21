-- =====================================================================
--  server/appearance/repository.lua  —  w_clothing (100% w_lib framework bridge)
--  Never touches characters_appearence or any framework character table directly.
--  Reads skin + clothes via w.framework:getUserSkin / getUserClothes, and saves
--  clothes exclusively via w.framework:updateUserClothes (works natively on
--  w_core + w_creators, VORP, RSG-Core v1/v2 and QBR-Core).
--  Persisted clothing states (hat off, sleeves rolled...) live in w_clothing_states.
-- =====================================================================

WCAppearanceRepo = { cache = {} }
local Repo = WCAppearanceRepo

local MIGRATION_WAIT_MS = 10000
local PERSISTED = { rules = false }
local srcByChar = {} -- [charid] = player server id

local function key(charid) return tostring(charid) end

local function schemaReady()
    if type(WCMigrations) ~= 'table' or type(WCMigrations.waitReady) ~= 'function' then return true end
    return WCMigrations.waitReady(MIGRATION_WAIT_MS) == true
end

local function catalogueReady(sex)
    return next(WCCatalog.forSex(sex == 'female' and 'female' or 'male')) ~= nil
end

function Repo.invalidate(charid)
    if charid ~= nil then Repo.cache[key(charid)] = nil end
end

function Repo.degraded()
    return nil
end

function Repo.rememberSource(charid, src)
    if charid ~= nil and tonumber(src) then srcByChar[key(charid)] = math.tointeger(tonumber(src)) end
end

local function u32nz(v)
    local h = WCUtil.u32(v)
    return (h and h ~= 0) and h or nil
end

local function layerByKey(k)
    if type(WCOverlays) ~= 'table' then return nil end
    if WCOverlays.byId and WCOverlays.byId[k] then return WCOverlays.byId[k] end
    for _, layer in ipairs(WCOverlays.layers or {}) do
        if layer.library == k then return layer end
    end
    return nil
end

local function decodeOverlay(layer, value)
    if type(value) ~= 'table' then return nil end
    local opacity = tonumber(value.opacity)
    if opacity == nil then opacity = 1.0 end
    if opacity > 1 then opacity = opacity / 100 end
    if opacity <= 0 then return nil end
    local style = tonumber(value.style)
    if not style then
        local id = tonumber(value.id)
        local grid = tonumber(value.sheetGrid) or 0
        local set = (value.sexe == 'm' or value.sexe == 'f') and value.sexe or nil
        for idx = 1, layer.styles do
            local tex, cell, texSet = WCOverlays.texture(layer, idx)
            if tex == id and (cell or 0) == grid and (set == nil or texSet == nil or texSet == set) then
                style = idx
                break
            end
        end
    end
    if not style then return nil end
    local color = tonumber(value.color) or (tonumber(value.tint0) and (tonumber(value.tint0) + 1)) or 1
    local out = { style = math.floor(style), color = math.floor(color), opacity = opacity + 0.0 }
    if tonumber(value.color2) then out.color2 = math.floor(tonumber(value.color2))
    elseif tonumber(value.tint1) then out.color2 = math.floor(tonumber(value.tint1)) + 1 end
    if tonumber(value.color3) then out.color3 = math.floor(tonumber(value.color3))
    elseif tonumber(value.tint2) then out.color3 = math.floor(tonumber(value.tint2)) + 1 end
    return out
end

local function loadSavedStates(charid)
    local ok, raw = pcall(w.database.scalar.await,
        'SELECT `states` FROM `w_clothing_states` WHERE `charid` = ? LIMIT 1', { key(charid) })
    if not ok or type(raw) ~= 'string' or raw == '' then return {} end
    local decoded = WCUtil.decode(raw)
    return type(decoded) == 'table' and decoded or {}
end

local function fromFramework(src, charid, skin, clothes)
    local sex = 'male'
    if type(skin) == 'table' then
        if skin.sex == 2 or skin.sex == 'female' or skin.model == 'mp_female' then sex = 'female' end
    else
        local okP, ped = pcall(GetPlayerPed, src)
        if okP and ped and ped ~= 0 and GetEntityModel(ped) == joaat('mp_female') then sex = 'female' end
    end
    if not catalogueReady(sex) then return nil, 'INTERNAL_ERROR' end

    local app = AppearanceSchema.default(sex)
    if type(skin) == 'table' then
        local model = 'mp_' .. sex
        local headHash = u32nz(skin.headHash)
        if not headHash and (tonumber(skin.headIndex) or tonumber(skin.skinTone)) and w and w.component and w.component.getHeadFromSkinTone then
            local name = w.component.getHeadFromSkinTone(model, tonumber(skin.headIndex) or 1, tonumber(skin.skinTone) or 1)
            headHash = name and u32nz(GetHashKey(name)) or nil
        end
        local eyesHash = u32nz(skin.eyesHash)
        if not eyesHash and tonumber(skin.eyesIndex) and w and w.component and w.component.getEyesFromIndex then
            local name = w.component.getEyesFromIndex(model, tonumber(skin.eyesIndex))
            eyesHash = name and u32nz(GetHashKey(name)) or nil
        end
        local teethHash = u32nz(skin.teethHash)
        if not teethHash and tonumber(skin.teethIndex) and w and w.component and w.component.getTeethFromIndex then
            local name = w.component.getTeethFromIndex(model, tonumber(skin.teethIndex))
            teethHash = name and u32nz(GetHashKey(name)) or nil
        end
        local bodyUpperHash = u32nz(skin.bodyUpperHash)
        if not bodyUpperHash and (tonumber(skin.bodiesIndex) or tonumber(skin.skinTone)) and w and w.component and w.component.getBodiesUpperFromSkinTone then
            local name = w.component.getBodiesUpperFromSkinTone(model, tonumber(skin.bodiesIndex) or 1, tonumber(skin.skinTone) or 1)
            bodyUpperHash = name and u32nz(GetHashKey(name)) or nil
        end
        local bodyLowerHash = u32nz(skin.bodyLowerHash)
        if not bodyLowerHash and (tonumber(skin.bodiesIndex) or tonumber(skin.skinTone)) and w and w.component and w.component.getBodiesLowerFromSkinTone then
            local name = w.component.getBodiesLowerFromSkinTone(model, tonumber(skin.bodiesIndex) or 1, tonumber(skin.skinTone) or 1)
            bodyLowerHash = name and u32nz(GetHashKey(name)) or nil
        end

        app.head.head = headHash or app.head.head
        app.head.eyes = eyesHash or app.head.eyes
        app.head.teeth = teethHash or app.head.teeth
        app.body.upper = bodyUpperHash or app.body.upper
        app.body.lower = bodyLowerHash or app.body.lower
        if type(skin.bodyScale) == 'number' and WCUtil.isFinite(skin.bodyScale) then
            app.body.height = skin.bodyScale
        end
        local rawWeight = tonumber(skin.bodyWeight)
        if rawWeight and rawWeight >= 1 and rawWeight <= 21 and rawWeight % 1 == 0 then
            app.body.weight = math.floor(rawWeight)
        else
            local waistHash = u32nz(skin.bodyWeight)
            if waistHash and AppearanceSchema.WAIST_TYPES then
                for i, wh in ipairs(AppearanceSchema.WAIST_TYPES) do
                    if WCUtil.u32(wh) == waistHash then app.body.weight = i; break end
                end
            end
        end
        local buildHash = u32nz(skin.bodyType)
        if buildHash and AppearanceSchema.BODY_BUILDS then
            for i, bh in ipairs(AppearanceSchema.BODY_BUILDS) do
                if WCUtil.u32(bh) == buildHash then app.body.build = i; break end
            end
        end
        if type(skin.hair) == 'table' then app.hair.style = u32nz(skin.hair.hash) or 0
        elseif skin.hair ~= nil then app.hair.style = u32nz(skin.hair) or 0 end
        if sex == 'male' then
            local beard = skin.beards_complete
            if beard == nil then beard = skin.mustache end
            if type(beard) == 'table' then app.hair.facial = u32nz(beard.hash) or 0
            elseif beard ~= nil then app.hair.facial = u32nz(beard) or 0 end
        end
        if type(skin.expressions) == 'table' then
            for k, v in pairs(skin.expressions) do
                local n = tonumber(v)
                if n and WCUtil.isFinite(n) then
                    if n > 1 or n < -1 then n = n / 100 end
                    app.morph[k] = n + 0.0
                end
            end
        end
        if type(skin.overlays) == 'table' then
            app.overlays = {}
            for k, v in pairs(skin.overlays) do
                local layer = type(k) == 'string' and layerByKey(k) or nil
                if layer and layer.sexes[sex] then
                    local o = decodeOverlay(layer, v)
                    if o then app.overlays[layer.id] = o end
                end
            end
        end
    end

    app.clothing.equipped = {}
    app.clothing.tints = {}
    if type(clothes) == 'table' then
        for category, entry in pairs(clothes) do
            if type(category) == 'string' and WCCatalog.isClothing(category) then
                local rawHash = type(entry) == 'table' and (entry.hash or entry.comp) or entry
                local h = WCCatalog.resolve(sex, category, rawHash)
                if h and h ~= 0 then
                    app.clothing.equipped[category] = h
                    if type(entry) == 'table' and entry.palette then
                        local tint = {
                            palette = entry.palette,
                            tint0 = tonumber(entry.tint0) or 0,
                            tint1 = tonumber(entry.tint1) or 0,
                            tint2 = tonumber(entry.tint2) or 0,
                        }
                        if WCCatalog.validTint(category, tint) then
                            app.clothing.tints[category] = tint
                        end
                    end
                end
            end
        end
    end

    local savedStates = loadSavedStates(charid)
    if next(savedStates) ~= nil then
        app.clothing.states = savedStates
    end

    return (AppearanceSchema.sanitize(app, PERSISTED)), nil
end

function Repo.standardClothes(app)
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

--- Load a character's appearance exclusively via w_lib (w.framework:getUserSkin + getUserClothes).
function Repo.load(charid, opts)
    if charid == nil then return nil, { missing = true } end
    local src = (type(opts) == 'table' and tonumber(opts.src)) or srcByChar[key(charid)]
    if src then Repo.rememberSource(charid, src) end

    if not schemaReady() then
        WCDebug.warn('appearance', 'reading %s refused: migrations not ready', key(charid))
        return nil, { error = 'DATABASE_ERROR' }
    end

    local cached = Repo.cache[key(charid)]
    if cached and (type(opts) ~= 'table' or opts.fresh ~= true) then
        return WCUtil.copy(cached.app), { version = AppearanceSchema.VERSION, cached = true, defaultsUsed = {}, degraded = false }
    end

    if not src then return nil, { missing = true } end

    if type(GetResourceState) == 'function' and GetResourceState('w_creators') == 'started' then
        local okCr, cr = pcall(function() return exports.w_creators:GetAppearance(src) end)
        if okCr and type(cr) == 'table' and type(cr.appearance) == 'table' then
            local app = WCUtil.copy(cr.appearance)
            local savedStates = loadSavedStates(charid)
            if next(savedStates) ~= nil then
                app.clothing = type(app.clothing) == 'table' and app.clothing or {}
                app.clothing.states = type(app.clothing.states) == 'table' and app.clothing.states or {}
                for k, v in pairs(savedStates) do app.clothing.states[k] = v end
            end
            app = (AppearanceSchema.sanitize(app, PERSISTED))
            Repo.cache[key(charid)] = { app = WCUtil.copy(app) }
            return WCUtil.copy(app), { version = AppearanceSchema.VERSION, cached = false, defaultsUsed = {}, degraded = false }
        end
    end

    local skin, clothes = nil, nil
    if w and w.framework then
        if type(w.framework.getUserSkin) == 'function' then
            local okS, s = pcall(function() return w.framework:getUserSkin(src) end)
            if okS and type(s) == 'table' then skin = s end
        end
        if type(w.framework.getUserClothes) == 'function' then
            local okC, c = pcall(function() return w.framework:getUserClothes(src) end)
            if okC and type(c) == 'table' then clothes = c end
        end
    end

    local app, err = fromFramework(src, charid, skin, clothes)
    if not app then return nil, { error = err or 'INTERNAL_ERROR' } end

    Repo.cache[key(charid)] = { app = WCUtil.copy(app) }
    return WCUtil.copy(app), { version = AppearanceSchema.VERSION, cached = false, defaultsUsed = {}, degraded = false }
end

--- Persist clothing ownership / outfits / states (`extra`) in DB and save equipped clothes
--  exclusively through w_lib (w.framework:updateUserClothes).
function Repo.save(charid, app, extra, opts)
    if charid == nil then return false, 'CHARACTER_NOT_FOUND' end
    if not catalogueReady(type(app) == 'table' and app.sex) then return false, 'INTERNAL_ERROR' end
    if not schemaReady() then return false, 'DATABASE_ERROR' end

    local src = (type(opts) == 'table' and tonumber(opts.src)) or srcByChar[key(charid)]
    if not src then return false, 'NO_CHARACTER' end

    app = AppearanceSchema.sanitize(app, PERSISTED)
    local queries = {}
    for _, q in ipairs(type(extra) == 'table' and extra or {}) do
        queries[#queries + 1] = q
    end

    local persistedStates = {}
    for group, value in pairs(type(app.clothing) == 'table' and type(app.clothing.states) == 'table' and app.clothing.states or {}) do
        local def = type(WCClothingStates) == 'table' and WCClothingStates.byId and WCClothingStates.byId[group]
        if def and def.persist then persistedStates[group] = value end
    end
    local encodedStates = WCUtil.encode(persistedStates)
    if encodedStates then
        queries[#queries + 1] = {
            query = 'INSERT INTO `w_clothing_states` (`charid`, `states`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `states` = VALUES(`states`)',
            values = { key(charid), encodedStates },
        }
    end

    Repo.invalidate(charid)
    if #queries > 0 then
        local okTx, done = pcall(w.database.transaction.await, queries)
        if not okTx or done ~= true then
            WCDebug.warn('appearance', 'saving clothing metadata for %s failed: %s', key(charid), tostring(done))
            return false, 'DATABASE_ERROR'
        end
    end

    local statesOnly = type(opts) == 'table' and opts.statesOnly == true
    if not statesOnly then
        local stdClothes = Repo.standardClothes(app)
        if w and w.framework and type(w.framework.updateUserClothes) == 'function' then
            local okFw, fwErr = pcall(function()
                w.framework:updateUserClothes(src, WCUtil.copy(stdClothes), true)
            end)
            if not okFw then
                WCDebug.warn('appearance', 'w.framework:updateUserClothes failed for %s: %s', tostring(src), tostring(fwErr))
                return false, 'DATABASE_ERROR'
            end
        end
        if type(GetResourceState) == 'function' and GetResourceState('w_creators') == 'started' and GetResourceState('w_core') ~= 'started' then
            pcall(function()
                exports.w_creators:SetClothes(src, WCUtil.copy(stdClothes), true)
            end)
        end
    end

    Repo.cache[key(charid)] = { app = WCUtil.copy(app) }
    TriggerEvent('w_appearance:updated', src, key(charid), app)
    return true, app
end

AddEventHandler('w_appearance:updated', function(_, charid)
    if charid ~= nil then Repo.invalidate(charid) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for cid, s in pairs(srcByChar) do
        if s == src then
            srcByChar[cid] = nil
            Repo.cache[cid] = nil
        end
    end
end)
