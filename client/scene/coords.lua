-- =====================================================================
--  client/scene/coords.lua  —  lightweight coordinate helper for standalone service flows
-- =====================================================================

CreatorScene = CreatorScene or {}

function CreatorScene.coords(c)
    if type(c) ~= 'table' and type(c) ~= 'userdata' and type(c) ~= 'vector4' and type(c) ~= 'vector3' then
        return nil
    end
    local x, y, z, h
    local okArr = pcall(function() x, y, z, h = c[1], c[2], c[3], c[4] end)
    if not okArr or x == nil then
        local ok = pcall(function() x, y, z, h = c.x, c.y, c.z, c.w or c.heading end)
        if not ok then return nil end
    end
    x, y, z, h = tonumber(x), tonumber(y), tonumber(z), tonumber(h) or 0.0
    if not (WCUtil.isFinite(x) and WCUtil.isFinite(y) and WCUtil.isFinite(z)) then return nil end
    return x + 0.0, y + 0.0, z + 0.0, h + 0.0
end

function CreatorScene.isLoaded() return false end
function CreatorScene.isIsolated() return false end
