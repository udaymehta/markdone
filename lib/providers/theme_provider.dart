import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import 'settings_providers.dart';

// --- Theme Mode Provider ---

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final settings = ref.read(settingsServiceProvider);
    switch (settings.getThemeMode()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  void toggle() {
    setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  void setMode(ThemeMode mode) {
    final settings = ref.read(settingsServiceProvider);
    settings.setThemeMode(mode.name);
    state = mode;
  }
}

final accentColorProvider = NotifierProvider<AccentColorNotifier, Color>(
  AccentColorNotifier.new,
);

class AccentColorNotifier extends Notifier<Color> {
  @override
  Color build() {
    final settings = ref.read(settingsServiceProvider);
    final storedColor = settings.getAccentColorValue();
    if (storedColor == null) return AppColors.accent;
    return Color(storedColor);
  }

  void setColor(Color color) {
    final settings = ref.read(settingsServiceProvider);
    settings.setAccentColorValue(color.toARGB32());
    state = color;
  }

  void reset() => setColor(AppColors.accent);
}
