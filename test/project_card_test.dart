import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdone/models/master_project.dart';
import 'package:markdone/models/sub_todo.dart';
import 'package:markdone/screens/home/widgets/project_card.dart';

Widget wrapWithMaterial(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('renders project title', (WidgetTester tester) async {
    final project = MasterProject(
      filePath: '/tmp/test.md',
      title: 'My Project',
      created: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        ProjectCard(project: project, onTap: () {}),
      ),
    );

    expect(find.text('My Project'), findsOneWidget);
  });

  testWidgets('renders completed badge for completed projects', (
    WidgetTester tester,
  ) async {
    final project = MasterProject(
      filePath: '/tmp/test.md',
      title: 'Done!',
      created: DateTime(2026, 1, 1),
      todos: [
        SubTodo(id: '1', title: 'A', isCompleted: true, lineIndex: 0),
      ],
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        ProjectCard(project: project, onTap: () {}),
      ),
    );

    expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
  });

  testWidgets('shows D-day badge', (WidgetTester tester) async {
    final project = MasterProject(
      filePath: '/tmp/test.md',
      title: 'Event',
      created: DateTime(2026, 1, 1),
      dday: DateTime.now().add(const Duration(days: 5)),
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        ProjectCard(project: project, onTap: () {}),
      ),
    );

    expect(find.textContaining('D-'), findsOneWidget);
  });

  testWidgets('shows D-DAY badge for today', (WidgetTester tester) async {
    final project = MasterProject(
      filePath: '/tmp/test.md',
      title: 'Due Today',
      created: DateTime(2026, 1, 1),
      dday: DateTime.now(),
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        ProjectCard(project: project, onTap: () {}),
      ),
    );

    expect(find.text('D-DAY'), findsOneWidget);
  });

  testWidgets('shows todo previews', (WidgetTester tester) async {
    final project = MasterProject(
      filePath: '/tmp/test.md',
      title: 'Tasks',
      created: DateTime(2026, 1, 1),
      todos: [
        SubTodo(id: '1', title: 'First task', isCompleted: false, lineIndex: 0),
        SubTodo(id: '2', title: 'Second task', isCompleted: true, lineIndex: 1),
      ],
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        ProjectCard(project: project, onTap: () {}),
      ),
    );

    expect(find.text('First task'), findsOneWidget);
    expect(find.text('Second task'), findsOneWidget);
  });

  testWidgets('shows progress bar and count', (WidgetTester tester) async {
    final project = MasterProject(
      filePath: '/tmp/test.md',
      title: 'Progress',
      created: DateTime(2026, 1, 1),
      todos: [
        SubTodo(id: '1', title: 'A', isCompleted: true, lineIndex: 0),
        SubTodo(id: '2', title: 'B', isCompleted: false, lineIndex: 1),
      ],
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        ProjectCard(project: project, onTap: () {}),
      ),
    );

    expect(find.text('1/2'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('hides completed todos when hideCompleted is true', (
    WidgetTester tester,
  ) async {
    final project = MasterProject(
      filePath: '/tmp/test.md',
      title: 'Hidden',
      created: DateTime(2026, 1, 1),
      todos: [
        SubTodo(id: '1', title: 'Pending', isCompleted: false, lineIndex: 0),
        SubTodo(id: '2', title: 'Hidden done', isCompleted: true, lineIndex: 1),
      ],
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        ProjectCard(project: project, onTap: () {}, hideCompleted: true),
      ),
    );

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Hidden done'), findsNothing);
  });

  testWidgets('renders description', (WidgetTester tester) async {
    final project = MasterProject(
      filePath: '/tmp/test.md',
      title: 'With Desc',
      created: DateTime(2026, 1, 1),
      description: 'A short description',
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        ProjectCard(project: project, onTap: () {}),
      ),
    );

    expect(find.text('A short description'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (WidgetTester tester) async {
    var tapped = false;
    final project = MasterProject(
      filePath: '/tmp/test.md',
      title: 'Tappable',
      created: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      wrapWithMaterial(
        ProjectCard(project: project, onTap: () => tapped = true),
      ),
    );

    await tester.tap(find.text('Tappable'));
    expect(tapped, true);
  });
}
