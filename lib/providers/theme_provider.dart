import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/date_formatters.dart';
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

// --- Font Scale Provider ---

final fontScaleProvider = NotifierProvider<FontScaleNotifier, double>(
  FontScaleNotifier.new,
);

class FontScaleNotifier extends Notifier<double> {
  @override
  double build() {
    final settings = ref.read(settingsServiceProvider);
    return settings.getFontScale();
  }

  void setScale(double scale) {
    final settings = ref.read(settingsServiceProvider);
    settings.setFontScale(scale);
    state = scale;
  }

  void reset() => setScale(1.0);
}

// --- AMOLED Dark Mode Provider ---

final amoledDarkProvider = NotifierProvider<AmoledDarkNotifier, bool>(
  AmoledDarkNotifier.new,
);

class AmoledDarkNotifier extends Notifier<bool> {
  @override
  bool build() {
    final settings = ref.read(settingsServiceProvider);
    return settings.getAmoledDark();
  }

  void setEnabled(bool value) {
    final settings = ref.read(settingsServiceProvider);
    settings.setAmoledDark(value);
    state = value;
  }

  void toggle() => setEnabled(!state);
}

// --- Date Format Style Provider ---

final dateFormatStyleProvider =
    NotifierProvider<DateFormatStyleNotifier, DateFormatStyle>(
      DateFormatStyleNotifier.new,
    );

class DateFormatStyleNotifier extends Notifier<DateFormatStyle> {
  @override
  DateFormatStyle build() {
    final settings = ref.read(settingsServiceProvider);
    final stored = settings.getDateFormat();
    return DateFormatStyle.values.asNameMap()[stored] ??
        DateFormatStyle.mmddyyyy;
  }

  void setStyle(DateFormatStyle value) {
    final settings = ref.read(settingsServiceProvider);
    settings.setDateFormat(value.name);
    state = value;
  }
}
