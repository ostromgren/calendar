# Calendar

A cross-platform calendar application built with Flutter. View and manage events in a monthly calendar or agenda, organize local calendars, and connect events from calendars on your device.

## Features

- Monthly calendar and agenda views
- Create and manage events, including long descriptions that can be expanded when needed
- Multiple local calendars with custom names and user-defined, color-coded categories
- Read and write supported device calendars
- Light, dark, system, curated, and custom app-wide color themes
- Android and iOS widgets for upcoming events
- Open `.ics` invitations in the app for review before saving
- English and Swedish interface languages

Platform capabilities depend on the operating system and its calendar permissions.

## Supported platforms

The repository includes application targets for Android, iOS, macOS, and Windows. Each platform requires its corresponding Flutter-supported development toolchain. Some platform integrations, such as device calendars and widgets, are available only on supported platforms.

## Getting started

### Requirements

- Flutter SDK compatible with the constraints in `pubspec.yaml`
- Platform-specific build tools for the target platform (for example, Xcode for iOS and macOS)

### Set up and run

```sh
flutter pub get
flutter run
```

To select a specific simulator, emulator, or desktop target:

```sh
flutter devices
flutter run -d <device-id>
```

## Development

Run the test suite and static analysis with:

```sh
flutter test
flutter analyze
```

Generate localization code after editing the files in `lib/l10n/`:

```sh
flutter gen-l10n
```

## Project structure

```text
lib/
├── data/       Data access, repositories, and platform integrations
├── domain/     Calendar, event, and settings models
├── l10n/       English and Swedish localization resources
└── ui/
    ├── core/   Shared theme and presentation utilities
    └── features/
        ├── calendar/
        └── settings/
```

The application separates data access, domain models, and feature-specific UI. View models hold presentation state and coordinate updates with repositories.

## Contributing

Contributions are welcome. Please include or update tests for behavior changes and run `flutter test` and `flutter analyze` before submitting a pull request.
