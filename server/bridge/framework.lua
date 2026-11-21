-- =====================================================================
--  server/bridge/framework.lua  —  w_clothing (100% w_lib bridge)
--  All framework identity, money, skin, clothes and job operations go
--  exclusively through w_lib (w.framework), supporting w_core, VORP,
--  RSG-Core (v1/v2) and QBR-Core with zero direct character-table SQL.
-- =====================================================================

if type(CreatorLogs) ~= 'table' then
    local code = LoadResourceFile(GetCurrentResourceName(), 'server/bridge/logging.lua')
    local ok, err = false, 'server/bridge/logging.lua is missing'
    if code then
        local loader
        loader, err = load(code, '@w_clothing/server/bridge/logging.lua', 't', _ENV)
        if loader then ok, err = pcall(loader) end
    end
    if not ok then
        print(('^3[w_clothing] Optional logging bootstrap failed: %s. Store continues.^0'):format(tostring(err)))
    end
end

if type(CreatorLogs) ~= 'table' or type(CreatorLogs.Emit) ~= 'function'
    or type(CreatorLogs.Register) ~= 'function' then
    CreatorLogs = {
        Emit = function() return false end,
        Register = function() return false end,
    }
end

local logTypesRegistered = false

local function registerLogTypes()
    if logTypesRegistered then return end
    logTypesRegistered = CreatorLogs.Register(function(logger)
        logger.RegisterScript({ label = 'Clothing Store' })

        logger.RegisterLogType({
            key = 'clothing_purchased', label = 'Clothing Purchased',
            channel = 'clothing-store', severity = 'info', class = 'economy',
            description = 'شراء قطع ملابس (وألوانها) من متجر الملابس.',
            schema = { charid = { type = 'string', required = true }, items = 'any', price = 'any', currency = 'any', store = 'any' },
        })
        logger.RegisterLogType({
            key = 'clothing_sold', label = 'Clothing Sold Back',
            channel = 'clothing-store', severity = 'info', class = 'economy',
            description = 'بيع قطعة ملابس مشتراة إلى المتجر.',
            schema = { charid = { type = 'string', required = true }, hash = 'any', category = 'any', price = 'any', currency = 'any', paid = 'any', store = 'any' },
        })
        logger.RegisterLogType({
            key = 'clothing_item', label = 'Clothing Wrapped / Unwrapped',
            channel = 'clothing-items', severity = 'info', class = 'economy',
            description = 'قطعة ملابس لُفّت في الحقيبة أو فُتحت منها، أو بطاقة طقم أُعطيت.',
            schema = { charid = { type = 'string', required = true }, action = 'any', hash = 'any', category = 'any', item = 'any' },
        })
        logger.RegisterLogType({
            key = 'outfit_saved', label = 'Outfit Saved',
            channel = 'character-wardrobe', severity = 'info', class = 'system',
            description = 'حُفظ طقم ملابس في الخزانة أو عُدّل.',
            schema = { charid = { type = 'string', required = true }, outfitId = 'any', name = 'any' },
        })
        logger.RegisterLogType({
            key = 'appearance_changed', label = 'Clothing Changed',
            channel = 'clothing-store', severity = 'info', class = 'system',
            description = 'تغيير ملابس الشخصية أو حالتها.',
            schema = { charid = { type = 'string', required = true }, sections = 'any', kind = 'any' },
        })
        logger.RegisterLogType({
            key = 'service_place_changed', label = 'Clothing Location Changed',
            channel = 'clothing-admin', severity = 'info', class = 'admin.action',
            description = 'تعديل متجر ملابس أو خزانة من لوحة الإدارة.',
            schema = { adminAction = { type = 'string', required = true }, place = 'any', placeType = 'any', detail = 'any' },
        })
        logger.RegisterLogType({
            key = 'security_violation', label = 'Security Violation',
            channel = 'clothing-tamper', severity = 'error', class = 'system',
            description = 'طلب غير سليم رفضه الخادم.',
            schema = { kind = { type = 'string', required = true }, detail = 'any' },
        })
        logger.RegisterLogType({
            key = 'economy_refund_failed', label = 'Economy Refund Failed',
            channel = 'clothing-store', severity = 'error', class = 'economy',
            description = 'تعذّر إرجاع المبلغ بعد فشل الحفظ؛ يُعاد بالمعرّف.',
            schema = { receipt = 'any', charid = 'any', amount = 'any', currency = 'any' },
        })
    end)
end

CreateThread(function()
    Wait(2000)
    registerLogTypes()
end)

AddEventHandler('onResourceStart', function(name)
    if name == 'w_logs' then
        logTypesRegistered = false
        CreateThread(function() Wait(1500); registerLogTypes() end)
    end
end)

-- =====================================================================
--  Bridge (100% w_lib w.framework)
-- =====================================================================
Bridge = {}

function Bridge.GetCharId(src)
    if type(GetResourceState) == 'function' and GetResourceState('w_creators') == 'started' then
        local ok, active = pcall(function() return exports.w_creators:GetActiveCharacter(src) end)
        if ok and type(active) == 'table' and active.charid ~= nil and tostring(active.charid) ~= '' then
            return tostring(active.charid)
        end
        return nil
    end
    if w and w.framework and type(w.framework.getUserIdentifiers) == 'function' then
        local ok, ids = pcall(function() return w.framework:getUserIdentifiers(src) end)
        if ok and type(ids) == 'table' then
            local isVorp = type(w.framework.is) == 'function' and w.framework:is('vorp')
            if isVorp and ids.charid ~= nil and tostring(ids.charid) ~= '' then
                local cid = tostring(ids.charid)
                return cid:find('^vorp:') and cid or ('vorp:' .. cid)
            end
            local cid = (ids.charid ~= nil and ids.charid ~= 0 and ids.charid ~= '0' and tostring(ids.charid) ~= '')
                and tostring(ids.charid)
                or (type(ids.identifier) == 'string' and ids.identifier ~= '' and ids.identifier or nil)
            return cid
        end
    end
    return nil
end

function Bridge.GetLicense(src)
    if w and w.framework and type(w.framework.getUserIdentifiers) == 'function' then
        local ok, ids = pcall(function() return w.framework:getUserIdentifiers(src) end)
        if ok and type(ids) == 'table' and type(ids.identifier) == 'string' and ids.identifier ~= '' then
            return ids.identifier
        end
    end
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return nil
end

function Bridge.JobLabel(src, name)
    if type(name) ~= 'string' or name == '' then return nil end
    if w and w.framework and type(w.framework.getCore) == 'function' then
        local ok, core = pcall(function() return w.framework:getCore() end)
        local shared = ok and type(core) == 'table' and core.Shared or nil
        local def = type(shared) == 'table' and type(shared.Jobs) == 'table' and shared.Jobs[name] or nil
        if type(def) == 'table' then
            local okk, key = pcall(function() return exports.w_lib:getPlayerLocaleKey(src) end)
            local label = (okk and key == 'ar') and def.label_ar or nil
            if type(label) ~= 'string' or label == '' then label = def.label end
            if type(label) == 'string' and label ~= '' then return label end
        end
    end
    return name
end

function Bridge.Notify(src, msg, kind)
    if not src or type(msg) ~= 'string' or msg == '' then return end
    pcall(function() w.notify(src, { description = msg, type = kind or 'inform' }) end)
end
