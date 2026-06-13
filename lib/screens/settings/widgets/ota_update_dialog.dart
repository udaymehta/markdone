import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/ota_update_service.dart';

const String _otaDismissedVersionKey = 'ota_dismissed_version';

enum _OtaDialogState { idle, checking, available, downloading, ready, failed }

class OtaUpdateDialogData {
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;
  final String publishedAt;

  const OtaUpdateDialogData({
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.publishedAt,
  });
}

Future<void> showOtaUpdateDialog(
  BuildContext context, {
  OtaUpdateDialogData? initialData,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _OtaUpdateDialog(initialData: initialData),
  );
}

class _OtaUpdateDialog extends StatefulWidget {
  final OtaUpdateDialogData? initialData;
  const _OtaUpdateDialog({this.initialData});

  @override
  State<_OtaUpdateDialog> createState() => _OtaUpdateDialogState();
}

class _OtaUpdateDialogState extends State<_OtaUpdateDialog> {
  _OtaDialogState _state = _OtaDialogState.idle;
  OtaUpdateDialogData? _data;
  String? _errorMessage;
  double _progress = 0;
  String? _apkPath;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _data = widget.initialData;
      _state = _OtaDialogState.available;
    } else {
      _checkForUpdates();
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _state = _OtaDialogState.checking;
      _errorMessage = null;
    });

    final result = await OtaUpdateService.checkForUpdate();

    if (!mounted) return;

    switch (result) {
      case OtaUpToDate(:final currentVersion):
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("You're up to date (v$currentVersion)")),
        );
      case OtaUpdateAvailable(
          :final latestVersion,
          :final releaseNotes,
          :final downloadUrl,
          :final publishedAt,
        ):
        setState(() {
          _state = _OtaDialogState.available;
          _data = OtaUpdateDialogData(
            latestVersion: latestVersion,
            releaseNotes: releaseNotes,
            downloadUrl: downloadUrl,
            publishedAt: publishedAt,
          );
        });
      case OtaCheckError(:final message):
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
    }
  }

  Future<void> _downloadApk() async {
    setState(() {
      _state = _OtaDialogState.downloading;
      _progress = 0;
      _errorMessage = null;
    });

    try {
      final path = await OtaUpdateService.downloadApk(
        url: _data!.downloadUrl,
        version: _data!.latestVersion,
        onProgress: (fraction) {
          if (mounted) setState(() => _progress = fraction);
        },
      );
      if (mounted) {
        setState(() {
          _apkPath = path;
          _state = _OtaDialogState.ready;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Download failed. Please try again.';
          _state = _OtaDialogState.failed;
        });
      }
    }
  }

  Future<void> _installApk() async {
    if (_apkPath == null) return;
    final result = await OpenFilex.open(_apkPath!);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open APK: ${result.message}')),
      );
    }
  }

  Future<void> _dismiss() async {
    if (_data != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_otaDismissedVersionKey, _data!.latestVersion);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(
      'https://github.com/atanhx/markdone/releases/latest',
    );
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open release page.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text('Update'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContent(theme),
      ),
      actions: _buildActions(theme),
    );
  }

  Widget _buildContent(ThemeData theme) {
    switch (_state) {
      case _OtaDialogState.idle:
      case _OtaDialogState.checking:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking for updates…'),
          ],
        );

      case _OtaDialogState.available:
        return _buildAvailableContent(theme);

      case _OtaDialogState.downloading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              'Downloading v${_data!.latestVersion}…',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
        );

      case _OtaDialogState.ready:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.green.shade400, size: 20),
                const SizedBox(width: 8),
                Text(
                  'v${_data!.latestVersion} ready to install',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'The update has been downloaded. Tap Install to apply.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        );

      case _OtaDialogState.failed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    color: theme.colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Download failed',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: theme.textTheme.bodySmall),
            ],
          ],
        );
    }
  }

  Widget _buildAvailableContent(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'v${_data!.latestVersion}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_data!.releaseNotes.isNotEmpty) ...[
            Text(
              'What\'s new',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              _data!.releaseNotes,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildActions(ThemeData theme) {
    switch (_state) {
      case _OtaDialogState.idle:
      case _OtaDialogState.checking:
        return [];

      case _OtaDialogState.available:
        return [
          TextButton(onPressed: _openInBrowser, child: const Text('Open in Browser')),
          TextButton(onPressed: _dismiss, child: const Text('Dismiss')),
          TextButton.icon(
            onPressed: _downloadApk,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download'),
          ),
        ];

      case _OtaDialogState.downloading:
        return [];

      case _OtaDialogState.ready:
        return [
          TextButton(onPressed: _dismiss, child: const Text('Later')),
          TextButton.icon(
            onPressed: _installApk,
            icon: const Icon(Icons.download_done_rounded, size: 18),
            label: const Text('Install'),
          ),
        ];

      case _OtaDialogState.failed:
        return [
          TextButton(onPressed: _dismiss, child: const Text('Dismiss')),
          TextButton(onPressed: _openInBrowser, child: const Text('Open in Browser')),
          TextButton.icon(
            onPressed: _downloadApk,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ];
    }
  }
}
