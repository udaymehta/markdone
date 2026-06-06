import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with a pre-initialized instance',
  );
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsService(prefs);
});

final storagePathProvider = NotifierProvider<StoragePathNotifier, String?>(
  StoragePathNotifier.new,
);

class StoragePathNotifier extends Notifier<String?> {
  @override
  String? build() {
    final settings = ref.read(settingsServiceProvider);
    return settings.getStoragePath();
  }

  Future<void> setPath(String path) async {
    final settings = ref.read(settingsServiceProvider);
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    settings.setStoragePath(path);
    state = path;
  }

  void clearPath() {
    final settings = ref.read(settingsServiceProvider);
    settings.clearStoragePath();
    state = null;
  }
}

final selectedCalendarIdProvider =
    NotifierProvider<SelectedCalendarNotifier, String?>(
      SelectedCalendarNotifier.new,
    );

class SelectedCalendarNotifier extends Notifier<String?> {
  @override
  String? build() {
    final settings = ref.read(settingsServiceProvider);
    return settings.getSelectedCalendarId();
  }

  void setCalendarId(String id) {
    final settings = ref.read(settingsServiceProvider);
    settings.setSelectedCalendarId(id);
    state = id;
  }
}

final selectedCalendarNameProvider =
    NotifierProvider<SelectedCalendarNameNotifier, String?>(
      SelectedCalendarNameNotifier.new,
    );

class SelectedCalendarNameNotifier extends Notifier<String?> {
  @override
  String? build() {
    final settings = ref.read(settingsServiceProvider);
    return settings.getSelectedCalendarName();
  }

  void setCalendarName(String name) {
    final settings = ref.read(settingsServiceProvider);
    settings.setSelectedCalendarName(name);
    state = name;
  }
}

final hideCompletedProvider = NotifierProvider<HideCompletedNotifier, bool>(
  HideCompletedNotifier.new,
);

class HideCompletedNotifier extends Notifier<bool> {
  @override
  bool build() {
    final settings = ref.read(settingsServiceProvider);
    return settings.getHideCompleted();
  }

  void setHideCompleted(bool value) {
    final settings = ref.read(settingsServiceProvider);
    settings.setHideCompleted(value);
    state = value;
  }
}

final calendarSyncEnabledProvider =
    NotifierProvider<CalendarSyncEnabledNotifier, bool>(
      CalendarSyncEnabledNotifier.new,
    );

class CalendarSyncEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final settings = ref.read(settingsServiceProvider);
    return settings.getCalendarSyncEnabled();
  }

  void setEnabled(bool value) {
    final settings = ref.read(settingsServiceProvider);
    settings.setCalendarSyncEnabled(value);
    state = value;
  }
}
