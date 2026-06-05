import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'providers/settings_providers.dart';
import 'services/notification_service.dart';

Future<void> requestStartupPermissions() async {
  if (!Platform.isAndroid) return;

  // Request notification permission (needed for task alarms)
  await Permission.notification.request();

  // Request exact alarm permission (needed for scheduled notifications)
  await Permission.scheduleExactAlarm.request();

  // Request calendar access (needed for calendar sync feature)
  await Permission.calendarFullAccess.request();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-initialize SharedPreferences once – makes all settings reads instant.
  final prefs = await SharedPreferences.getInstance();

  final notifService = NotificationService();
  await notifService.init();

  // Request necessary permissions on startup
  await requestStartupPermissions();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MarkDoneApp(),
    ),
  );
}
