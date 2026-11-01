import 'package:material_ui/material_ui.dart';

/// Language preference for the app's interface.
enum AppLanguage {
  system,
  english,
  swedish;

  Locale? get locale => switch (this) {
    AppLanguage.system => null,
    AppLanguage.english => const Locale('en'),
    AppLanguage.swedish => const Locale('sv'),
  };
}
