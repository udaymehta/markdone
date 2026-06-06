import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdone/app.dart';
import 'package:markdone/models/master_project.dart';
import 'package:markdone/models/habit.dart';
import 'package:markdone/providers/project_providers.dart';
import 'package:markdone/providers/habit_providers.dart';
import 'package:markdone/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockProjectsNotifier extends ProjectsNotifier {
  @override
  Future<List<MasterProject>> build() async => [];
}

class MockHabitListNotifier extends HabitListNotifier {
  @override
  Future<List<Habit>> build() async => [];
}

ProviderScope createTestApp() {
  return ProviderScope(
    overrides: [
      projectsProvider.overrideWith(MockProjectsNotifier.new),
      habitListProvider.overrideWith(MockHabitListNotifier.new),
    ],
    child: const MarkDoneApp(),
  );
}

void main() {
  testWidgets('App renders Projects tab by default', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          projectsProvider.overrideWith(MockProjectsNotifier.new),
          habitListProvider.overrideWith(MockHabitListNotifier.new),
        ],
        child: const MarkDoneApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Projects'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Empty state shows no-projects message', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          projectsProvider.overrideWith(MockProjectsNotifier.new),
          habitListProvider.overrideWith(MockHabitListNotifier.new),
        ],
        child: const MarkDoneApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No projects yet'), findsOneWidget);
  });
}
