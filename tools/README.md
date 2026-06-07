# Cruzero asset pipeline (fal.ai)

Generates every on-brand image the app references and wires it into
`Assets.xcassets`. No external npm dependencies — pure Node (built-in `fetch`),
Node 18+. Uses macOS `sips` to transcode to PNG when fal returns WebP
(`recraft-v3` ignores `output_format` and returns WebP, which `actool` rejects
by extension), so all catalog assets are real `.png`.

## The contract

`asset-manifest.json` is the single source of truth: `id → prompt, model, size,
category, target screen`. The generated PNGs (`Cruzero/Resources/Generated/`)
are **gitignored** and regenerated from the manifest; the resulting imagesets in
`Assets.xcassets/Generated/` **are** committed.

Two models, picked per asset `type`:

| type           | model                  | used for                                        |
| -------------- | ---------------------- | ----------------------------------------------- |
| `illustration` | `fal-ai/recraft-v3`    | explainer/welcome heroes, glyphs, empty states, grain tile, app icon |
| `photo`        | `fal-ai/flux-pro/v1.1` | cruiser profile photos, ships, ports            |

A shared `styleSuffix` per type is appended to every prompt so the set stays
visually coherent (warm Mediterranean-at-dusk illustrations; candid amateur
golden-hour photos).

## Run it

```bash
# 1. paste your key (gitignored)
cp tools/.env.example tools/.env        # then edit FAL_KEY=...

# 2. inspect prompts without spending anything
node tools/generate-assets.mjs --dry-run

# 3. generate (≈54 images) then import into the asset catalog
node tools/generate-assets.mjs
node tools/import-assets.mjs
```

Or with npm scripts (run from `tools/`): `npm run generate:dry`, `npm run assets`.

### Useful flags

- `--only <name>` — single asset, e.g. `--only ship-1` (or a prefix like `--only cruiser-maya`)
- `--category <cat>` — `hero | cruiser | ship | port | glyph | empty | texture | icon`
- `--force` — regenerate even if the PNG already exists
- `--concurrency <n>` — parallel requests (default 4)
- `import --clean` — drop imagesets whose source PNG is gone

## Without a key

`generate-assets.mjs` exits cleanly (status 0) with instructions when `FAL_KEY`
is unset — generation is intentionally blocked per `MOCKUP.md`. The app still
builds: `Avatar`, `PhotoTile`, and `PillChip` render placeholder fallbacks and
`TextureBackground` draws a procedural grain until real assets land.
