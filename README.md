# Calendar App (Flutter)

A cross-platform Calendar application for Android and iOS built with Flutter and Dart.

---

## 📱 Platform Targets

| Platform | Latest 2 Versions Supported | Targeted Version | Configuration File |
| :--- | :--- | :--- | :--- |
| **Android** | **Android 15** (API 35) & **Android 16** (API 36) | **Android 16** (API 36) | `android/app/build.gradle.kts` |
| **iOS** | **iOS 26** & **iOS 27** (2026 versioning) | **iOS 27** (Deployment target 26.0+) | `ios/Runner.xcodeproj` / `ios/Podfile` |

---

## 🧠 Android Developer's Bridge to Flutter & iOS

Coming from 3 years of Android development (targeting Android 14), here is how your existing knowledge maps to Flutter and iOS:

### 1. Architectural Concepts

| Android (Kotlin / Jetpack) | Flutter Equivalent | iOS Native Equivalent |
| :--- | :--- | :--- |
| `Activity` / `Fragment` | `Widget` (e.g. `Scaffold`, `CalendarView`) | `UIViewController` |
| `@Composable` function | `StatelessWidget` / `StatefulWidget` | SwiftUI `@View` |
| `ViewModel` + `StateFlow` | `ChangeNotifier` + `ListenableBuilder` | `ObservableObject` / `@Observable` |
| `MutableStateFlow.value = ...` | `notifyListeners()` | `@Published` / `@Observable` |
| `data class Event(...)` | `class CalendarEvent` with `const` constructor & `final` fields | Swift `struct Event` |
| `Modifier.fillMaxSize().padding()` | `Container`, `Padding`, `Expanded`, `SizedBox` | Swift modifiers |
| `RecyclerView` / `LazyColumn` | `ListView.builder` / `SliverList` | `List` / `UICollectionView` |
| `CoordinatorLayout` / NestedScroll | `CustomScrollView` + Slivers | `UIScrollView` |

### 2. Project File Structure Mapping

| Android | iOS | Purpose |
| :--- | :--- | :--- |
| `android/app/build.gradle.kts` | `ios/Podfile` & `Runner.xcodeproj` | Build config, min/target SDK, plugins |
| `android/app/src/main/AndroidManifest.xml` | `ios/Runner/Info.plist` | App name, permissions, orientation, metadata |
| `MainActivity.kt` | `AppDelegate.swift` & `SceneDelegate.swift` | Native app entry point and platform channels |
| `applicationId = "com.example.calendar"` | `PRODUCT_BUNDLE_IDENTIFIER` | Unique app identifier |
| `res/values/strings.xml`, `themes.xml` | `lib/ui/core/theme.dart` | Material 3 themes & styling (shared across both!) |
| `res/drawable`, `res/mipmap` | `ios/Runner/Assets.xcassets` | App icons and native splash assets |

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

### 5. Run on iOS Simulator
```bash
open -a Simulator
flutter run -d iPhone
```

---

## ⚡ Tooling & Environment Next Steps

1. **Flutter CLI**: Added to `~/.zshrc` (`export PATH="$HOME/flutter/bin:$PATH"`).
2. **Android SDK**: Install Android Studio to get the Android SDK, command-line tools, and create an Android Virtual Device (AVD).
3. **iOS Toolchain**: Install Xcode from the Mac App Store, then run:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```
