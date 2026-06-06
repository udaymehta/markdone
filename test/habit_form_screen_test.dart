import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdone/models/habit.dart';
import 'package:markdone/providers/habit_providers.dart';
import 'package:markdone/providers/settings_providers.dart';
import 'package:markdone/screens/habits/habit_form_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHabitListNotifier extends HabitListNotifier {
  @override
  Future<List<Habit>> build() async => [];
}

Widget createTestApp({Habit? habit}) {
  return ProviderScope(
    overrides: [
      habitListProvider.overrideWith(MockHabitListNotifier.new),
    ],
    child: MaterialApp(home: HabitFormScreen(habit: habit)),
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
          habitListProvider.overrideWith(MockHabitListNotifier.new),
        ],
        child: const MaterialApp(home: HabitFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Habit'), findsOneWidget);
    expect(find.text('Habit name'), findsOneWidget);
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
          habitListProvider.overrideWith(MockHabitListNotifier.new),
        ],
        child: const MaterialApp(home: HabitFormScreen()),
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
          habitListProvider.overrideWith(MockHabitListNotifier.new),
        ],
        child: const MaterialApp(home: HabitFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Exercise');
    await tester.pump();

    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create'),
    );
    expect(createButton.onPressed, isNotNull);
  });

  testWidgets('renders edit mode with existing habit', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final habit = Habit(
      id: '1',
      name: 'Morning Run',
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          habitListProvider.overrideWith(MockHabitListNotifier.new),
        ],
        child: MaterialApp(home: HabitFormScreen(habit: habit)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Habit'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Morning Run'), findsOneWidget);
  });

  testWidgets('shows goal field', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          habitListProvider.overrideWith(MockHabitListNotifier.new),
        ],
        child: const MaterialApp(home: HabitFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Goal (optional)'), findsOneWidget);
  });
}
