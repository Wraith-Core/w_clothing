-- =====================================================================
--  config/board.lua  —  w_clothing admin board (/clothingadmin)
-- =====================================================================

Config.Board = {
    command     = 'clothingadmin',
    maxDistance = 80.0,
    radius      = { min = 0.5, max = 10.0, default = 2.0 },
    labelMax    = 48,

    npcModels = {
        clothing = { 'S_M_M_Tailor_01', 'u_m_m_nbxgeneralstoreowner_01', 'u_f_m_tumgeneralstoreowner_01' },
        wardrobe = { 'a_m_m_valtownfolk_01', 'a_f_m_valtownfolk_01' },
    },

    chairModels  = {},
    previewModel = 'a_m_m_valtownfolk_01',

    blipSprites = {
        clothing = 'blip_shop_tailor',
        wardrobe = 'blip_shop_wardrobe',
    },
}
