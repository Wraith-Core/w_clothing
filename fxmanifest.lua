fx_version "adamant"
games { "rdr3" }
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'
name 'w_clothing'
author 'Wraith Studio'
description 'Standalone clothing stores, wardrobes, saved outfits and clothing states. Compatible with w_core, VORP, RSG and QBR.'
version '1.0.2'

shared_scripts {
    '@w_lib/init.lua',
    'config/main.lua',
    'config/locations.lua',
    'config/clothing.lua',
    'config/wardrobe.lua',
    'config/outfits.lua',
    'config/board.lua',
    'shared/util.lua',
    'shared/result.lua',
    'shared/debug.lua',
    'shared/services.lua',
    'shared/locations.lua',
    'shared/morphology.lua',
    'shared/overlays.lua',
    'shared/catalog.lua',
    'shared/rules.lua',
    'shared/appearance.lua',
    'shared/clothing_states.lua',
}

client_scripts {
    'client/natives/metaped.lua',
    'client/natives/ped.lua',
    'client/natives/clothing.lua',
    'client/natives/camera.lua',
    'client/natives/scene.lua',
    'client/natives/ui.lua',
    'client/core/locale.lua',
    'client/core/ui.lua',
    'client/core/state.lua',
    'client/appearance/pipeline.lua',
    'client/appearance/overlays.lua',
    'client/appearance/sync.lua',
    'client/camera/camera.lua',
    'client/scene/coords.lua',
    'client/scene/environment.lua',
    'client/editor/tree.lua',
    'client/editor/editor.lua',
    'client/editor/panel.lua',
    'client/clothing/catalogue.lua',
    'client/clothing/escort.lua',
    'client/services/locations.lua',
    'client/clothing/store.lua',
    'client/clothing/states.lua',
    'client/wardrobe/wardrobe.lua',
    'client/services/board.lua',
    'client/api.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bridge/logging.lua',
    'server/bridge/framework.lua',
    'server/core/migrations.lua',
    'server/core/security.lua',
    'server/core/refunds.lua',
    'server/core/economy.lua',
    'server/core/sessions.lua',
    'server/appearance/repository.lua',
    'server/appearance/sync.lua',
    'server/scene.lua',
    'server/clothing/ownership.lua',
    'server/clothing/store.lua',
    'server/clothing/states.lua',
    'server/wardrobe/outfits.lua',
    'server/wardrobe/wardrobe.lua',
    'server/clothing/items.lua',
    'server/locations/store.lua',
    'server/api.lua',
}

ui_page 'web/build/index.html'

files {
    'locales/*.json',
    'web/build/index.html',
    'web/build/tex/*.png',
    'web/build/tex/ui/*.png',
    'web/build/tex/cloth/*.png',
    'web/build/fonts/*.woff2',
    'web/build/sounds/*.mp3',
    'web/build/img/*.jpg',
}

dependencies {
    '/onesync',
    'w_lib',
    'oxmysql',
}

w_lib {
    'locale',
    'component',
    'callback',
    'framework-bridge',
}

escrow_ignore {
    'config/*.lua',
    'server/bridge/logging.lua',
}
