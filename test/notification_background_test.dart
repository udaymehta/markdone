import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:markdone/services/notification_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class FakePathProvider extends PathProviderPlatform {
  final String documentsPath;
  FakePathProvider({required this.documentsPath});

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getTemporaryPath() async => '/tmp/test_tmp';

  @override
  Future<String?> getApplicationSupportPath() async => '/tmp/test_support';

  @override
  Future<String?> getLibraryPath() async => null;

  @override
  Future<String?> getApplicationCachePath() async => '/tmp/test_cache';

  @override
  Future<List<String>?> getExternalCachePaths() async => [];

  @override
  Future<String?> getDownloadsPath() async => '/tmp/test_downloads';
}

void main() {
  group('handleBackgroundNotificationResponse', () {
    late Directory tempDir;
    late PathProviderPlatform originalPathProvider;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('notif_test_');
      originalPathProvider = PathProviderPlatform.instance;
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
      PathProviderPlatform.instance = originalPathProvider;
      NotificationService.onDoneAction = null;
    });

    group('edge cases', () {
      test('null payload does nothing', () async {
        await handleBackgroundNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
          ),
        );
      });

      test('null actionId with valid payload does nothing', () async {
        await handleBackgroundNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: '/tmp/test.md|||abc',
          ),
        );
      });

      test('unknown actionId does nothing', () async {
        final projectFile = File('${tempDir.path}/unknown_action.md');
        await projectFile.create(recursive: true);

        await handleBackgroundNotificationResponse(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'unknown_action',
            payload: '${projectFile.path}|||todo-999',
          ),
        );

        final queueFile = File('${tempDir.path}/.markdone_queue');
        expect(await queueFile.exists(), false);
      });
    });

    group('habit notifications', () {
      test('habit_done writes habit ID to queue', () async {
        final docsDir = Directory('${tempDir.path}/app_docs')..createSync();
        PathProviderPlatform.instance = FakePathProvider(
          documentsPath: docsDir.path,
        );

        await handleBackgroundNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'habit_done',
            payload: 'habit|||habit-abc-123',
          ),
        );

        final queueFile = File('${docsDir.path}/.habit_queue');
        expect(await queueFile.exists(), true);
        final content = await queueFile.readAsString();
        expect(content, 'habit-abc-123\n');
      });

      test('habit_not_done does nothing', () async {
        final docsDir = Directory('${tempDir.path}/app_docs2')..createSync();
        PathProviderPlatform.instance = FakePathProvider(
          documentsPath: docsDir.path,
        );

        await handleBackgroundNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'habit_not_done',
            payload: 'habit|||habit-xyz',
          ),
        );

        final queueFile = File('${docsDir.path}/.habit_queue');
        expect(await queueFile.exists(), false);
      });

      test('habit payload with missing ID does not crash', () async {
        final docsDir = Directory('${tempDir.path}/app_docs3')..createSync();
        PathProviderPlatform.instance = FakePathProvider(
          documentsPath: docsDir.path,
        );

        await handleBackgroundNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'habit_done',
            payload: 'habit|||',
          ),
        );

        final queueFile = File('${docsDir.path}/.habit_queue');
        expect(await queueFile.exists(), true);
      });

      test('habit payload with only prefix does not crash', () async {
        final docsDir = Directory('${tempDir.path}/app_docs4')..createSync();
        PathProviderPlatform.instance = FakePathProvider(
          documentsPath: docsDir.path,
        );

        await handleBackgroundNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'habit_done',
            payload: 'habit|||',
          ),
        );

        final queueFile = File('${docsDir.path}/.habit_queue');
        expect(await queueFile.exists(), true);
      });

      test('habit_done with date in payload writes ID and date to queue',
          () async {
        final docsDir = Directory('${tempDir.path}/app_docs_date')
          ..createSync();
        PathProviderPlatform.instance = FakePathProvider(
          documentsPath: docsDir.path,
        );

        await handleBackgroundNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'habit_done',
            payload: 'habit|||habit-date-123|||2026-06-12',
          ),
        );

        final queueFile = File('${docsDir.path}/.habit_queue');
        expect(await queueFile.exists(), true);
        final content = await queueFile.readAsString();
        expect(content, 'habit-date-123|||2026-06-12\n');
      });

      test('habit payload with date and old format both work (backward compat)',
          () async {
        final docsDir = Directory('${tempDir.path}/app_docs_compat')
          ..createSync();
        PathProviderPlatform.instance = FakePathProvider(
          documentsPath: docsDir.path,
        );

        // New format with date
        await handleBackgroundNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'habit_done',
            payload: 'habit|||with-date|||2026-06-12',
          ),
        );

        // Old format without date
        await handleBackgroundNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'habit_done',
            payload: 'habit|||no-date',
          ),
        );

        final queueFile = File('${docsDir.path}/.habit_queue');
        final content = await queueFile.readAsString();
        expect(content, 'with-date|||2026-06-12\nno-date\n');
      });

      test('multiple habit done actions append to same queue', () async {
        final docsDir = Directory('${tempDir.path}/app_docs5')..createSync();
        PathProviderPlatform.instance = FakePathProvider(
          documentsPath: docsDir.path,
        );

        await handleBackgroundNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'habit_done',
            payload: 'habit|||id-1',
          ),
        );
        await handleBackgroundNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'habit_done',
            payload: 'habit|||id-2',
          ),
        );

        final queueFile = File('${docsDir.path}/.habit_queue');
        final content = await queueFile.readAsString();
        expect(content, 'id-1\nid-2\n');
      });
    });

    group('project notifications', () {
      test('done action writes to queue next to project file', () async {
        final projectFile = File('${tempDir.path}/test_project.md');
        await projectFile.create(recursive: true);

        await handleBackgroundNotificationResponse(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: NotificationService.doneActionId,
            payload: '${projectFile.path}|||todo-123',
          ),
        );

        final queueFile = File('${tempDir.path}/.markdone_queue');
        expect(await queueFile.exists(), true);
        final content = await queueFile.readAsString();
        expect(content, '${projectFile.path}|||todo-123\n');
      });

      test('done action with invalid payload (no |||) does nothing', () async {
        await handleBackgroundNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: NotificationService.doneActionId,
            payload: 'invalid-no-separator',
          ),
        );
      });

      test('done action with empty payload part after sep does nothing', () async {
        await handleBackgroundNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: NotificationService.doneActionId,
            payload: '/tmp/test.md|||',
          ),
        );
      });

      test('done action with wrong actionId does not create queue', () async {
        final projectFile = File('${tempDir.path}/wrong_action.md');
        await projectFile.create(recursive: true);

        await handleBackgroundNotificationResponse(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'wrong_id',
            payload: '${projectFile.path}|||todo-456',
          ),
        );

        final queueFile = File('${tempDir.path}/.markdone_queue');
        expect(await queueFile.exists(), false);
      });

      test('multiple done actions append to same queue', () async {
        final projectFile = File('${tempDir.path}/multi.md');
        await projectFile.create(recursive: true);

        await handleBackgroundNotificationResponse(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: NotificationService.doneActionId,
            payload: '${projectFile.path}|||todo-a',
          ),
        );
        await handleBackgroundNotificationResponse(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: NotificationService.doneActionId,
            payload: '${projectFile.path}|||todo-b',
          ),
        );

        final queueFile = File('${tempDir.path}/.markdone_queue');
        final content = await queueFile.readAsString();
        expect(
          content,
          '${projectFile.path}|||todo-a\n${projectFile.path}|||todo-b\n',
        );
      });

      test('done action for files in subdirectory writes queue alongside', () async {
        final projectFile = File(
          '${tempDir.path}/subdir/subsub/my_project.md',
        );
        await projectFile.create(recursive: true);

        await handleBackgroundNotificationResponse(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: NotificationService.doneActionId,
            payload: '${projectFile.path}|||todo-deep',
          ),
        );

        final queueFile = File(
          '${tempDir.path}/subdir/subsub/.markdone_queue',
        );
        expect(await queueFile.exists(), true);
      });

      test('appends habit and project queues independently', () async {
        final docsDir = Directory('${tempDir.path}/both_docs')..createSync();
        PathProviderPlatform.instance = FakePathProvider(
          documentsPath: docsDir.path,
        );

        final projectFile = File('${tempDir.path}/both/project.md');
        await projectFile.create(recursive: true);

        await handleBackgroundNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'habit_done',
            payload: 'habit|||habit-id',
          ),
        );
        await handleBackgroundNotificationResponse(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: NotificationService.doneActionId,
            payload: '${projectFile.path}|||todo-id',
          ),
        );

        final habitQueue = File('${docsDir.path}/.habit_queue');
        final projectQueue = File('${tempDir.path}/both/.markdone_queue');

        expect(await habitQueue.exists(), true);
        expect(await projectQueue.exists(), true);

        expect(await habitQueue.readAsString(), 'habit-id\n');
        expect(
          await projectQueue.readAsString(),
          '${projectFile.path}|||todo-id\n',
        );
      });
    });

    group('onDoneAction foreground callback', () {
      test('callback receives correct filePath and todoId', () async {
        String? capturedFilePath;
        String? capturedTodoId;
        NotificationService.onDoneAction = (filePath, todoId) async {
          capturedFilePath = filePath;
          capturedTodoId = todoId;
        };

        await NotificationService.onDoneAction!('/tmp/test.md', 'todo-xyz');
        expect(capturedFilePath, '/tmp/test.md');
        expect(capturedTodoId, 'todo-xyz');
      });

      test('callback is invoked by handler on done action (foreground path)',
          () async {
        String? capturedFilePath;
        String? capturedTodoId;
        NotificationService.onDoneAction = (filePath, todoId) async {
          capturedFilePath = filePath;
          capturedTodoId = todoId;
        };

        final projectFile = File('${tempDir.path}/fg_test.md');
        await projectFile.create(recursive: true);

        await handleBackgroundNotificationResponse(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: NotificationService.doneActionId,
            payload: '${projectFile.path}|||todo-fg',
          ),
        );

        expect(capturedFilePath, isNull);
        expect(capturedTodoId, isNull);
      });
    });
  });

  group('NotificationService constants', () {
    test('doneActionId is "done"', () {
      expect(NotificationService.doneActionId, 'done');
    });
  });
}
