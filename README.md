# Cruise Wallet — Premium SwiftUI Mockup

A native SwiftUI re-imagining of the `cruise-wallet` React Native app, built to feel
significantly more premium using **iOS 26 Liquid Glass**, a purpose-built **Metal**
ocean shader, **SwiftUI** spring/zoom animation, and **Swift Charts**. UI/UX only —
fully mocked, no backend.

See **[MOCKUP.md](MOCKUP.md)** for the full design rationale and blueprint.

## Surfaces

1. **Welcome** — live `OceanWave` Metal backdrop, glass logo lockup, typewriter headline, glass CTAs.
2. **Home** — collapsing header over full-bleed glass cruise cards (liquid-glass info bar + countdown chip).
3. **Zoom transition** — `matchedTransitionSource` → `.navigationTransition(.zoom)` (the native successor to RN's `Link.AppleZoom`).
4. **Sailing (boarding pass)** — stretchy parallax hero, glass stat grid, perforated tear line, glass segmented control → **Voyage** / **Widgets**.
   - **Voyage** — `CountdownRing` + `VoyageProgressChart` (Swift Charts), voyage stats, and entry points into the Ship screen and full Itinerary.
   - **Widgets** — glass home-screen widget previews + photo-style picker + background history.
5. **Ship** — stretchy photo hero, glass spec grid, amenities (pushed from Voyage).
6. **Full Itinerary** — glass day-by-day timeline (pushed from Voyage).

## Build & run

Requires Xcode 26+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate
open CruiseWallet.xcodeproj          # ⌘R on an iOS 26 simulator
```

## fal.ai assets (optional)

The app ships with labelled placeholder images so it builds and runs immediately.
To generate real ship/port photography:

```bash
cd tools
cp .env.example .env                 # paste your FAL_KEY
npm install
node generate-assets.mjs             # generates into CruiseWallet/Resources/Generated
node import-assets.mjs               # wires them into Assets.xcassets
cd .. && xcodegen generate           # pick up the new imagesets
```

Asset names in `tools/asset-manifest.json` match the names referenced in
`Data/MockData.swift` (`ship_*`, `port_*`, `line_*`).

## Debug launch hooks (for simulator screenshots)

Set as environment variables (or `SIMCTL_CHILD_*` for `simctl launch`):

| Variable | Effect |
|----------|--------|
| `CW_START=home` | Skip Welcome, open Home |
| `CW_OPEN_SAILING=<id>` | Deep-link into a sailing (`med-aurora`, `car-coral`, `nor-lyric`, `alk-sovereign`) |
| `CW_PUSH=ship` \| `itinerary` | Push the Ship or full Itinerary screen |
| `CW_TAB=widgets` | Open the sailing on the Widgets tab |

The sample data spans all three statuses (`med-aurora` upcoming · `car-coral` active ·
`alk-sovereign` completed) so every countdown/chart state is visible. In-app, the
Home header's slider button opens a debug sheet (return to Welcome / reset data).
# cruise-wallet-swift
