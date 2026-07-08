# DealBoard

A personal, **offline-first** iOS app for tracking the daily food & drink deals
run by places near you. Browse by weekday, add deals from a photo (with on-device
OCR) or by hand, and manage your establishments. No accounts, no cloud, no ads,
no analytics — and completely free.

> Personal use only. Not intended for the App Store.

## Offline-first

Everything core works with **no internet**: saving deals, establishments and
photos, and browsing which places have deals on a given day. All data lives in a
local SwiftData store; photos are saved to the app's Documents directory.

The **only** networked feature is optional establishment enrichment in the
add-deal flow (MapKit food/drink POI lookup at a photo's GPS coordinate). It's
non-blocking and degrades gracefully — offline it silently falls back to nearby
saved places and manual entry, and nothing else breaks.

## Features

- **Weekday browser** — pick a day (defaults to today), see every recurring deal
  that runs then, filter by Food / Drink / Both.
- **Add from photo** — pick from the library or shoot live; on-device Vision OCR
  extracts the text and suggests an editable title + key points.
- **Establishment matching** — reads the photo's EXIF GPS (falling back to the
  PHAsset location), then ranks nearby saved places (offline) and, if online,
  merges in MapKit food/drink businesses. Always offers "None" and "Add new".
- **Manual entry** — every automated step has a by-hand fallback.
- **Manage** — edit/delete deals, full establishments manager with optional saved
  coordinates (capture current location or leave blank).
- Warm, appetising palette; full Dark Mode, Dynamic Type, and VoiceOver labels.

## Build & run (Simulator)

Requires Xcode 16+ (built with Xcode 26.5).

```
open DealBoard.xcodeproj
```

Pick an iPhone simulator and press ⌘R.

## Run on your own iPhone

1. Plug in your iPhone and select it as the run destination in Xcode.
2. Select the **DealBoard** target → **Signing & Capabilities** → set **Team** to
   your personal Apple ID (add it under Xcode ▸ Settings ▸ Accounts if needed).
   Change the **Bundle Identifier** if `com.hughwilliams.DealBoard` is taken.
3. Press ⌘R. The first run fails to launch until you trust the certificate:
   on the phone go to **Settings ▸ General ▸ VPN & Device Management**, tap your
   developer profile, and **Trust** it. Run again.

## Project structure

```
DealBoard/
  DealBoardApp.swift        App entry + TabView root (Deals / Places)
  Models/                   SwiftData models + enums + preview data
    Deal.swift, Establishment.swift, DealType.swift, Weekday.swift, PreviewData.swift
  Services/                 All the non-UI logic
    OCRService.swift         Vision on-device text recognition
    DealHeuristics.swift     Title / key-point / type suggestions from OCR
    PhotoMetadata.swift      EXIF GPS parsing (+ PHAsset fallback)
    EstablishmentMatcher.swift  Offline proximity + online MapKit ranking
    ImageStore.swift         Photo files in Documents
    LocationService.swift    One-shot current location (for saving a place)
  Views/                    SwiftUI screens + components
  Theme/Theme.swift         Warm semantic colours (light + dark variants)
  Resources/Assets.xcassets App icon slot
```

## Dependencies

None. Apple frameworks only — SwiftUI, SwiftData, Vision, PhotosUI, ImageIO,
CoreLocation, MapKit, UIKit.
