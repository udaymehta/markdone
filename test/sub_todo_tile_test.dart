import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdone/models/sub_todo.dart';
import 'package:markdone/screens/project_detail/widgets/sub_todo_tile.dart';

Widget wrapWithMaterial(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('renders todo title', (WidgetTester tester) async {
    final todo = SubTodo(
      id: '1', title: 'Buy milk', isCompleted: false, lineIndex: 0,
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        SubTodoTile(todo: todo, onToggle: () {}, onTap: () {}),
      ),
    );

    expect(find.text('Buy milk'), findsOneWidget);
  });

  testWidgets('strikethrough when completed', (WidgetTester tester) async {
    final todo = SubTodo(
      id: '1', title: 'Done task', isCompleted: true, lineIndex: 0,
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        SubTodoTile(todo: todo, onToggle: () {}, onTap: () {}),
      ),
    );

    final text = tester.widget<Text>(find.text('Done task'));
    expect(text.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('shows date with ddmmyyyy format', (WidgetTester tester) async {
    final todo = SubTodo(
      id: '1',
      title: 'Scheduled',
      isCompleted: false,
      lineIndex: 0,
      alarm: DateTime(2026, 6, 15, 14, 30),
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        SubTodoTile(todo: todo, onToggle: () {}, onTap: () {}),
      ),
    );

    expect(find.textContaining('15/06/2026'), findsOneWidget);
    expect(find.textContaining('2:30 PM'), findsOneWidget);
  });

  testWidgets('shows recurring icon', (WidgetTester tester) async {
    final todo = SubTodo(
      id: '1',
      title: 'Daily task',
      isCompleted: false,
      lineIndex: 0,
      recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.daily),
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        SubTodoTile(todo: todo, onToggle: () {}, onTap: () {}),
      ),
    );

    expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
  });

  testWidgets('shows recurrence label in metadata', (
    WidgetTester tester,
  ) async {
    final todo = SubTodo(
      id: '1',
      title: 'Weekly',
      isCompleted: false,
      lineIndex: 0,
      alarm: DateTime(2026, 6, 15, 14, 30),
      recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        SubTodoTile(todo: todo, onToggle: () {}, onTap: () {}),
      ),
    );

    expect(find.textContaining('Every week'), findsOneWidget);
  });

  testWidgets('shows reminder in metadata', (WidgetTester tester) async {
    final todo = SubTodo(
      id: '1',
      title: 'Reminded',
      isCompleted: false,
      lineIndex: 0,
      alarm: DateTime(2026, 6, 15, 14, 30),
      reminderBefore: const Duration(hours: 1),
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        SubTodoTile(todo: todo, onToggle: () {}, onTap: () {}),
      ),
    );

    expect(find.textContaining('1 hr before'), findsOneWidget);
  });

  testWidgets('shows calendar icon when event id exists', (
    WidgetTester tester,
  ) async {
    final todo = SubTodo(
      id: '1',
      title: 'Cal',
      isCompleted: false,
      lineIndex: 0,
      calendarEventId: 'cal-123',
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        SubTodoTile(todo: todo, onToggle: () {}, onTap: () {}),
      ),
    );

    expect(find.byIcon(Icons.event_outlined), findsOneWidget);
  });

  testWidgets('swipe right triggers onToggle', (WidgetTester tester) async {
    var toggled = false;
    final todo = SubTodo(
      id: '1', title: 'Swipeable', isCompleted: false, lineIndex: 0,
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        SubTodoTile(todo: todo, onToggle: () => toggled = true, onTap: () {}),
      ),
    );

    await tester.fling(find.text('Swipeable'), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(toggled, true);
  });

  testWidgets('calls onTap when title area tapped', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    final todo = SubTodo(
      id: '1', title: 'Tappable', isCompleted: false, lineIndex: 0,
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        SubTodoTile(todo: todo, onToggle: () {}, onTap: () => tapped = true),
      ),
    );

    await tester.tap(find.text('Tappable'));
    expect(tapped, true);
  });
}
