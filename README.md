# w_clothing

Standalone RedM clothing stores, personal wardrobes, owned clothing catalog, colorway tints, saved outfits, and clothing state toggles for **Wraith Framework RedM**.

## Key Features

- **Clothing Stores:** Interactive tailor shops across RDR2 towns (press `J`) with categorized hierarchical browsing, live preview, and colorway tints.
- **Personal Wardrobes & Outfits:** Owned clothing persistence (`w_creators_clothes`, `w_creators_outfits`, `w_creators_colorways`, `w_clothing_states`), outfit saving, equipping, and management.
- **Clothing States:** Toggle hat, bandana, rolled sleeves, collar, and coat states.
- **In-Game Admin Board:** `/clothingadmin` (ACE `w_clothing.admin`) to configure store and wardrobe locations.

## Installation

1. Place `w_clothing` in `resources/[wraith]/w_clothing`.
2. Import `sql/install.sql` (or allow auto-migrations on startup).
3. Add `ensure w_clothing` to `server.cfg` after `w_lib` and `w_creators`.

## Key Exports

```lua
exports.w_clothing:OpenClothingStore(src, locationId)
exports.w_clothing:OpenWardrobe(src, locationId)
exports.w_clothing:GetOutfits()
exports.w_clothing:GetOwnedClothes()
exports.w_clothing:IsBusy()
```

## Documentation & Links

- **Developer Docs:** https://wraith-core.github.io/docs/#/resources/character-appearance
- **txAdmin Recipe:** https://github.com/Wraith-Core/txAdminRecipe
- **Credits:** See [CREDITS.md](CREDITS.md)
