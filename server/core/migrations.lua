-- =====================================================================
--  server/core/migrations.lua  —  w_clothing idempotent schema migrations
--  Character skin & equipped clothes are read and saved exclusively through
--  w_lib (w.framework), so w_clothing never creates or touches any character
--  appearance table (works natively on w_core, VORP, RSG and QBR).
-- =====================================================================

WCMigrations = { list = {}, done = false, ok = nil, applied = {} }
local M = WCMigrations

function M.register(id, fn, verify)
    assert(type(id) == 'string' and type(fn) == 'function', 'WCMigrations.register(id, fn, verify?)')
    assert(verify == nil or type(verify) == 'function', 'WCMigrations.register: verify must be a function')
    for _, m in ipairs(M.list) do
        if m.id == id then error('duplicate migration id ' .. id) end
    end
    M.list[#M.list + 1] = { id = id, fn = fn, verify = verify }
end

function M.columnsExist(t, columns)
    for _, c in ipairs(columns) do
        if not M.columnExists(t, c) then return false end
    end
    return true
end

function M.tableExists(t)
    local n = w.database.scalar.await(
        'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { t })
    return (tonumber(n) or 0) > 0
end

function M.columnExists(t, c)
    local n = w.database.scalar.await(
        'SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
        { t, c })
    return (tonumber(n) or 0) > 0
end

function M.addColumn(t, c, definition)
    if M.columnExists(t, c) then return false end
    w.database.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(t, c, definition))
    return true
end

function M.waitReady(timeoutMs)
    WCUtil.waitUntil(function() return M.done end, timeoutMs or 30000, 100)
    return M.done and M.ok == true
end

function M.run()
    if M.running then return false, {} end
    M.running = true
    local applied = {}
    local ok, err = pcall(function()
        w.database.query.await([[
            CREATE TABLE IF NOT EXISTS `w_clothing_migrations` (
                `id` VARCHAR(64) NOT NULL,
                `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        ]])
        local seen = {}
        for _, row in ipairs(w.database.query.await('SELECT id FROM w_clothing_migrations') or {}) do
            seen[row.id] = true
        end
        for _, m in ipairs(M.list) do
            if not seen[m.id] then
                local stepOk, stepErr = pcall(m.fn)
                if not stepOk then error(('migration %s failed: %s'):format(m.id, tostring(stepErr)), 0) end
                w.database.insert.await('INSERT INTO w_clothing_migrations (id) VALUES (?)', { m.id })
                applied[#applied + 1] = m.id
                WCDebug.log('migrations', 'applied %s', m.id)
            elseif m.verify and not m.verify() then
                WCDebug.warn('migrations', '%s is recorded but its schema is missing: applying it again', m.id)
                local stepOk, stepErr = pcall(m.fn)
                if not stepOk then error(('migration %s failed: %s'):format(m.id, tostring(stepErr)), 0) end
                if not m.verify() then error(('migration %s: the schema is still incomplete'):format(m.id), 0) end
                applied[#applied + 1] = m.id
            end
        end
    end)
    M.running = false
    M.done, M.ok, M.applied = true, ok, applied
    if not ok then
        print(('^1[w_clothing] database migration stopped: %s^0'):format(tostring(err)))
        return false, applied
    end
    return true, applied
end

M.register('001_owned_clothes', function()
    w.database.query.await([[
        CREATE TABLE IF NOT EXISTS `w_creators_clothes` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `charid` VARCHAR(100) NOT NULL,
            `hash` BIGINT NOT NULL,
            `category` VARCHAR(64) NOT NULL,
            `palette` VARCHAR(64) NULL,
            `tint0` INT NULL,
            `tint1` INT NULL,
            `tint2` INT NULL,
            `source` VARCHAR(16) NULL,
            `acquired_at` TIMESTAMP NULL,
            `price_paid` DECIMAL(10,2) NULL,
            `currency` VARCHAR(8) NULL,
            PRIMARY KEY (`id`),
            INDEX `charid_idx` (`charid`),
            UNIQUE KEY `char_item` (`charid`, `hash`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    ]])
    M.addColumn('w_creators_clothes', 'source', 'VARCHAR(16) NULL')
    M.addColumn('w_creators_clothes', 'acquired_at', 'TIMESTAMP NULL')
    M.addColumn('w_creators_clothes', 'price_paid', 'DECIMAL(10,2) NULL')
    M.addColumn('w_creators_clothes', 'currency', 'VARCHAR(8) NULL')
end, function()
    return M.tableExists('w_creators_clothes')
        and M.columnsExist('w_creators_clothes', { 'source', 'acquired_at', 'price_paid', 'currency' })
end)

M.register('002_outfits_colorways_states', function()
    w.database.query.await([[
        CREATE TABLE IF NOT EXISTS `w_creators_outfits` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `charid` VARCHAR(100) NOT NULL,
            `name` VARCHAR(64) NOT NULL,
            `data` LONGTEXT NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NULL,
            PRIMARY KEY (`id`),
            INDEX `charid_idx` (`charid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    ]])
    w.database.query.await([[
        CREATE TABLE IF NOT EXISTS `w_creators_colorways` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `charid` VARCHAR(100) NOT NULL,
            `hash` BIGINT NOT NULL,
            `palette` VARCHAR(64) NOT NULL,
            `tint0` INT NOT NULL,
            `tint1` INT NOT NULL,
            `tint2` INT NOT NULL,
            `price_paid` DECIMAL(10,2) NULL,
            `currency` VARCHAR(8) NULL,
            `acquired_at` TIMESTAMP NULL,
            PRIMARY KEY (`id`),
            INDEX `charid_idx` (`charid`),
            UNIQUE KEY `char_colorway` (`charid`, `hash`, `palette`, `tint0`, `tint1`, `tint2`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    ]])
    w.database.query.await([[
        CREATE TABLE IF NOT EXISTS `w_clothing_states` (
            `charid` VARCHAR(100) NOT NULL,
            `states` LONGTEXT NOT NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`charid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    ]])
end, function()
    return M.tableExists('w_creators_outfits') and M.tableExists('w_creators_colorways')
        and M.tableExists('w_clothing_states')
end)

M.register('003_clothing_locations', function()
    w.database.query.await([[
        CREATE TABLE IF NOT EXISTS `w_creators_locations` (
            `id` VARCHAR(64) NOT NULL,
            `type` VARCHAR(16) NOT NULL,
            `data` LONGTEXT NOT NULL,
            `position` INT NOT NULL DEFAULT 0,
            `updated_by` VARCHAR(100) NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    ]])
    local existing = tonumber(w.database.scalar.await(
        "SELECT COUNT(*) FROM `w_creators_locations` WHERE `type` IN ('clothing', 'wardrobe')")) or 0
    if existing == 0 then
        for index, loc in ipairs((Config and Config.Locations) or {}) do
            if type(loc) == 'table' and (loc.type == 'clothing' or loc.type == 'wardrobe') and type(loc.id) == 'string' then
                local data = WCLocations.encode(loc)
                local encoded = data and WCUtil.encode(data)
                if encoded then
                    w.database.query.await(
                        'INSERT IGNORE INTO `w_creators_locations` (`id`, `type`, `data`, `position`) VALUES (?, ?, ?, ?)',
                        { loc.id, tostring(loc.type), encoded, index })
                end
            end
        end
    end
end, function()
    return M.tableExists('w_creators_locations')
end)

w.database.ready(function()
    M.run()
end)
