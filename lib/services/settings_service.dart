import 'package:shared_preferences/shared_preferences.dart';

/// Persists user settings using SharedPreferences.
///
/// Accepts a pre-initialized [SharedPreferences] instance so all reads
/// are synchronous – no more cascading async waits at startup.
class SettingsService {
  static const String _keyStoragePath = 'markdone_storage_path';
  static const String _keySelectedCalendarId = 'markdone_calendar_id';
  static const String _keySelectedCalendarName = 'markdone_calendar_name';
  static const String _keyThemeMode = 'markdone_theme_mode';
  static const String _keyAccentColor = 'markdone_accent_color';
  static const String _keyHideCompleted = 'markdone_hide_completed';
  static const String _keyCalendarSyncEnabled = 'markdone_calendar_sync';
  static const String _keyFontScale = 'markdone_font_scale';
  static const String _keyAmoledDark = 'markdone_amoled_dark';
  static const String _keyDateFormat = 'markdone_date_format';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  // --- Storage Path ---

  String? getStoragePath() => _prefs.getString(_keyStoragePath);

  void setStoragePath(String path) => _prefs.setString(_keyStoragePath, path);

  void clearStoragePath() => _prefs.remove(_keyStoragePath);

  // --- Calendar ID ---

  String? getSelectedCalendarId() => _prefs.getString(_keySelectedCalendarId);

  void setSelectedCalendarId(String id) =>
      _prefs.setString(_keySelectedCalendarId, id);

  String? getSelectedCalendarName() =>
      _prefs.getString(_keySelectedCalendarName);

  void setSelectedCalendarName(String name) =>
      _prefs.setString(_keySelectedCalendarName, name);

  // --- Theme Mode ---

  String? getThemeMode() => _prefs.getString(_keyThemeMode);

  void setThemeMode(String mode) => _prefs.setString(_keyThemeMode, mode);

  // --- Accent Color ---

  int? getAccentColorValue() => _prefs.getInt(_keyAccentColor);

  void setAccentColorValue(int colorValue) =>
      _prefs.setInt(_keyAccentColor, colorValue);

  // --- Hide Completed Tasks ---

  bool getHideCompleted() => _prefs.getBool(_keyHideCompleted) ?? false;

  void setHideCompleted(bool value) => _prefs.setBool(_keyHideCompleted, value);

  // --- Calendar Sync Enabled ---

  bool getCalendarSyncEnabled() =>
      _prefs.getBool(_keyCalendarSyncEnabled) ?? false;

  void setCalendarSyncEnabled(bool value) =>
      _prefs.setBool(_keyCalendarSyncEnabled, value);

  // --- Font Scale ---

  double getFontScale() => _prefs.getDouble(_keyFontScale) ?? 1.0;

  void setFontScale(double value) => _prefs.setDouble(_keyFontScale, value);

  // --- AMOLED Dark Mode ---

  bool getAmoledDark() => _prefs.getBool(_keyAmoledDark) ?? false;

  void setAmoledDark(bool value) => _prefs.setBool(_keyAmoledDark, value);

  // --- Date Format ---

  String? getDateFormat() => _prefs.getString(_keyDateFormat);

  void setDateFormat(String value) => _prefs.setString(_keyDateFormat, value);
}
