import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/date_formatters.dart';
import 'core/ota_payload_handler.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'screens/main_shell.dart';

class MarkDoneApp extends ConsumerWidget {
  const MarkDoneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accentColor = ref.watch(accentColorProvider);
    final fontScale = ref.watch(fontScaleProvider);
    final amoled = ref.watch(amoledDarkProvider);

    ref.listen(dateFormatStyleProvider, (_, next) {
      MarkdoneDateFormatter.style = next;
    });

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
      home: const _OtaAwareHome(),
    );
  }
}

class _OtaAwareHome extends StatefulWidget {
  const _OtaAwareHome();
  @override
  State<_OtaAwareHome> createState() => _OtaAwareHomeState();
}

class _OtaAwareHomeState extends State<_OtaAwareHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OtaPayloadHandler.handlePendingUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const MainShell();
  }
}
