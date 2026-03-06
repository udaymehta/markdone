import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/settings_providers.dart';
import '../../providers/project_providers.dart';
import '../../providers/theme_provider.dart';
import '../../services/calendar_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static final Uri _githubUri = Uri.parse(
    'https://github.com/udaymehta/markdone',
  );
  static const List<Color> _accentOptions = [
    Color(0xFFFF6B35),
    Color(0xFFE53935),
    Color(0xFFD81B60),
    Color(0xFF8E24AA),
    Color(0xFF5E35B1),
    Color(0xFF3949AB),
    Color(0xFF1E88E5),
    Color(0xFF00897B),
    Color(0xFF43A047),
    Color(0xFFFDD835),
    Color(0xFFFB8C00),
    Color(0xFF6D4C41),
  ];

  bool _permissionsChecked = false;
  Map<Permission, PermissionStatus> _permissionStatuses = {};

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final notifStatus = await Permission.notification.status;
    final calendarStatus = await Permission.calendarFullAccess.status;
    final storageStatus = await Permission.manageExternalStorage.status;
    final alarmStatus = await Permission.scheduleExactAlarm.status;

    if (mounted) {
      setState(() {
        _permissionStatuses = {
          Permission.notification: notifStatus,
          Permission.calendarFullAccess: calendarStatus,
          Permission.manageExternalStorage: storageStatus,
          Permission.scheduleExactAlarm: alarmStatus,
        };
        _permissionsChecked = true;
      });
    }
  }

  Future<void> _toggleCalendarSync(bool enable) async {
    if (enable) {
      final status = await Permission.calendarFullAccess.request();
      _checkPermissions();
      if (status.isGranted) {
        ref.read(calendarSyncEnabledProvider.notifier).setEnabled(true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Calendar permission is required to sync.'),
            ),
          );
        }
      }
    } else {
      ref.read(calendarSyncEnabledProvider.notifier).setEnabled(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storagePath = ref.watch(storagePathProvider);
    final effectiveStoragePathAsync = ref.watch(effectiveStoragePathProvider);
    final archiveStoragePathAsync = ref.watch(archiveStoragePathProvider);
    final selectedCalId = ref.watch(selectedCalendarIdProvider);
    final selectedCalName = ref.watch(selectedCalendarNameProvider);
    final hideCompleted = ref.watch(hideCompletedProvider);
    final calSyncEnabled = ref.watch(calendarSyncEnabledProvider);
    final accentColor = ref.watch(accentColorProvider);
    final permissionEntries = _permissionEntries();
    final effectiveStoragePathText = effectiveStoragePathAsync.when(
      data: (path) => path,
      loading: () => 'Resolving storage path…',
      error: (_, _) => storagePath ?? 'Could not resolve storage path',
    );
    final storageSubtitle = storagePath != null
        ? 'Custom folder\n$effectiveStoragePathText'
        : 'Default folder\n$effectiveStoragePathText';
    final archiveStoragePathText = archiveStoragePathAsync.when(
      data: (path) => path,
      loading: () => 'Resolving archive path…',
      error: (_, _) => '$effectiveStoragePathText/archive',
    );
    final showPermissionsSection =
        permissionEntries.isNotEmpty &&
        (!_permissionsChecked ||
            !_allRelevantPermissionsGranted(permissionEntries));

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: theme.textTheme.headlineMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Storage Folder ──
          _SectionHeader(title: 'Storage'),
          _SettingsTile(
            icon: Icons.folder_outlined,
            title: 'Projects Folder',
            subtitle: storageSubtitle,
            subtitleMaxLines: 3,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy_all_rounded, size: 20),
                  tooltip: 'Copy folder path',
                  onPressed: effectiveStoragePathAsync.hasValue
                      ? () => _copyText(
                          effectiveStoragePathText,
                          message: 'Folder path copied',
                        )
                      : null,
                ),
                if (storagePath != null)
                  IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    onPressed: () async {
                      ref.read(storagePathProvider.notifier).clearPath();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reset to default storage folder'),
                          ),
                        );
                      }
                      ref.invalidate(projectsProvider);
                    },
                  ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            onTap: () => _pickFolder(context),
          ),
          _SettingsTile(
            icon: Icons.archive_outlined,
            title: 'Archive Folder',
            subtitle: archiveStoragePathText,
            subtitleMaxLines: 3,
            trailing: IconButton(
              icon: const Icon(Icons.copy_all_rounded, size: 20),
              tooltip: 'Copy archive folder path',
              onPressed: archiveStoragePathAsync.hasValue
                  ? () => _copyText(
                      archiveStoragePathText,
                      message: 'Archive folder path copied',
                    )
                  : null,
            ),
          ),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // ── Tasks ──
          _SectionHeader(title: 'Tasks'),
          _SettingsTile(
            icon: Icons.visibility_off_outlined,
            title: 'Hide Completed Tasks',
            subtitle: hideCompleted
                ? 'Completed tasks are hidden'
                : 'Completed tasks pushed to bottom',
            trailing: Switch(
              value: hideCompleted,
              onChanged: (v) =>
                  ref.read(hideCompletedProvider.notifier).setHideCompleted(v),
              activeTrackColor: theme.colorScheme.primary,
            ),
            onTap: () => ref
                .read(hideCompletedProvider.notifier)
                .setHideCompleted(!hideCompleted),
          ),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // ── Calendar ──
          _SectionHeader(title: 'Calendar'),
          _SettingsTile(
            icon: Icons.sync_rounded,
            title: 'Enable Calendar Sync',
            subtitle: calSyncEnabled
                ? 'Tasks with alarms sync to device calendar'
                : 'Calendar sync disabled',
            trailing: Switch(
              value: calSyncEnabled,
              onChanged: (v) => _toggleCalendarSync(v),
              activeTrackColor: theme.colorScheme.primary,
            ),
            onTap: () => _toggleCalendarSync(!calSyncEnabled),
          ),
          if (calSyncEnabled)
            _SettingsTile(
              icon: Icons.calendar_month_outlined,
              title: 'Sync Calendar',
              subtitle:
                  selectedCalName ??
                  selectedCalId ??
                  'Not selected – tap to choose',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _pickCalendar(context),
            ),
          if (calSyncEnabled && selectedCalId != null)
            _SettingsTile(
              icon: Icons.sync_rounded,
              title: 'Sync Now',
              subtitle: 'Push & pull changes with calendar',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _runFullSync(context),
            ),

          const Divider(height: 32, indent: 16, endIndent: 16),

          // ── Appearance ──
          _SectionHeader(title: 'Appearance'),
          _SettingsTile(
            icon: ref.watch(themeModeProvider) == ThemeMode.dark
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            title: 'Theme',
            subtitle: ref.watch(themeModeProvider) == ThemeMode.dark
                ? 'Dark Mode'
                : 'Light Mode',
            trailing: Switch(
              value: ref.watch(themeModeProvider) == ThemeMode.dark,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              activeTrackColor: theme.colorScheme.primary,
            ),
            onTap: () => ref.read(themeModeProvider.notifier).toggle(),
          ),

          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Accent Color',
            subtitle: 'Pick your app accent color',
            trailing: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.4),
                ),
              ),
            ),
            onTap: () => _pickAccentColor(context),
          ),

          if (showPermissionsSection) ...[
            const Divider(height: 32, indent: 16, endIndent: 16),

            // ── Permissions ──
            _SectionHeader(title: 'Permissions'),
            if (_permissionsChecked)
              ..._buildPermissionTiles(permissionEntries)
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],

          const Divider(height: 32, indent: 16, endIndent: 16),

          // ── About ──
          _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'MarkDone!',
            subtitle: 'v1.0.0(release)',
          ),
          _SettingsTile(
            icon: Icons.link_rounded,
            title: 'GitHub Repo',
            subtitle: 'Tap to open\nhttps://github.com/udaymehta/markdone',
            subtitleMaxLines: 3,
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: _openGithubPage,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<({String label, IconData icon, Permission perm})> _permissionEntries() {
    if (Platform.isAndroid) {
      return const [
        (
          label: 'Notifications',
          icon: Icons.notifications_outlined,
          perm: Permission.notification,
        ),
        (
          label: 'Calendar',
          icon: Icons.calendar_month_outlined,
          perm: Permission.calendarFullAccess,
        ),
        (
          label: 'File Storage',
          icon: Icons.sd_storage_outlined,
          perm: Permission.manageExternalStorage,
        ),
        (
          label: 'Exact Alarms',
          icon: Icons.alarm_rounded,
          perm: Permission.scheduleExactAlarm,
        ),
      ];
    }

    if (Platform.isIOS) {
      return const [
        (
          label: 'Notifications',
          icon: Icons.notifications_outlined,
          perm: Permission.notification,
        ),
        (
          label: 'Calendar',
          icon: Icons.calendar_month_outlined,
          perm: Permission.calendarFullAccess,
        ),
      ];
    }

    return const [];
  }

  bool _allRelevantPermissionsGranted(
    List<({String label, IconData icon, Permission perm})> entries,
  ) {
    if (!_permissionsChecked) return false;
    return entries.every(
      (entry) => _permissionStatuses[entry.perm]?.isGranted ?? false,
    );
  }

  List<Widget> _buildPermissionTiles(
    List<({String label, IconData icon, Permission perm})> entries,
  ) {
    return entries.map((e) {
      final status = _permissionStatuses[e.perm];
      final granted = status?.isGranted ?? false;

      return _SettingsTile(
        icon: e.icon,
        title: e.label,
        subtitle: granted ? 'Granted' : (status?.toString() ?? 'Unknown'),
        trailing: granted
            ? Icon(
                Icons.check_circle_rounded,
                color: Colors.green.shade400,
                size: 22,
              )
            : TextButton(
                onPressed: () async {
                  final result = await e.perm.request();
                  if (result.isPermanentlyDenied) {
                    openAppSettings();
                  }
                  _checkPermissions();
                },
                child: const Text('Grant'),
              ),
        onTap: () {},
      );
    }).toList();
  }

  Future<void> _pickAccentColor(BuildContext context) async {
    final currentColor = ref.read(accentColorProvider);
    final selectedColor = await showModalBottomSheet<Color>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Accent Color', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Choose the color used across the app.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final color in _accentOptions)
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.pop(ctx, color),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: currentColor.toARGB32() == color.toARGB32()
                                  ? theme.colorScheme.onSurface
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: currentColor.toARGB32() == color.toARGB32()
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => Navigator.pop(ctx, _accentOptions.first),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reset to default'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedColor == null) return;
    ref.read(accentColorProvider.notifier).setColor(selectedColor);
  }

  Future<void> _pickFolder(BuildContext context) async {
    // Ensure storage permission first
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Storage permission is required to choose a folder',
              ),
            ),
          );
        }
        return;
      }
    }

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose Projects Folder',
    );

    if (result != null) {
      await ref.read(storagePathProvider.notifier).setPath(result);
      // Reload projects from the new folder
      ref.invalidate(projectsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Projects folder set to:\n$result')),
        );
      }
    }
  }

  Future<void> _pickCalendar(BuildContext context) async {
    final calService = CalendarService();
    final calendars = await calService.getCalendars();

    if (calendars.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No calendars found. Ensure calendar permission is granted '
              'and you have a calendar account on this device.',
            ),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final currentCalId = ref.read(selectedCalendarIdProvider);

    final selected = await showModalBottomSheet<CalendarInfo>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.85,
          minChildSize: 0.3,
          expand: false,
          builder: (ctx, scrollController) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Text(
                      'Select Calendar',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: calendars.length,
                      itemBuilder: (ctx, index) {
                        final cal = calendars[index];
                        final isSelected = currentCalId == cal.id;
                        final readOnlyLabel = cal.isReadOnly
                            ? ' (Read-only)'
                            : '';

                        return ListTile(
                          leading: Icon(
                            Icons.calendar_today_rounded,
                            color: cal.color != null
                                ? Color(cal.color!)
                                : theme.colorScheme.primary,
                          ),
                          title: Text(cal.displayName + readOnlyLabel),
                          subtitle: cal.subtitle.isNotEmpty
                              ? Text(cal.subtitle)
                              : null,
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          onTap: () => Navigator.pop(ctx, cal),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected != null) {
      ref.read(selectedCalendarIdProvider.notifier).setCalendarId(selected.id);
      ref
          .read(selectedCalendarNameProvider.notifier)
          .setCalendarName(selected.displayName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calendar set to: ${selected.displayName}')),
        );
      }
    }
  }

  Future<void> _runFullSync(BuildContext context) async {
    // Show a loading snackbar
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Syncing MarkDone!…'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );
    }

    try {
      await ref.read(projectsProvider.notifier).syncEverything();

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Everything is up to date')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    }
  }

  Future<void> _copyText(String text, {required String message}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openGithubPage() async {
    final launched = await launchUrl(
      _githubUri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open GitHub page.')),
      );
    }
  }
}

// ── Reusable Widgets ──

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final int subtitleMaxLines;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.subtitleMaxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall,
        maxLines: subtitleMaxLines,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
