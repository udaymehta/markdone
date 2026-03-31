import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../core/timezone_utils.dart';
import '../models/sub_todo.dart';
import '../models/master_project.dart';
import 'recurrence_service.dart';

/// Background notification action handler — must be a top-level function so
/// it can run in a separate isolate when the app is not in the foreground.
///
/// When the user taps "Done!" while the app is backgrounded/killed, this writes
/// a pending-completion entry to a queue file.  The next time the app opens,
/// [ProjectsNotifier] reads that queue and applies the toggles.
@pragma('vm:entry-point')
Future<void> handleBackgroundNotificationResponse(
  NotificationResponse response,
) async {
  if (response.actionId != NotificationService.doneActionId) return;
  final payload = response.payload;
  if (payload == null) return;

  final sep = payload.indexOf('|||');
  if (sep < 0) return;

  final filePath = payload.substring(0, sep);
  final todoId = payload.substring(sep + 3);

  // Write the pending completion to a queue file that sits alongside
  // the project .md files.  The app processes this on its next start.
  try {
    final queueFile = File('${File(filePath).parent.path}/.markdone_queue');
    await queueFile.writeAsString(
      '$filePath|||$todoId\n',
      mode: FileMode.append,
    );
  } catch (_) {
    // Silently ignore I/O errors — the queue is best-effort.
  }
}

/// Manages Android system-level notifications for sub-todos and projects.
class NotificationService {
  static const String _remindersChannelId = 'markdone_reminders';
  static const String _instantChannelId = 'markdone_instant';

  /// Action ID sent with every notification's "Done!" button.
  static const String doneActionId = 'done';

  /// How many future occurrences to pre-schedule for recurring tasks so that
  /// notifications keep firing even when the app is not opened.
  static const int _maxRecurringPreSchedule = 10;

  /// Set this from [ProjectsNotifier] so that a foreground "Done!" tap is
  /// handled immediately without going through the queue file.
  static Future<void> Function(String filePath, String todoId)? onDoneAction;

  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize the notification plugin.
  Future<void> init() async {
    if (_initialized) return;

    await initializeTimezone();

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
      // Background isolate handler for action button taps when app is not
      // in the foreground.
      onDidReceiveBackgroundNotificationResponse:
          handleBackgroundNotificationResponse,
    );

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

        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
      }
    }

    _initialized = true;
  }

  /// Ensures the service is initialized before any operation.
  Future<void> _ensureInitialized() async {
    if (!_initialized) await init();
  }

  /// Called when the user taps a notification or one of its action buttons
  /// while the app is in the foreground (or is brought to the foreground).
  void _onNotificationTap(NotificationResponse response) {
    if (response.actionId == doneActionId) {
      final payload = response.payload;
      if (payload == null) return;
      final sep = payload.indexOf('|||');
      if (sep < 0) return;
      final filePath = payload.substring(0, sep);
      final todoId = payload.substring(sep + 3);
      // Delegate to whatever ProjectsNotifier has wired up.
      onDoneAction?.call(filePath, todoId);
    }
    // Other taps (notification body): no-op for now — reserved for deep-link.
  }

  /// Schedules a notification with exact alarms, falling back to inexact if the
  /// permission is denied.
  Future<void> _scheduleZonedWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String payload,
    List<AndroidNotificationAction> actions = const [],
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _remindersChannelId,
        'Task Reminders',
        channelDescription: 'Notifications for scheduled task reminders',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        actions: actions,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (_) {
      // Fallback to inexact if exact alarms are denied.
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  /// Show a debug message as an instantaneous notification.
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

  /// Schedules the main alarm notification(s) for a sub-todo.
  ///
  /// For recurring tasks, up to [_maxRecurringPreSchedule] future occurrences
  /// are pre-scheduled so that notifications keep firing even when the app is
  /// not opened between occurrences.
  Future<void> scheduleSubTodoAlarm({
    required SubTodo todo,
    required String projectTitle,
    required String projectFilePath,
  }) async {
    await _ensureInitialized();

    if (todo.alarm == null) return;

    final now = tz.TZDateTime.now(tz.local);
    final baseId = todo.id.hashCode.abs() % 2147483647;
    // Payload encodes both the file path and the todo ID so the "Done!" handler
    // knows exactly which task to toggle.
    final payload = '$projectFilePath|||${todo.id}';
    const actions = [
      AndroidNotificationAction(
        doneActionId,
        'Done!',
        cancelNotification: true,
      ),
    ];

    if (!todo.isRecurring) {
      // Non-recurring: one notification at the alarm time.
      final scheduledDate = tz.TZDateTime.from(todo.alarm!, tz.local);
      if (scheduledDate.isBefore(now)) return;
      await _scheduleZonedWithFallback(
        id: baseId,
        title: todo.title,
        body: 'Project: $projectTitle',
        scheduledDate: scheduledDate,
        payload: payload,
        actions: actions,
      );
      return;
    }

    // Recurring: pre-schedule the next N occurrences so notifications fire
    // even if the app is never opened between recurrences.
    DateTime currentAlarm = todo.alarm!;
    int scheduledCount = 0;
    int maxIter =
        _maxRecurringPreSchedule * 3; // guard against pathological rules

    while (scheduledCount < _maxRecurringPreSchedule && maxIter-- > 0) {
      final scheduledDate = tz.TZDateTime.from(currentAlarm, tz.local);

      if (scheduledDate.isAfter(now)) {
        await _scheduleZonedWithFallback(
          id: (baseId + scheduledCount) % 2147483647,
          title: todo.title,
          body: 'Project: $projectTitle',
          scheduledDate: scheduledDate,
          payload: payload,
          actions: actions,
        );
        scheduledCount++;
      }

      final next = RecurrenceService.nextOccurrence(
        alarm: currentAlarm,
        rule: todo.recurrence!,
        after: currentAlarm,
      );
      if (next == null) break;
      currentAlarm = next;
    }
  }

  /// Schedules a heads-up reminder notification (alarm − reminderBefore).
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

    if (scheduledDate.isBefore(now)) return;

    final id = (todo.id.hashCode.abs() + 1000000) % 2147483647;
    final reminderLabel = todo.reminderLabel ?? todo.reminderString;
    final payload = '$projectFilePath|||${todo.id}';
    const actions = [
      AndroidNotificationAction(
        doneActionId,
        'Done!',
        cancelNotification: true,
      ),
    ];

    await _scheduleZonedWithFallback(
      id: id,
      title: todo.title,
      body: 'Due in $reminderLabel',
      scheduledDate: scheduledDate,
      payload: payload,
      actions: actions,
    );
  }

  /// Cancels all notifications for a sub-todo, including any pre-scheduled
  /// recurring occurrences.
  Future<void> cancelSubTodoNotifications(SubTodo todo) async {
    await _ensureInitialized();

    final baseAlarmId = todo.id.hashCode.abs() % 2147483647;
    final reminderId = (todo.id.hashCode.abs() + 1000000) % 2147483647;

    // Cancel the base alarm and all pre-scheduled recurring occurrences.
    for (int i = 0; i < _maxRecurringPreSchedule; i++) {
      await _plugin.cancel((baseAlarmId + i) % 2147483647);
    }
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
