import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/sub_todo.dart';
import '../models/master_project.dart';

/// Manages Android system-level notifications for sub-todos and projects.
class NotificationService {
  static const String _remindersChannelId = 'markdone_reminders';
  static const String _instantChannelId = 'markdone_instant';

  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Well-known timezone aliases that the tz database doesn't include.
  /// Some devices (especially Samsung) report deprecated IANA names.
  static const _tzAliases = <String, String>{
    'Asia/Calcutta': 'Asia/Kolkata',
    'US/Eastern': 'America/New_York',
    'US/Central': 'America/Chicago',
    'US/Mountain': 'America/Denver',
    'US/Pacific': 'America/Los_Angeles',
    'US/Hawaii': 'Pacific/Honolulu',
    'US/Alaska': 'America/Anchorage',
    'US/Arizona': 'America/Phoenix',
    'Canada/Eastern': 'America/Toronto',
    'Canada/Central': 'America/Winnipeg',
    'Canada/Pacific': 'America/Vancouver',
    'Europe/Kiev': 'Europe/Kyiv',
    'Pacific/Samoa': 'Pacific/Pago_Pago',
  };

  /// Resolves a timezone identifier, falling back to known aliases.
  static tz.Location _resolveLocation(String identifier) {
    try {
      return tz.getLocation(identifier);
    } catch (_) {
      final alias = _tzAliases[identifier];
      if (alias != null) {
        return tz.getLocation(alias);
      }
      rethrow;
    }
  }

  /// Initialize the notification plugin.
  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone database and set device's local timezone
    tz_data.initializeTimeZones();
    try {
      // FlutterTimezone.getLocalTimezone() returns TimezoneInfo with .identifier
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(_resolveLocation(tzInfo.identifier));
    } catch (e) {
      // Fallback: try UTC rather than a hard-coded timezone
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {
        // Absolute last resort
      }
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // On Android, create notification channels and request permissions
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _remindersChannelId,
            'Task Reminders',
            description: 'Notifications for scheduled task reminders',
            importance: Importance.high,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _instantChannelId,
            'Instant Notifications',
            description: 'Immediate test notifications',
            importance: Importance.high,
          ),
        );

        // Request notification permission (Android 13+)
        await androidPlugin.requestNotificationsPermission();

        // Request exact alarm permission (Android 12+)
        await androidPlugin.requestExactAlarmsPermission();
      }
    }

    _initialized = true;
  }

  /// Ensures the service is initialized before any operation.
  Future<void> _ensureInitialized() async {
    if (!_initialized) await init();
  }

  /// Show a debug message as an instantaneous notification
  Future<void> showDebugNotification(String message) async {
    await _ensureInitialized();
    final debugId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _plugin.show(
      debugId,
      'Debug Log',
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _instantChannelId,
          'Instant Notifications',
          channelDescription: 'Immediate test notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    // Reserved for future deep-link handling from notifications.
  }

  /// Schedules the main notification for a sub-todo's reminder time.
  Future<void> scheduleSubTodoAlarm({
    required SubTodo todo,
    required String projectTitle,
    required String projectFilePath,
  }) async {
    await _ensureInitialized();

    if (todo.alarm == null) return;

    final scheduledDate = tz.TZDateTime.from(todo.alarm!, tz.local);
    final now = tz.TZDateTime.now(tz.local);

    if (scheduledDate.isBefore(now)) {
      return;
    }

    final id = todo.id.hashCode.abs() % 2147483647; // Keep within int32 range

    try {
      await _plugin.zonedSchedule(
        id,
        projectTitle,
        todo.title,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _remindersChannelId,
            'Task Reminders',
            channelDescription: 'Notifications for scheduled task reminders',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: projectFilePath,
      );
    } catch (e) {
      // Fallback to inexact if exact alarms are denied
      await _plugin.zonedSchedule(
        id,
        projectTitle,
        todo.title,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _remindersChannelId,
            'Task Reminders',
            channelDescription: 'Notifications for scheduled task reminders',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: projectFilePath,
      );
    }
  }

  /// Schedules a heads-up reminder notification (alarm - reminderBefore).
  Future<void> scheduleSubTodoReminder({
    required SubTodo todo,
    required String projectTitle,
    required String projectFilePath,
  }) async {
    await _ensureInitialized();

    if (todo.alarm == null || todo.reminderBefore == null) return;

    final reminderTime = todo.alarm!.subtract(todo.reminderBefore!);
    final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);
    final now = tz.TZDateTime.now(tz.local);

    if (scheduledDate.isBefore(now)) {
      return;
    }

    // Use a different ID for the reminder
    final id = (todo.id.hashCode.abs() + 1000000) % 2147483647;

    try {
      await _plugin.zonedSchedule(
        id,
        '⏰ Upcoming: $projectTitle',
        '${todo.title} (in ${todo.reminderString})',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _remindersChannelId,
            'Task Reminders',
            channelDescription: 'Notifications for scheduled task reminders',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: projectFilePath,
      );
    } catch (e) {
      // Fallback to inexact if exact alarms are denied
      await _plugin.zonedSchedule(
        id,
        '⏰ Upcoming: $projectTitle',
        '${todo.title} (in ${todo.reminderString})',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _remindersChannelId,
            'Task Reminders',
            channelDescription: 'Notifications for scheduled task reminders',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: projectFilePath,
      );
    }
  }

  /// Cancels all notifications for a sub-todo.
  Future<void> cancelSubTodoNotifications(SubTodo todo) async {
    await _ensureInitialized();

    final alarmId = todo.id.hashCode.abs() % 2147483647;
    final reminderId = (todo.id.hashCode.abs() + 1000000) % 2147483647;
    await _plugin.cancel(alarmId);
    await _plugin.cancel(reminderId);
  }

  /// Reschedules all notifications for a project.
  Future<void> rescheduleProjectNotifications(MasterProject project) async {
    await _ensureInitialized();

    for (final todo in project.todos) {
      if (!todo.isCompleted) {
        await scheduleSubTodoAlarm(
          todo: todo,
          projectTitle: project.title,
          projectFilePath: project.filePath,
        );
        await scheduleSubTodoReminder(
          todo: todo,
          projectTitle: project.title,
          projectFilePath: project.filePath,
        );
      } else {
        await cancelSubTodoNotifications(todo);
      }
    }
  }

  /// Cancels all pending notifications.
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }

  /// Show an immediate notification (for testing / debugging).
  Future<void> showInstant({
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 2147483647,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _instantChannelId,
          'Instant Notifications',
          channelDescription: 'Immediate test notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Returns all pending notification requests (for debugging).
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    await _ensureInitialized();
    return _plugin.pendingNotificationRequests();
  }
}
