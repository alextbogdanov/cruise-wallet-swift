# Cruise Wallet — Premium SwiftUI Mockup

## Context

`cruise-wallet` (`~/Desktop/CCC/cruise-wallet`) is a React Native / Expo app that tracks a
user's cruises and powers iOS home/lock-screen widgets. Its core surfaces are a teal **Welcome**
screen, a **Home** list of "boarding-pass" cruise cards, an Apple-zoom **transition** into a
**Sailing** detail screen (hero + 2×2 info grid + perforated separator + Itinerary/Widgets tabs).

The goal: rebuild those surfaces as a **brand-new, buildable, fully-mocked SwiftUI iOS app** at
`~/Desktop/CCC/cruise-wallet-swift` that is *significantly* more premium — using the same native
toolkit already proven in `cruzero-swift`: **iOS 26 Liquid Glass** (with a glass fallback),
**Metal** shaders, **SwiftUI** spring/matched-geometry animation, and **Swift Charts**. This is
**UI/UX only** — no backend, no Convex, no networking. Mock data only.

**Decisions locked with the user:**
- **Design system:** Adopt cruzero's tokens wholesale — near-white surfaces (`#F8F8F7`), dusk-indigo
  accent (`#2E6C92`), shadow ladder, spring vocabulary. The **ocean identity is carried by fal.ai
  photography** (ships, ports, destinations), not by chrome color — same philosophy as cruzero.
- **Imagery:** Reuse cruzero's **fal.ai pipeline** (user pastes `FAL_KEY`). `flux-pro/v1.1` for
  realistic ships (no branding) + ports at golden hour; `recraft-v3` for flat illustration / empty
  states. Build proceeds with labelled placeholders until the key is provided.
- **Sailing screen = Voyage + Widgets tabs.** The **Voyage** tab is charts-driven and is the entry
  point into two pushed sub-screens: a dedicated **Ship** screen and the **full Itinerary** screen.
- **Scope (six surfaces):** Welcome · Home (cards) · shared zoom transition · Sailing
  (boarding-pass) · Ship · full Itinerary.

---

## Design Foundation (ported from `cruzero-swift`)

Tooling: **XcodeGen** (`project.yml`), Xcode 26.x (native iOS 26 `.glassEffect`), target **iOS
17.0+** so the glass fallback path is exercised; opportunistic iOS 26 Liquid Glass + iOS 18 zoom
navigation transition.

**Port verbatim from `~/Desktop/CCC/cruzero-swift/Cruzero/`, then adapt:**
- `DesignSystem/Color+Hex.swift` — copy as-is.
- `DesignSystem/GlassEffectCompatibility.swift` — copy `compatibleGlass`, `compatibleGlassStatic`,
  `compatibleGlassCapsule` (the core of the premium feel: iOS 26 native + gradient/stroke/shadow
  fallback).
- `DesignSystem/ScaleButtonStyle.swift` — 0.96 spring press on every pressable.
- `DesignSystem/Theme.swift` — copy structure; keep cruzero's palette (near-white bg, dusk indigo
  `#2E6C92` / light `#5FA3C2` / deep `#245876`, coral secondary, ink `#1A1A2E`, shadow ladder,
  `Theme.Motion` springs, `Theme.Radius`). Drop the `AccentContext` two-mode plumbing — cruise
  wallet has a single mode.
- `Animation/Transitions.swift`, `Animation/TypewriterText.swift` — reuse for reveals + the Welcome
  headline.
- `Animation/Shaders/PaperWave.metal` — reuse as the **Welcome** animated ocean background (layered
  under glass). `SeamMorph.metal` — optional accent for the boarding-pass perforation/tear.
- `DesignSystem/Components/`: reuse `CountdownPill`, `GlassCard`, `PrimaryCTAButton`,
  `SecondaryButton`, `CollapsingHeader`, `SectionHeader`, `Avatar`, `PhotoTile`. (`CollapsingHeader`
  is the chrome signature — scroll-offset-driven large title that shrinks into a glass bar; offset
  read via background `GeometryReader` + `PreferenceKey`, transforms **clamped/render-only** to
  avoid NaN crashes.)
- `project.yml` — copy and rename target → `CruiseWallet`, bundle `com.cruisewallet.app`. Add
  `import Charts` usage (Swift Charts is a system framework, no SPM needed). Keep Lottie SPM.
- `tools/` (fal.ai) — copy `generate-assets.mjs`, `import-assets.mjs`, `asset-manifest.json`,
  `package.json`, `.env.example`; rewrite the manifest for cruise-wallet's asset set.

**Spring vocabulary (from `Theme.Motion`):** `snappy` (0.3/0.7) for press/selection, `gentle`
(0.5/0.8) for reveals/layout, `page` (easeInOut 0.3) for transitions. `ScaleButtonStyle` on every
pressable.

---

## Mock Data & Models (`Models/`, `Data/MockData.swift`)

Mirror the source's `UserSailing` / `SailingDay` shapes (from `cruise-wallet/src/types/sailing.d.ts`
and `convex/schema.ts`), as plain Swift structs (`Identifiable`, `Equatable`):

- **`Sailing`** — `id`, `shipName`, `cruiseLineName`, `cruiseLineLogoAsset`, `departureDate: Date`,
  `length: Int` (nights), `shipCoverImageAsset`, `cardBackgroundImageAsset?`, `embarkPort`,
  `disembarkPort`, `ship: Ship`, `days: [SailingDay]`.
- **`SailingDay`** — `dayNumber`, `date: Date?`, `portName`, `region?`, `country?`,
  `arrivalTime?`, `departureTime?`, `allDay: Bool`, `fieldNotes?`; computed `isAtSea`
  (`portName == "At Sea"`).
- **`Ship`** — `name`, `line`, `shipClass`, `yearBuilt`, `grossTonnage`, `decks`, `guestCapacity`,
  `lengthMeters`, `amenities: [Amenity]`, `photos: [String]` (asset names). (Source has no rich ship
  table; this is the premium addition that powers the new **Ship** screen.)
- **`CruiseStatus`** enum — port `cruise-status.ts` exactly:
  `before(daysUntil)` / `during(dayNumber, totalDays)` / `after(daysSince)`, plus
  `countdownText`, `statusLabel` (UPCOMING `#007AFF` / ACTIVE `#34C759` / COMPLETED `#8E8E93`),
  `progressFraction` (0…1 across the trip — drives the charts).

`MockStore` (`ObservableObject`) is the single source of truth, injected via `.environmentObject`.
Provide **3–4 sample sailings** spanning all three statuses (one `before`, one `during`, one
`after`) so every countdown/chart state is visible, each with a full `days` array (mix of port calls
+ at-sea days, arrival/departure times, field notes) and a populated `Ship`.

---

## Screen-by-Screen Blueprint

### 1. Welcome — `Features/Welcome/WelcomeView.swift`
Source: `cruise-wallet/src/app/index.tsx` (teal gradient, frosted boat circle, "Your Cruise, Your
Screen", white "Get Started").

Premium redesign:
- **`PaperWave.metal`** animated ocean wash as the background layer (slow, GPU-driven), under a
  near-white-to-translucent veil so it reads calm, not loud.
- A floating **`GlassCard`** logo lockup (boat SF Symbol in a `compatibleGlassCapsule`) with a soft
  parallax float (`Transitions.swift`).
- Headline revealed with **`TypewriterText`** + `staggeredReveal` subcopy.
- **`PrimaryCTAButton`** ("Get Started") — interactive-glass capsule with accent glow; `SecondaryButton`
  ("I already have an account") as a ghost capsule. `Get Started` → `Home`.

### 2. Home — `Features/Home/HomeView.swift` + `Features/Home/SailingCard.swift`
Source: `cruise-wallet/src/app/home.tsx`, `components/home/sailing-card-image.tsx`,
`sailing-card-info-bar.tsx`, `constants/card-transition.ts` (card = screenW−48 × 220; 150 image + 70
info bar; frosted countdown badge top-left).

Premium redesign:
- **`CollapsingHeader`** with large title "Your Sailings"; near-white `Theme.backgroundGradient`.
- **`SailingCard`** — full-bleed ship/destination photo (`Image(asset)`, downsampled), with a
  **liquid-glass info bar** floated over the bottom (`compatibleGlass`) carrying ship name, date,
  and the cruise-line logo tile — replacing the source's flat white bar. A glass **`CountdownPill`**
  top-left. Shadow ladder (`Theme.Shadow.medium`) for lift; `ScaleButtonStyle` on press.
- Optional featured **next-sailing** hero card at top with an inline mini `CountdownRing`; remaining
  cards in a `LazyVStack`. (No list/row toggle — premium single treatment. Long-press → delete
  confirmation, mirroring source.)
- Each card is the **transition source** (see §3).

### 3. Shared zoom transition (Home card → Sailing)
Source: `Link.AppleZoom` in `home.tsx` (the card image zooms into the detail hero).

Native equivalent (use `swiftui-animation` skill):
- `@Namespace var heroNS` in the navigation root.
- On `SailingCard`: `.matchedTransitionSource(id: sailing.id, in: heroNS)`.
- On the pushed `SailingView`: `.navigationTransition(.zoom(sourceID: sailing.id, in: heroNS))`
  (iOS 18+).
- **iOS 17 fallback:** `#available` guard → a `matchedGeometryEffect` hero overlay (card image +
  CountdownPill morph into the sailing hero) with `Theme.Motion.gentle`, else a cross-dissolve.
  Primary target for screenshots is iOS 26 sim, where the zoom is the headline.

### 4. Sailing (boarding-pass) — `Features/Sailing/SailingView.swift`
Source: `components/sailings/sailing-pass.tsx` (hero 220 + bottom gradient + countdown badge +
"Current Voyage" + ship name + status badge; 2×2 info grid DEPARTURE/DURATION/CRUISE LINE/SHIP;
`PerforatedSeparator`; SegmentedControl + PagerView → Details/Widgets).

Premium redesign — a true **glass boarding pass**:
- **Parallax collapsing hero** (`CollapsingHeader` pattern): large ship photo parallax-scrolls;
  overlaid "Current Voyage" eyebrow + ship name + glass status chip; on scroll collapses into a
  glass nav bar. Close (✕) + share/edit affordances as glass buttons.
- **Info grid → glass stat tiles** (`StatTile` on `GlassCard`): Departure, Duration, Cruise Line,
  Ship — each with an SF Symbol.
- **`PerforatedSeparator`** — notched ticket divider (mask + dotted rule; optional `SeamMorph.metal`
  shimmer) selling the boarding-pass metaphor.
- **Segmented control (glass) → two tabs: Voyage · Widgets** (custom matched-geometry segmented
  pill, not `Picker`; iOS 26 `GlassEffectContainer`).
  - **Voyage tab** (`Features/Sailing/VoyageTab.swift`) — the charts centerpiece (§4a).
  - **Widgets tab** (`Features/Sailing/WidgetsTab.swift`) — redesigned widget previews (§4b).

#### 4a. Voyage tab (Swift Charts — use the `swift-charts` skill)
- **`CountdownRing`** — a radial/donut `SectorMark` (or trimmed arc) showing
  `CruiseStatus.progressFraction`: pre-sailing shows "N days to go" with the ring filling toward
  departure; active shows "Day X of Y"; completed shows a full ring. Accent gradient stroke + center
  numeral.
- **`VoyageProgressChart`** — a horizontal **route timeline**: ports as `PointMark`s along a
  `LineMark` route with annotations (port names), at-sea spans rendered lighter; a `RuleMark`
  "you are here" marker for active cruises. (Days-at-sea vs in-port could alternatively be a small
  stacked `BarMark` sparkline — pick one in build.)
- **Stat tiles** row: nights, ports, sea days, embark→disembark.
- **Two entry points (per user):**
  - **"View ship" `NavigationLink`** → **Ship screen** (§5).
  - **Itinerary preview** (first 3–4 `ItineraryDayRow`s) + **"View full itinerary" link** → full
    Itinerary (§6).

#### 4b. Widgets tab
Source: `components/sailings/widgets-section.tsx`, `photo-style-selector.tsx`,
`card-background-history.tsx`.
- Glass **widget preview tiles** (small/medium iOS widget mockups: ship photo + countdown overlay).
- Horizontal **photo-style picker** (`PillChip`-style glass chips: Ocean, Sunset, Minimal, Night
  Sky, Tropical, Nautical).
- **Background-history** grid (thumbnails). Visual/mocked only — no generation.

### 5. Ship screen — `Features/Ship/ShipView.swift` (pushed from Voyage)
Premium native addition (source has no dedicated ship page). Collapsing photo header (ship hero +
photo strip), ship name + line + class, a **spec grid** (year built, gross tonnage, decks, guest
capacity, length) as glass `StatTile`s, and an **amenities** list (SF Symbol rows on `GlassCard`).
Optional small Swift Charts stat (e.g. capacity/size relative bar). Back via standard
`NavigationStack`.

### 6. Full Itinerary — `Features/Itinerary/FullItineraryView.swift` (pushed from Voyage)
Source: `components/sailings/sailing-itinerary.tsx` (vertical rail + dots + connector; Day N; port +
region; date; arrival/departure; all-day; field notes; at-sea = hollow dot, port = solid).

Premium redesign: full-height scroll of **`ItineraryDayRow`** on glass day cards — continuous
accent timeline rail, solid accent dot for port calls / hollow dot for at-sea, port name + region,
formatted date, arrival/departure time pair, "All Day", field notes. Section header "Itinerary" +
sailing name (`CollapsingHeader`). `ItineraryDayRow` is shared with the Voyage-tab preview.

---

## Shared Components (`DesignSystem/Components/` — new, cruise-wallet specific)
- `SailingCard` (home) · `BoardingPassHeader` (parallax hero) · `PerforatedSeparator` ·
  `StatTile` · `GlassSegmentedControl` · `CountdownRing` (Charts) · `VoyageProgressChart` (Charts) ·
  `ItineraryDayRow` · `WidgetPreviewTile` · `PhotoStylePicker`.
Reused from cruzero: `CountdownPill`, `GlassCard`, `PrimaryCTAButton`, `SecondaryButton`,
`CollapsingHeader`, `SectionHeader`, `Avatar`, `PhotoTile`, `ScaleButtonStyle`.

## App Shell & Navigation
- `CruiseWalletApp.swift`, `RootView.swift` — a `NavigationStack` rooted at Welcome.
  Welcome → Home (replace root) → push `SailingView` (zoom). Inside Voyage tab → push `ShipView` /
  `FullItineraryView`.
- `MockStore` injected via `.environmentObject`. A small **Debug** affordance (sheet) to jump
  Welcome↔Home and to cycle the focused sailing's status (before/during/after) so all
  countdown/chart states are demoable — mirrors cruzero's `DebugMenuView` pattern.

## fal.ai Asset Pipeline (`tools/`)
Rewrite `asset-manifest.json` for: 1 welcome ocean hero (or rely on `PaperWave`), ~6–8 **ship**
photos (`flux-pro/v1.1`, no branding/name, dusk/golden light), ~8 **port/destination** backgrounds
(`flux-pro/v1.1`, golden hour), ~6 cruise-line **logo** placeholders + ~4 empty-state/illustration
glyphs (`recraft-v3`). `generate-assets.mjs` downloads to `Resources/Generated/`; `import-assets.mjs`
builds `Assets.xcassets` imagesets. **Generation blocked until `FAL_KEY` pasted**; until then every
image references a labelled placeholder so the app keeps building.

## Performance
`LazyVStack`/`List` with stable ids; `Equatable` rows; cheap `body`; precomputed formatted strings;
downsampled bundled images; avoid stacked blur/`.glassEffect` inside scrolling cells (use
`compatibleGlassStatic` there); animations scoped with explicit `value:`; honor reduced-motion.

## File / Project Layout
```
cruise-wallet-swift/
  project.yml                 # XcodeGen (iOS 17+, Lottie SPM)
  MOCKUP.md                   # this document
  tools/                      # fal.ai: generate/import scripts, manifest, .env
  CruiseWallet/
    CruiseWalletApp.swift, RootView.swift
    DesignSystem/ Theme.swift, Color+Hex.swift, GlassEffectCompatibility.swift,
                  ScaleButtonStyle.swift, Components/, Backgrounds/
    Animation/    Transitions.swift, TypewriterText.swift, Shaders/PaperWave.metal, SeamMorph.metal
    Features/     Welcome/ Home/ Sailing/ (VoyageTab, WidgetsTab) Ship/ Itinerary/ Debug/
    Models/       Data/MockData.swift, MockStore.swift
    Resources/    Generated/ , Assets.xcassets
```

---

## Build Sequence
1. Save `MOCKUP.md` to `cruise-wallet-swift/` (this document).
2. Scaffold `project.yml`; `xcodegen generate`; confirm empty app builds
   (`xcodebuild -project CruiseWallet.xcodeproj -scheme CruiseWallet build`).
3. **Port design foundation**: Color/Glass/ScaleButtonStyle/Theme + Animation + reused Components +
   the two Metal shaders. A tiny styleguide screen to eyeball glass/shadow/springs.
4. **Models + MockStore + MockData** (3–4 sailings across all statuses, full days + ships).
5. **Asset pipeline**: rewrite manifest + scripts. Once `FAL_KEY` pasted → generate + import;
   until then placeholders.
6. **Welcome** (PaperWave bg + glass logo + TypewriterText + CTAs).
7. **Home** (`CollapsingHeader` + `SailingCard` glass cards + `CountdownPill`) and wire
   `.matchedTransitionSource`.
8. **Sailing** boarding-pass shell (parallax hero + StatTiles + `PerforatedSeparator` +
   `GlassSegmentedControl`) and the **zoom transition** (`.navigationTransition(.zoom)` + iOS 17
   matchedGeometry fallback).
9. **Voyage tab** — `CountdownRing` + `VoyageProgressChart` (Swift Charts) + stat tiles + itinerary
   preview + the two nav entry points.
10. **Ship screen** + **Full Itinerary screen**.
11. **Widgets tab** (preview tiles + photo-style picker + history grid).
12. Debug menu; polish pass (springs, shadows, haptics, reduced-motion).

## Verification
- `xcodebuild -project CruiseWallet.xcodeproj -scheme CruiseWallet -destination 'generic/platform=iOS Simulator' build`
  succeeds at each phase.
- Boot in iOS Simulator (Xcode 26): Welcome → Home → tap a card → **zoom transition** into Sailing →
  Voyage tab → **View ship** and **View full itinerary** both push → Widgets tab renders.
- Flip the debug status cycle: confirm `CountdownRing`/`VoyageProgressChart`/status chip update for
  before/during/after.
- Confirm the floating glass reads as liquid glass (sliding matched-geometry segmented pill, accent
  glow); `CollapsingHeader`s shrink/fade **smoothly, no NaN/crash**; every generated asset appears
  on a screen (no orphans).
- Visually compare glass/shadow/animation parity against `cruzero-swift`.
