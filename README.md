# WhiteGram-iOS

<p align="center">
  <img src="https://raw.githubusercontent.com/TelegramMessenger/Telegram-iOS/master/submodules/Display/Source/Images.xcassets/AppIcon.appiconset/Icon-60@3x.png" width="100" height="100" alt="WhiteGram Logo" />
</p>

<p align="center">
  <b>Advanced Telegram client for iOS with Ghost Mode, Local & NFT Gifts, Upgrader Workshop, and Profile Sync.</b>
</p>

<p align="center">
  <a href="https://t.me/likecry">Developer: @likecry</a> • 
  <a href="https://t.me/xWhiteGram">Official Channel: @xWhiteGram</a> • 
  <a href="LICENSE">License: GNU GPL v2.0+</a>
</p>

---

## 📖 Overview

**WhiteGram-iOS** is an advanced fork of the official Telegram Messenger for iOS, integrating high-demand privacy and customization features proven across WhiteGram Desktop and Android editions.

### 🌟 Key Highlights
- 👻 **Ghost Mode (Режим призрака):** Granular suppression of online status (`account.updateStatus`), real-time typing indicators (`messages.setTyping`), and read receipts (`messages.readHistory`), with options for read-on-action and scheduled sending.
- 🎁 **Local & NFT Gifts:** Local gift collection shelf, transfer dialog for sending collectible gifts to any user, unpack animations, and custom chat bubbles.
- 🎰 **Upgrader & Craft Workshop:** Native UIKit radial gauge with animated winning needle, stake/target chance calculation, cubic easing spin animations, and a 4-ingredient craft workshop.
- 🔄 **Silent Profile Synchronization:** Background REST/JSON synchronization for profile badges, custom titles, verification signatures, and disk cache.
- 🎨 **Appearance & Animations:** Unified color palettes across chats, customizable animation curves (25%–300%), and TgWsProxy support.
- 📦 **Zero-Config CI/CD:** GitHub Actions pipeline producing unsigned `.ipa` packages for TrollStore, AltStore, Sideloadly, and Apple Developer accounts.

---

## 🏛 Architecture

WhiteGram-iOS is built on a clean modular architecture bridging TelegramCore and TelegramUI:

```
+---------------------------------------------------------------+
|                       WhiteGram App                           |
+---------------------------------------------------------------+
|                        WhiteGramUI                            |
|   (WhiteGramSettingsController, ThemeEngine, Views)          |
+---------------+---------------+---------------+---------------+
|   GhostMode   |     Gifts     |   Upgrader    |  ProfileSync  |
| (Interception | (NFT Models,  | (Radial Gauge,|  (REST Client,|
|   & Hooks)    | Shelf, Flow)  |  Craft Shop)  |  Cache Sync)  |
+---------------+---------------+---------------+---------------+
|                       WhiteGramCore                           |
|      (Storage, Logging, TelegramCore Bridge Layer)           |
+---------------------------------------------------------------+
|                  Telegram-iOS Submodules                      |
|       (TelegramCore, Postbox, SwiftSignalKit, Display)        |
+---------------------------------------------------------------+
```

---

## 📁 Repository Layout

```
WhiteGram-iOS/
├── .github/
│   └── workflows/
│       └── build-ipa.yml          # GitHub Actions CI for macos-14 / Xcode 15/16
├── Configurations/
│   ├── WhiteGram.xcconfig         # Build settings, signing disabled for IPA
│   ├── exportOptions.plist        # IPA export options
│   └── WhiteGram-Info.plist       # Bundle metadata and capabilities
├── Sources/
│   ├── WhiteGramCore/             # Shared logger, storage, version & bridge types
│   ├── GhostMode/                 # GhostModeManager, GhostSettings, MTProto hooks
│   ├── Gifts/                     # WhiteGramGift models, GiftStorage, Transfer dialog
│   ├── Upgrader/                  # UpgraderRadialGaugeView, Upgrader & Workshop VCs
│   ├── ProfileSync/               # ProfileSyncService REST client & signature cache
│   └── WhiteGramUI/               # Settings navigation, theme & color management
├── Tests/
│   └── WhiteGramTests/            # Unit test suite
├── build-system/
│   ├── Make/
│   │   └── Build.py               # Python build & IPA packaging tool
│   └── build_ipa.sh               # Shell pipeline script for CI & local builds
├── Package.swift                  # Swift Package Manager manifest
├── BUILD.bazel                    # Bazel build definitions
├── WORKSPACE                      # Bazel workspace configuration
├── .bazelrc                       # Bazel compilation flags
├── .bazelversion                  # Pinned Bazel version (7.x)
└── README.md                      # Documentation
```

---

## 🛠 Prerequisites & Requirements

| Component | Minimum Version | Recommended |
|---|---|---|
| **Operating System** | macOS 14.0 Sonoma | macOS 14.5+ or macOS 15 |
| **Xcode** | Xcode 15.0 | Xcode 15.4 or Xcode 16.0 |
| **Target iOS** | iOS 15.0 | iOS 16.0+ |
| **Bazel** | Bazel 7.1.0 | Bazelisk |
| **Python** | Python 3.10 | Python 3.11 |
| **Swift Tools** | Swift 5.9 | Swift 5.9 / 5.10 |

---

## 🚀 Building WhiteGram-iOS

### 1. Automated Build Pipeline (Recommended)
Run the all-in-one packaging script:
```bash
chmod +x build-system/build_ipa.sh
./build-system/build_ipa.sh --method auto --configuration release
```
The output `.ipa` and its SHA-256 hash will be generated at:
```
build/artifacts/WhiteGram-unsigned.ipa
build/artifacts/WhiteGram-unsigned.ipa.sha256
```

### 2. Building via Bazel
WhiteGram leverages Bazel matching Telegram-iOS build conventions:
```bash
# Build iOS application target
bazel build //:WhiteGram --apple_platform_type=ios --cpu=ios_arm64 --compilation_mode=opt

# Package into unsigned IPA
python3 build-system/Make/Build.py --configuration=release_arm64 --codesign=none
```

### 3. Building via Swift Package Manager
To build or test individual modules:
```bash
# Compile all modules
swift build -c release

# Run unit tests
swift test
```

---

## 📱 Sideloading & Installation

The output `WhiteGram-unsigned.ipa` is ready for all major sideloading tools:

### TrollStore (iOS 14.0 – 16.6.1 & 17.0)
1. Transfer `WhiteGram-unsigned.ipa` to your iOS device via AirDrop, iCloud, or Telegram Saved Messages.
2. Share the file to **TrollStore**.
3. TrollStore signs the binary with root entitlements. The app will never expire and notifications work seamlessly.

### AltStore / SideStore
1. Open AltStore on your device.
2. Select `My Apps` → `+` and choose `WhiteGram-unsigned.ipa`.
3. Sign in with your free or developer Apple ID.

### Sideloadly
1. Connect your iPhone/iPad via USB or Wi-Fi.
2. Drag and drop `WhiteGram-unsigned.ipa` into Sideloadly.
3. Enter your Apple ID credentials and click **Start**.

### Scarlet / Feather / Esign
1. Import `WhiteGram-unsigned.ipa` into your on-device signing tool.
2. Select your P12 certificate and mobileprovision.
3. Install the signed package.

---

## 🤖 GitHub Actions CI/CD Pipeline

The `.github/workflows/build-ipa.yml` workflow automates testing, compiling, and packaging:

### Features:
- **Environment:** Dedicated `macos-14` runner.
- **Xcode Versioning:** Switches dynamically between Xcode 15.4 and Xcode 16.0.
- **Smart Caching:** High-speed cache for Bazel repositories and SwiftPM artifacts.
- **Automatic Releases:** Pushing a version tag (e.g. `v0.5.3`) automatically builds the unsigned IPA, computes SHA-256 hashes, creates a GitHub Release, and publishes download assets.
- **Manual Trigger:** Supports `workflow_dispatch` with options for build method and Xcode version.

---

## 🔒 Security & Telegram Compliance

- **Credentials & Cryptography:** WhiteGram never intercepts or stores raw MTProto authentication keys or session credentials outside the sandboxed Telegram keychain.
- **Ghost Mode Boundaries:** Presence suppression works by dropping outgoing network signals. No server-side constraints are bypassed; Telegram server timeouts apply normally.
- **Local Decorations:** Local NFT gifts, badges, and balance simulations are strictly local or synced within the opt-in WhiteGram community network without altering official Telegram billing.

---

## 📄 License & Credits

- Based on [Telegram Messenger for iOS](https://github.com/TelegramMessenger/Telegram-iOS) licensed under **GNU GPL v2.0+**.
- Inspired by concepts from [AyuGram](https://github.com/AyuGram).
- WhiteGram core developed and maintained by [@likecry](https://t.me/likecry).
- Channel: [https://t.me/xWhiteGram](https://t.me/xWhiteGram).
