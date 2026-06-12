import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;
import '../core/timezone_utils.dart';
import '../models/sub_todo.dart';
import '../models/master_project.dart';
import 'recurrence_service.dart';

@pragma('vm:entry-point')
Future<void> handleBackgroundNotificationResponse(
  NotificationResponse response,
) async {
  final payload = response.payload;
  if (payload == null) return;

  if (payload.startsWith('habit|||')) {
    if (response.actionId != 'habit_done') return;
    final parts = payload.split('|||');
    if (parts.length < 2) return;
    final habitId = parts[1];
    final dateStr = parts.length >= 3 ? parts[2] : null;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final queueFile = File('${dir.path}/.habit_queue');
      final line = dateStr != null ? '$habitId|||$dateStr\n' : '$habitId\n';
      await queueFile.writeAsString(line, mode: FileMode.append);
    } catch (_) {
      // Best-effort I/O
    }
    return;
  }

  if (response.actionId != NotificationService.doneActionId) return;

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

class NotificationService {
  static const String _remindersChannelId = 'markdone_reminders';
  static const String _instantChannelId = 'markdone_instant';
  static const String _habitChannelId = 'markdone_habit_reminders';

  static const String doneActionId = 'done';
  static const String habitDoneActionId = 'habit_done';
  static const String habitNotDoneActionId = 'habit_not_done';

  static const int _maxRecurringPreSchedule = 10;

  static Future<void> Function(String filePath, String todoId)? onDoneAction;
  static Future<void> Function(String habitId, [String? notificationDate])?
      onHabitDoneAction;

  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

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

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _habitChannelId,
            'Habit Reminders',
            description: 'Daily reminders for habits',
            importance: Importance.high,
          ),
        );

        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
      }
    }

    _initialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) await init();
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    if (payload.startsWith('habit|||')) {
      if (response.actionId == habitDoneActionId) {
        final parts = payload.split('|||');
        if (parts.length >= 2) {
          final dateStr = parts.length >= 3 ? parts[2] : null;
          onHabitDoneAction?.call(parts[1], dateStr);
        }
      }
      return;
    }

    if (response.actionId == doneActionId) {
      final sep = payload.indexOf('|||');
      if (sep < 0) return;
      final filePath = payload.substring(0, sep);
      final todoId = payload.substring(sep + 3);
      // Delegate to whatever ProjectsNotifier has wired up.
      onDoneAction?.call(filePath, todoId);
    }
    // Other taps (notification body): no-op for now — reserved for deep-link.
  }

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

  Future<void> cancelSubTodoNotifications(SubTodo todo) async {
    await _ensureInitialized();

    final baseAlarmId = todo.id.hashCode.abs() % 2147483647;
    final reminderId = (todo.id.hashCode.abs() + 1000000) % 2147483647;

    for (int i = 0; i < _maxRecurringPreSchedule; i++) {
      await _plugin.cancel((baseAlarmId + i) % 2147483647);
    }
    await _plugin.cancel(reminderId);
  }

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

  Future<void> scheduleHabitReminder({
    required String habitId,
    required String habitName,
    required int hour,
    required int minute,
    String notificationMessage = 'Did you complete this habit today?',
  }) async {
    await _ensureInitialized();

    final nowLocal = DateTime.now();
    var intendedDate = DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day);
    var scheduledDate = tz.TZDateTime.from(
      DateTime(nowLocal.year, nowLocal.month, nowLocal.day, hour, minute),
      tz.local,
    );
    if (scheduledDate.isBefore(tz.TZDateTime.from(nowLocal, tz.local))) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
      intendedDate = intendedDate.add(const Duration(days: 1));
    }

    final id = (habitId.hashCode.abs() + 2000000) % 2147483647;
    final dateStr =
        '${intendedDate.year}-${intendedDate.month.toString().padLeft(2, '0')}-${intendedDate.day.toString().padLeft(2, '0')}';
    final payload = 'habit|||$habitId|||$dateStr';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _habitChannelId,
        'Habit Reminders',
        channelDescription: 'Daily reminders for habits',
        importance: Importance.high,
        priority: Priority.high,
        actions: [
          AndroidNotificationAction(
            'habit_done',
            'Done',
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'habit_not_done',
            'Not Done',
            cancelNotification: true,
          ),
        ],
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        habitName,
        notificationMessage,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id,
        habitName,
        notificationMessage,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  Future<void> cancelHabitReminder(String habitId) async {
    await _ensureInitialized();
    final id = (habitId.hashCode.abs() + 2000000) % 2147483647;
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }

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

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    await _ensureInitialized();
    return _plugin.pendingNotificationRequests();
  }
}
