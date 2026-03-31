import 'dart:io';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import '../core/timezone_utils.dart';
import '../models/sub_todo.dart';
import '../models/master_project.dart';

/// Lightweight representation of a device calendar for picker UI.
class CalendarInfo {
  final String id;
  final String name;
  final String accountName;
  final String accountType;
  final int? color;
  final bool isReadOnly;

  const CalendarInfo({
    required this.id,
    required this.name,
    required this.accountName,
    required this.accountType,
    this.color,
    this.isReadOnly = false,
  });

  /// Human-readable display name.
  String get displayName {
    if (name.isNotEmpty && name != accountName) return name;
    if (accountName.isNotEmpty) return accountName;
    return 'Calendar $id';
  }

  /// Subtitle for the picker: shows account or type info.
  String get subtitle {
    if (name.isNotEmpty && name != accountName && accountName.isNotEmpty) {
      return accountName;
    }
    if (accountType.isNotEmpty) return accountType;
    return '';
  }
}

/// Manages 2-way sync between sub-todos and Android Calendar events.
class CalendarService {
  static final CalendarService _instance = CalendarService._();
  factory CalendarService() => _instance;
  CalendarService._();

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();
  bool _hasPermission = false;
  bool _tzInitialized = false;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  Future<void> _ensureTimezone() async {
    if (_tzInitialized) return;
    try {
      await initializeTimezone();
      _log('[CalendarService] tz.local set to: ${tz.local.name}');
    } catch (e) {
      _log('[CalendarService] _ensureTimezone error: $e');
    }
    _tzInitialized = true;
  }

  // ── Timezone helpers ──

  /// Converts any DateTime (including TZDateTime or UTC DateTime) to a plain
  /// local DateTime whose year/month/day/hour/minute/second represent the
  /// wall-clock time in the device's local timezone.
  ///
  /// The device_calendar plugin returns TZDateTime objects that may be in UTC.
  /// We must convert to the local timezone first, then extract wall-clock
  /// components so the rest of the app (which stores offset-free local times)
  /// gets the correct values.
  static DateTime toPlainLocal(DateTime dt) {
    if (dt is tz.TZDateTime) {
      // Convert to local timezone FIRST, then extract components.
      // The plugin often returns TZDateTime in UTC — extracting raw
      // components from a UTC TZDateTime would give us UTC hours, not local.
      final local = tz.TZDateTime.from(dt, tz.local);
      return DateTime(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
        local.millisecond,
      );
    }
    if (dt.isUtc) {
      final local = dt.toLocal();
      return DateTime(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
        local.millisecond,
      );
    }
    return dt;
  }

  /// Constructs a TZDateTime in the device-local timezone from a DateTime.
  ///
  /// - If [dt] is already a TZDateTime (possibly UTC), converts the instant
  ///   to the local timezone.
  /// - If [dt] is a plain UTC DateTime, converts to local.
  /// - If [dt] is a plain local DateTime, builds from its components
  ///   (the values already represent local wall-clock time).
  static tz.TZDateTime toLocalTZ(DateTime dt) {
    if (dt is tz.TZDateTime) {
      return tz.TZDateTime.from(dt, tz.local);
    }
    if (dt.isUtc) {
      return tz.TZDateTime.from(dt, tz.local);
    }
    // Plain local DateTime — build from components.
    return tz.TZDateTime(
      tz.local,
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
    );
  }

  // ── Permissions ──

  /// Best-effort permission check. Returns true if we believe permissions are
  /// granted; false otherwise. The plugin's native methods also handle
  /// permission re-requests internally, so this is just a fast-path hint.
  Future<bool> ensurePermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    if (_hasPermission) return true;

    try {
      // Check if already granted.
      final check = await _plugin.hasPermissions();
      if (check.isSuccess && (check.data ?? false)) {
        _hasPermission = true;
        return true;
      }

      // Request if not yet granted.
      final req = await _plugin.requestPermissions();
      _hasPermission = req.isSuccess && (req.data ?? false);
      return _hasPermission;
    } catch (e) {
      _log('[CalendarService] ensurePermissions error: $e');
      // Don't block — native methods will request permissions themselves.
      return true;
    }
  }

  // ── Calendar listing ──

  /// Retrieve available calendars, mapped to our [CalendarInfo] model so we
  /// never depend on the plugin's nullable fields downstream.
  ///
  /// We intentionally do NOT pre-check permissions here — the plugin's native
  /// `retrieveCalendars()` already requests permissions if needed, and doing
  /// a separate Dart-side check can conflict with it.
  Future<List<CalendarInfo>> getCalendars() async {
    if (!Platform.isAndroid && !Platform.isIOS) return [];

    try {
      final result = await _plugin.retrieveCalendars();

      if (result.errors.isNotEmpty) {
        for (final err in result.errors) {
          _log(
            '[CalendarService] retrieveCalendars error: '
            'code=${err.errorCode}, msg=${err.errorMessage}',
          );
        }
      }

      if (!result.isSuccess || result.data == null) {
        _log(
          '[CalendarService] retrieveCalendars returned no data '
          '(isSuccess=${result.isSuccess}, data=${result.data})',
        );
        return [];
      }

      _log(
        '[CalendarService] retrieveCalendars returned ${result.data!.length} calendar(s)',
      );

      final infos = <CalendarInfo>[];
      for (final cal in result.data!) {
        // Defensive: skip calendars without an ID.
        if (cal.id == null || cal.id!.isEmpty) continue;

        infos.add(
          CalendarInfo(
            id: cal.id!,
            name: cal.name ?? '',
            accountName: cal.accountName ?? '',
            accountType: cal.accountType ?? '',
            color: cal.color,
            isReadOnly: cal.isReadOnly ?? false,
          ),
        );

        _log(
          '[CalendarService] calendar: id=${cal.id}, '
          'name=${cal.name}, account=${cal.accountName}, '
          'type=${cal.accountType}, color=${cal.color}, '
          'readOnly=${cal.isReadOnly}',
        );
      }

      // Sort: writable calendars first, then alphabetical by display name.
      infos.sort((a, b) {
        if (a.isReadOnly != b.isReadOnly) {
          return a.isReadOnly ? 1 : -1;
        }
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });

      return infos;
    } catch (e, st) {
      _log('[CalendarService] getCalendars exception: $e\n$st');
      return [];
    }
  }

  // ── Event CRUD ──

  /// Creates or updates a calendar event for a sub-todo.
  /// Returns the event ID on success, null on failure.
  Future<String?> upsertEvent({
    required String calendarId,
    required SubTodo todo,
    required String projectTitle,
    String? existingEventId,
  }) async {
    if (todo.alarm == null) return null;
    await _ensureTimezone();
    if (!await ensurePermissions()) return null;

    try {
      final event = Event(calendarId);
      if (existingEventId != null) {
        event.eventId = existingEventId;
      }

      // Debug: log the raw alarm and conversion result
      final rawAlarm = todo.alarm!;
      final tzStart = toLocalTZ(rawAlarm);
      _log(
        '[CalendarService] upsertEvent DEBUG:\n'
        '  tz.local.name     = ${tz.local.name}\n'
        '  rawAlarm          = $rawAlarm\n'
        '  rawAlarm.isUtc    = ${rawAlarm.isUtc}\n'
        '  rawAlarm.runtimeType = ${rawAlarm.runtimeType}\n'
        '  rawAlarm.hour     = ${rawAlarm.hour}\n'
        '  rawAlarm.minute   = ${rawAlarm.minute}\n'
        '  rawAlarm.msEpoch  = ${rawAlarm.millisecondsSinceEpoch}\n'
        '  tzStart           = $tzStart\n'
        '  tzStart.location  = ${tzStart.location.name}\n'
        '  tzStart.hour      = ${tzStart.hour}\n'
        '  tzStart.minute    = ${tzStart.minute}\n'
        '  tzStart.msEpoch   = ${tzStart.millisecondsSinceEpoch}\n'
        '  tzStart.toIso     = ${tzStart.toIso8601String()}',
      );

      event.title = '${todo.title} ($projectTitle)';
      event.start = tzStart;
      event.end = tzStart.add(const Duration(hours: 1));

      if (todo.reminderBefore != null) {
        event.reminders = [Reminder(minutes: todo.reminderBefore!.inMinutes)];
      }

      final result = await _plugin.createOrUpdateEvent(event);
      if (result?.isSuccess == true && result!.data != null) {
        _log('[CalendarService] upsertEvent OK → eventId=${result.data}');
        return result.data;
      }
      _log('[CalendarService] upsertEvent failed');
      return null;
    } catch (e) {
      _log('[CalendarService] upsertEvent error: $e');
      return null;
    }
  }

  /// Deletes a calendar event by ID.
  Future<bool> deleteEvent({
    required String calendarId,
    required String eventId,
  }) async {
    if (!await ensurePermissions()) return false;
    try {
      final result = await _plugin.deleteEvent(calendarId, eventId);
      return result.isSuccess && (result.data ?? false);
    } catch (e) {
      _log('[CalendarService] deleteEvent error: $e');
      return false;
    }
  }

  /// Retrieve all events in a calendar within +/- 1 year.
  Future<List<Event>> _retrieveCalendarEvents(String calendarId) async {
    await _ensureTimezone();
    final now = DateTime.now();
    final start = toLocalTZ(now.subtract(const Duration(days: 365)));
    final end = toLocalTZ(now.add(const Duration(days: 365)));

    final result = await _plugin.retrieveEvents(
      calendarId,
      RetrieveEventsParams(startDate: start, endDate: end),
    );

    if (result.isSuccess && result.data != null) {
      return result.data!.toList();
    }
    return [];
  }

  /// Retrieves a single event by ID.
  Future<Event?> getEvent({
    required String calendarId,
    required String eventId,
  }) async {
    if (!await ensurePermissions()) return null;

    try {
      final events = await _retrieveCalendarEvents(calendarId);
      return events.where((e) => e.eventId == eventId).firstOrNull;
    } catch (e) {
      _log('[CalendarService] getEvent error: $e');
      return null;
    }
  }

  // ── 2-Way Sync ──

  /// Full 2-way sync for a single project:
  ///
  /// **Push** – for every todo that has an alarm but no calendarEventId,
  /// create a new calendar event. For todos that already have a calendarEventId,
  /// push any local time changes to the calendar.
  ///
  /// **Pull** – if a calendar event was modified externally (time changed),
  /// update the todo's alarm to match.
  ///
  /// Returns an updated copy of the project if anything changed, or null if
  /// nothing was modified.
  Future<MasterProject?> syncProject({
    required MasterProject project,
    required String calendarId,
  }) async {
    await _ensureTimezone();
    if (!await ensurePermissions()) return null;

    bool anyChanged = false;
    final updatedTodos = <SubTodo>[];

    // Pre-fetch all events in one batch to avoid N+1 queries.
    final allEvents = await _retrieveCalendarEvents(calendarId);
    final eventById = <String, Event>{
      for (final e in allEvents)
        if (e.eventId != null) e.eventId!: e,
    };

    for (final todo in project.todos) {
      // Skip completed todos – remove their calendar events.
      if (todo.isCompleted) {
        if (todo.calendarEventId != null) {
          await deleteEvent(
            calendarId: calendarId,
            eventId: todo.calendarEventId!,
          );
          updatedTodos.add(todo.copyWith(clearCalendarEventId: true));
          anyChanged = true;
        } else {
          updatedTodos.add(todo);
        }
        continue;
      }

      // Per-task calendar opt-out – remove any lingering event.
      if (!todo.syncToCalendar) {
        if (todo.calendarEventId != null) {
          await deleteEvent(
            calendarId: calendarId,
            eventId: todo.calendarEventId!,
          );
          updatedTodos.add(todo.copyWith(clearCalendarEventId: true));
          anyChanged = true;
        } else {
          updatedTodos.add(todo);
        }
        continue;
      }

      // No alarm → nothing to sync.
      if (todo.alarm == null) {
        updatedTodos.add(todo);
        continue;
      }

      // ─── Push: create event if it doesn't exist yet ───
      if (todo.calendarEventId == null) {
        final newId = await upsertEvent(
          calendarId: calendarId,
          todo: todo,
          projectTitle: project.title,
        );
        if (newId != null) {
          updatedTodos.add(todo.copyWith(calendarEventId: newId));
          anyChanged = true;
        } else {
          updatedTodos.add(todo);
        }
        continue;
      }

      // ─── Event exists → compare times (2-way) ───
      final existing = eventById[todo.calendarEventId];
      if (existing == null) {
        // Event was deleted externally → re-create it.
        final newId = await upsertEvent(
          calendarId: calendarId,
          todo: todo,
          projectTitle: project.title,
        );
        if (newId != null) {
          updatedTodos.add(todo.copyWith(calendarEventId: newId));
          anyChanged = true;
        } else {
          updatedTodos.add(todo.copyWith(clearCalendarEventId: true));
          anyChanged = true;
        }
        continue;
      }

      if (existing.start != null) {
        // Convert both to plain local DateTimes for an apples-to-apples
        // comparison (avoids UTC-vs-local and TZDateTime offset issues).
        final externalLocal = toPlainLocal(existing.start!);
        final todoLocal = toPlainLocal(todo.alarm!);
        final drift = externalLocal.difference(todoLocal).abs();

        _log(
          '[CalendarService] sync compare "${todo.title}":\n'
          '  existing.start      = ${existing.start}\n'
          '  existing.start.loc  = ${existing.start!.location.name}\n'
          '  existing.start.hour = ${existing.start!.hour}\n'
          '  externalLocal       = $externalLocal (hour=${externalLocal.hour})\n'
          '  todoLocal           = $todoLocal (hour=${todoLocal.hour})\n'
          '  drift               = ${drift.inMinutes} minutes',
        );

        if (drift > const Duration(minutes: 1)) {
          // Pull: calendar event changed externally → update local alarm.
          updatedTodos.add(todo.copyWith(alarm: externalLocal));
          anyChanged = true;
          _log(
            '[CalendarService] pull: "${todo.title}" alarm updated '
            'from $todoLocal → $externalLocal',
          );
          continue;
        }
      }

      // Push: make sure the event title/reminders are up-to-date.
      await upsertEvent(
        calendarId: calendarId,
        todo: todo,
        projectTitle: project.title,
        existingEventId: todo.calendarEventId,
      );
      updatedTodos.add(todo);
    }

    if (anyChanged) {
      return project.copyWith(todos: updatedTodos);
    }
    return null;
  }

  /// Sync all projects that have `syncWithCalendar == true`.
  /// Returns a map of filePath → updated project for those that changed.
  Future<Map<String, MasterProject>> syncAllProjects({
    required List<MasterProject> projects,
    required String calendarId,
  }) async {
    final changes = <String, MasterProject>{};
    for (final project in projects) {
      if (!project.syncWithCalendar) continue;
      final updated = await syncProject(
        project: project,
        calendarId: calendarId,
      );
      if (updated != null) {
        changes[project.filePath] = updated;
      }
    }
    return changes;
  }
}
