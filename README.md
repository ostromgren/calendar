# Calendar App (Flutter)

A cross-platform Calendar application built with Flutter and Dart.

---

## 📱 Platform Targets

| Platform | Latest 2 Versions Supported | Targeted Version | Configuration File |
| :--- | :--- | :--- | :--- |
| **Android** | **Android 15** (API 35) & **Android 16** (API 36) | **Android 16** (API 36) | `android/app/build.gradle.kts` |
| **iOS** | **iOS 26** & **iOS 27** (2026 versioning) | **iOS 27** (Deployment target 26.0+) | `ios/Runner.xcodeproj` / `ios/Podfile` |
| **macOS** | Flutter desktop | Current macOS | `macos/Runner` |
| **Windows** | Flutter desktop | Windows 10+ | `windows/runner` |

---

## 🧱 Key Concepts

### State Management
The app uses Flutter's built-in [`ChangeNotifier`](lib/ui/features/calendar/view_models/calendar_view_model.dart) pattern:
- **ViewModel** holds and mutates state, calling `notifyListeners()` after each change.
- **View** wraps its build in `ListenableBuilder(listenable: viewModel, ...)` and rebuilds automatically.

### Layered Architecture
| Layer | Responsibility |
| :--- | :--- |
| `domain/models/` | Immutable data classes with no framework dependencies |
| `data/repositories/` | Single source of truth for reading and writing events |
| `ui/features/*/view_models/` | UI state, user intent handlers, delegates to repository |
| `ui/features/*/views/` | Stateless widgets that render ViewModel state |
| `ui/core/` | Shared theme, colours, and typography |

### Native Platform Configuration
| Concern | Android | iOS |
| :--- | :--- | :--- |
| Build config | `android/app/build.gradle.kts` | `ios/Runner.xcodeproj` / `ios/Podfile` |
| App metadata & permissions | `android/app/src/main/AndroidManifest.xml` | `ios/Runner/Info.plist` |
| Native entry point | `android/.../MainActivity.kt` | `ios/Runner/AppDelegate.swift` |
| App bundle identifier | `applicationId` in `build.gradle.kts` | `PRODUCT_BUNDLE_IDENTIFIER` in Xcode |
| Icons & splash assets | `android/app/src/main/res/mipmap-*/` | `ios/Runner/Assets.xcassets` |

### Opening calendar events from other apps

Android advertises support for the standard calendar event insertion intent and
for opening `.ics` files. iOS and macOS register `.ics` as an alternate file
type, so the OS can offer Calendar when opening an invite. Incoming invites
open prefilled in the event form for review before saving.

Windows builds receive `.ics` file paths when launched by the OS. To add the
app to the Windows **Open with** list, run the bundled
`register_calendar_association.ps1` from PowerShell after installing the app.
The script registers the current user's file association without changing the
default `.ics` application.

---

## 🏗️ Architecture

The codebase adheres to the recommended layered approach:

```text
lib/
├── data/
│   └── repositories/
│       └── calendar_repository.dart    # Event persistence & CRUD (single source of truth)
├── domain/
│   └── models/
│       └── calendar_event.dart         # Immutable event model
├── ui/
│   ├── core/
│   │   └── theme.dart                  # Material 3 light/dark theme definitions
│   └── features/
│       └── calendar/
│           ├── view_models/
│           │   └── calendar_view_model.dart # State management (ChangeNotifier)
│           └── views/
│               ├── calendar_view.dart       # Main calendar screen (Slivers)
│               └── widgets/
│                   ├── day_cell.dart        # Day cell in monthly grid
│                   ├── event_tile.dart      # Daily event list item
│                   └── month_header.dart    # Month navigation controls
└── main.dart                                # Dependency wiring & runApp()
```

---

## 🚀 Running the Project

### 1. Run Unit & Widget Tests
```bash
flutter test
```

### 2. Run Static Analyzer
```bash
flutter analyze
```

### 3. Run on Chrome (Instant testing without mobile simulators)
```bash
flutter run -d chrome
```

### 4. Run on Android
```bash
flutter run -d android
```

### 5. Install a release-mode build on Android
Connect your Samsung with USB debugging enabled, then find its Flutter device ID:
```bash
flutter devices
flutter run --release -d <device-id>
```

This builds and installs the optimized release-mode app directly on the phone.
The current Android release build uses the local debug signing key for personal
testing; configure a private release keystore before distributing the APK.

### 6. Run on iOS Simulator
```bash
open -a Simulator
flutter run -d iPhone
```

---

## ⚡ Tooling & Environment Next Steps

1. **Flutter CLI**: Added to `~/.zshrc` (`export PATH="$HOME/flutter/bin:$PATH"`).
2. **JDK & Android SDK (CLI-only)**: Install **JDK 21 (LTS)** and **Android Command-Line Tools** via Homebrew (`brew install openjdk@21 && brew install --cask android-commandlinetools`). Use the modern `android sdk` CLI (`android sdk install "platforms;android-36" ...`) to manage packages.
3. **iOS Toolchain**: Install Xcode from the Mac App Store, then run:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```
