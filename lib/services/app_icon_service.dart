import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppIconService {
  static const _channel = MethodChannel('com.atanhx.markdone/app_icon');
  static const _key = 'markdone_app_icon';

  static const icons = [
    ('default', 'Deep Blue'),
    ('red', 'Chili Red'),
    ('yellow', 'Sun Yellow'),
  ];

  static Future<String> getCurrentIcon() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key) ?? 'default';
    // Migration: old "blue" key -> new "default" key
    if (saved == 'blue') return 'default';
    return saved;
  }

  static Future<void> setIcon(String iconName) async {
    if (!Platform.isAndroid) return;

    await _channel.invokeMethod('setAppIcon', {'icon': iconName});

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, iconName);
  }
}
