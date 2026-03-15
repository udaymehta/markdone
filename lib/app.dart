import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/date_formatters.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'screens/home/home_screen.dart';

class MarkDoneApp extends ConsumerWidget {
  const MarkDoneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accentColor = ref.watch(accentColorProvider);
    final fontScale = ref.watch(fontScaleProvider);
    final amoled = ref.watch(amoledDarkProvider);
    final dateStyle = ref.watch(dateFormatStyleProvider);

    // Apply date format globally so stateless widgets pick it up.
    MarkdoneDateFormatter.style = dateStyle;

    return MaterialApp(
      title: 'MarkDone!',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(accentColor),
      darkTheme: AppTheme.darkTheme(accentColor, amoled),
      themeMode: themeMode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(fontScale)),
          child: child!,
        );
      },
      home: const HomeScreen(),
    );
  }
}
