-- =====================================================================
--  config/locations.lua  —  w_clothing
--  Clothing stores and wardrobes. Editable in-game with /clothingadmin.
-- =====================================================================

Config.LocationDefaults = {
    clothing = {
        interactionRadius = 2.0,
        prompt = true,
        npc = false,
        blip = { sprite = 'blip_shop_tailor', label = 'متجر الملابس' },
        camera = 'fullBody',
        storeProfile = 'general',
        pricingProfile = 'standard',
        outfits = true,
    },
    wardrobe = {
        interactionRadius = 2.0,
        prompt = true,
        npc = false,
        blip = { sprite = 'blip_shop_wardrobe', label = 'الخزانة' },
        camera = 'fullBody',
    },
}

Config.Locations = {
    -- Clothing stores (coords = catalogue book, preview = fitting stand)
    {
        id = 'valentine_clothing', type = 'clothing', enabled = true,
        label = 'متجر الملابس', town = 'فالنتاين',
        coords = vector3(-326.17, 773.757, 117.5),
        book = vector4(-326.17, 773.757, 117.5, -170.0),
        preview = vector4(-329.31, 775.11, 120.63, 294.79),
        npc = { model = 'S_M_M_Tailor_01', coords = vector4(-325.67, 772.63, 116.44, 11.3) },
    },
    {
        id = 'saintdenis_clothing', type = 'clothing', enabled = true,
        label = 'متجر الملابس', town = 'سانت دينيس',
        coords = vector3(2554.619, -1167.834, 53.746),
        book = vector4(2554.619, -1167.834, 53.746, 0.0),
        preview = vector4(2555.89, -1161.23, 52.7, 12.85),
        npc = { model = 'S_M_M_Tailor_01', coords = vector4(2554.6, -1166.83, 52.7, 180.95) },
    },
    {
        id = 'blackwater_clothing', type = 'clothing', enabled = true,
        label = 'متجر الملابس', town = 'بلاك ووتر',
        coords = vector3(-761.98, -1292.61, 43.885),
        book = vector4(-761.98, -1292.61, 43.885, 180.0),
        preview = vector4(-767.74, -1295.17, 42.84, 304.87),
        npc = { model = 'S_M_M_Tailor_01', coords = vector4(-761.75, -1293.92, 42.84, 357.16) },
    },
    {
        id = 'tumbleweed_clothing', type = 'clothing', enabled = true,
        label = 'متجر الملابس', town = 'تمبلويد',
        coords = vector3(-5486.660, -2936.75, -0.346),
        book = vector4(-5486.660, -2936.75, -0.346, -144.0),
        preview = vector4(-5479.77, -2933.07, -1.36, 181.29),
        npc = false,
    },

    -- Wardrobes (wear owned clothing & saved outfits for free)
    {
        id = 'rhodes_wardrobe', type = 'wardrobe', enabled = true,
        label = 'الخزانة', town = 'رودز',
        coords = vector3(1223.55, -1288.67, 76.9),
    },
    {
        id = 'valentine_wardrobe', type = 'wardrobe', enabled = true,
        label = 'الخزانة', town = 'فالنتاين',
        coords = vector3(-184.5, 625.02, 114.09),
    },
    {
        id = 'saintdenis_wardrobe', type = 'wardrobe', enabled = true,
        label = 'الخزانة', town = 'سانت دينيس',
        coords = vector3(2549.82, -1169.58, 53.68),
    },
}
