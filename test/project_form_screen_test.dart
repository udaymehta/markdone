import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdone/models/master_project.dart';
import 'package:markdone/providers/project_providers.dart';
import 'package:markdone/providers/settings_providers.dart';
import 'package:markdone/screens/projects/project_form_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockProjectsNotifier extends ProjectsNotifier {
  @override
  Future<List<MasterProject>> build() async => [];
}

ProviderScope createTestApp({MasterProject? project, String? filePath}) {
  return ProviderScope(
    overrides: [
      projectsProvider.overrideWith(MockProjectsNotifier.new),
    ],
    child: MaterialApp(
      home: ProjectFormScreen(project: project, filePath: filePath),
    ),
  );
}

void main() {
  testWidgets('renders name field and create button', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          projectsProvider.overrideWith(MockProjectsNotifier.new),
        ],
        child: const MaterialApp(home: ProjectFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Project'), findsOneWidget);
    expect(find.text('Project name'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('create button is disabled when name is empty', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          projectsProvider.overrideWith(MockProjectsNotifier.new),
        ],
        child: const MaterialApp(home: ProjectFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create'),
    );
    expect(createButton.onPressed, isNull);
  });

  testWidgets('create button is enabled when name is filled', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          projectsProvider.overrideWith(MockProjectsNotifier.new),
        ],
        child: const MaterialApp(home: ProjectFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final nameField = find.widgetWithText(TextField, '').first;
    await tester.enterText(nameField, 'My Project');
    await tester.pump();

    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create'),
    );
    expect(createButton.onPressed, isNotNull);
  });

  testWidgets('renders edit mode with existing project', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final project = MasterProject(
      filePath: '/tmp/test.md',
      title: 'Existing Project',
      created: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          projectsProvider.overrideWith(MockProjectsNotifier.new),
        ],
        child: MaterialApp(home: ProjectFormScreen(project: project)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Project'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Existing Project'), findsOneWidget);
  });

  testWidgets('shows D-day field', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          projectsProvider.overrideWith(MockProjectsNotifier.new),
        ],
        child: const MaterialApp(home: ProjectFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('D-Day'), findsOneWidget);
  });

  testWidgets('shows description and background color fields', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          projectsProvider.overrideWith(MockProjectsNotifier.new),
        ],
        child: const MaterialApp(home: ProjectFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Description (optional)'), findsOneWidget);
    expect(find.text('Background color'), findsOneWidget);
  });
}
