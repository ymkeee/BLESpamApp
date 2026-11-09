# BLESpam — TrollStore iOS App

A SwiftUI app that broadcasts custom BLE advertisement packets (Apple, Samsung, Microsoft) — similar to Flipper Zero BLE Spam, but running natively on iPhone via TrollStore.

## Screenshots (UI description)

- Dark glassmorphism interface with animated gradient orbs
- Grid of payload cards with per-vendor color coding
- Animated pulsing start/stop button with spinning gradient ring
- Live stats bar: packets sent, interval, last payload name
- Category filter chips: Apple / Samsung / Microsoft / All

## How it works

iOS's public `CoreBluetooth` API restricts `CBPeripheralManager` to only advertise data that includes registered GATT service UUIDs. To bypass this and send **raw manufacturer data** (which is what triggers nearby-device popups), the app calls the private Objective-C selector:

```
-[CBPeripheralManager _startAdvertisingWithAdvertisementData:andMask:andFlags:andCompletionHandler:]
```

The call is made via `NSInvocation` (in `PrivateAdvertiser.m`) to correctly pass the `uint8_t` scalar arguments. Swift cannot call mixed C-typed Obj-C selectors directly, so the ObjC file acts as a trampoline.

## Payloads included

| Category | Payloads |
|---|---|
| 🍎 Apple | AirPods Pro 2, AirPods 3, AirPods Max, Beats Studio 3, Beats Flex, Apple TV, Apple Watch, iPhone Transfer, NameDrop, AirTag |
| 🟣 Samsung/Google | Galaxy Buds Pro, Galaxy Buds 2, Galaxy Buds Live, Pixel Buds A |
| 🪟 Microsoft | Swift Pair Mouse, Keyboard, Headset |

## Requirements

- iOS 15.0 – 16.x
- [TrollStore 2.x](https://github.com/opa334/TrollStore) installed
- Bluetooth enabled

## Build manually (macOS)

```bash
# Install ldid if you haven't already
brew install ldid

xcodebuild \
  -project BLESpamApp.xcodeproj \
  -scheme BLESpamApp \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  ARCHS="arm64 arm64e" \
  BUILD_DIR="$(pwd)/build" \
  clean build

# Sign with entitlements
ldid -SBLESpamApp/Resources/entitlements.plist \
     build/Release-iphoneos/BLESpamApp.app/BLESpamApp

# Package
mkdir -p Payload
cp -r build/Release-iphoneos/BLESpamApp.app Payload/
zip -r BLESpam.ipa Payload/
```

Then install `BLESpam.ipa` via **TrollStore → Install IPA**.

## Build via GitHub Actions (automatic)

Push to `main` → Actions → `Build BLESpam IPA (TrollStore)` → download artifact `BLESpam-TrollStore`.

## Project structure

```
BLESpamApp/
├── .github/workflows/build.yml     ← CI pipeline
├── BLESpamApp.xcodeproj/
│   └── project.pbxproj
└── BLESpamApp/
    ├── Sources/
    │   ├── BLESpamApp.swift         ← @main entry point
    │   ├── ContentView.swift        ← Main UI
    │   ├── BLEManager.swift         ← BLE engine (uses private API)
    │   ├── Payloads.swift           ← All payload byte arrays
    │   ├── Extensions.swift         ← Color, glass card, animations
    │   ├── PayloadCard.swift        ← Grid card component
    │   ├── StartStopButton.swift    ← Animated button
    │   └── StatsBar.swift           ← Live stats row
    ├── Bridge/
    │   ├── BLESpamApp-Bridging-Header.h
    │   ├── PrivateBLE.h             ← Private API declarations
    │   ├── PrivateAdvertiser.h      ← ObjC trampoline header
    │   └── PrivateAdvertiser.m      ← NSInvocation call to private sel
    └── Resources/
        ├── Info.plist
        └── entitlements.plist       ← TrollStore entitlements
```

## Disclaimer

For educational and security research purposes only. Broadcasting fake BLE packets in public places may violate local laws. Use responsibly and only with permission.
