-- =====================================================================
--  config/main.lua  —  w_clothing
--  Standalone Clothing Stores, Wardrobes, Saved Outfits & Clothing States.
--  Works standalone on w_core / VORP / RSG / QBR, and integrates automatically
--  with w_creators when both are running.
-- =====================================================================

Config = {}
Config.Creator = {}
Config.Barber = {}
Config.CosmeticSurgery = {}
Config.Scene = {}

Config.Debug = {
    enabled = false,
    domains = {},
}

-- 'auto' detects w_core / VORP / RSG / QBR automatically, or set 'vorp' | 'rsg' | 'qbr'
Config.Framework = 'auto'

Config.Services = {
    clothingStores  = true,
    wardrobe        = true,
    savedOutfits    = true,
    clothingActions = true,
}

-- Framework character tables (used in standalone mode when w_creators is not installed)
Config.Characters = {
    tables = {
        vorp = 'characters',
        rsg  = 'players',
        qbr  = 'players',
    },
}

-- When running standalone without w_creators, sync saved clothing back to the
-- framework's native clothes store (RSG / VORP / QBR) via w_lib's framework bridge.
Config.Standalone = {
    syncToFramework = true,
    restoreOnSpawn  = true,
}

Config.Swatches = {
    skinOrder = { 1, 4, 3, 5, 2, 6 },
    skin = {
        [1] = '#f1d3b8', [4] = '#dcb08b', [3] = '#c38c62', [5] = '#9e6a45', [2] = '#76492d', [6] = '#4a2d1c',
    },
    hair = {
        BLONDE = '#b58d4c', LIGHT_BLONDE = '#d8bc7d', DARK_BLONDE = '#8c6834', STRAWBERRY_BLONDE = '#c0835a',
        BROWN = '#5b3b23', LIGHT_BROWN = '#7b5332', MEDIUM_BROWN = '#4a2e1b', DARKEST_BROWN = '#2a1a10',
        GINGER = '#a3522a', LIGHT_GINGER = '#c17040', DARK_GINGER = '#793a1e',
        GREY = '#8c8985', LIGHT_GREY = '#bab7b2', DARK_GREY = '#5a5855', UNCLE_GREY = '#a8a8ad',
        SALT_PEPPER = '#6e6b67', JET_BLACK = '#151313',
    },
}

Config.Experimental = {
    metapedRequestPath = false,
    hatAccess          = false,
    clothingAnimations = true,
    variationPreset    = false,
}

Config.Keys = {
    interact        = 'J', -- opens a clothing store or wardrobe (never E)
    clothingActions = nil, -- optional keybind for /clothing panel (players can also use w_clothingwheel)
}

Config.Admin = {
    ace         = 'w_clothing.admin',
    fallbackAce = 'w_creators.admin', -- keeps existing staff permissions working during migration
}
