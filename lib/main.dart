import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'app.dart';
import 'providers/settings_providers.dart';
import 'services/notification_service.dart';
import 'services/ota_background_service.dart';


Future<void> requestStartupPermissions() async {
  if (!Platform.isAndroid) return;

  // Request notification permission (needed for task alarms)
  await Permission.notification.request();

  // Request exact alarm permission (needed for scheduled notifications)
  await Permission.scheduleExactAlarm.request();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-initialize SharedPreferences once – makes all settings reads instant.
  final prefs = await SharedPreferences.getInstance();

  // Track app version to reset stale prefs (e.g. from Android Auto Backup)
  const currentVersion = '1.4.0';
  final lastVersion = prefs.getString('markdone_version');
  if (lastVersion != currentVersion) {
    await prefs.setString('markdone_version', currentVersion);
    // Reset calendar sync on version change so it always starts OFF
    await prefs.setBool('markdone_calendar_sync', false);
  }

  final notifService = NotificationService();
  await notifService.init();

  // Cancel ALL stale notifications from previous sessions.
  // Providers will reschedule valid ones during their build() call.
  await notifService.cancelAll();

  await requestStartupPermissions();

  await Workmanager().initialize(otaBackgroundCallback);
  await Workmanager().registerPeriodicTask(
    'ota_update_check',
    'otaCheck',
    frequency: const Duration(hours: 12),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MarkDoneApp(),
    ),
  );
}
