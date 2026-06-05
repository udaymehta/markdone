import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/color_utils.dart';
import '../../core/date_formatters.dart';
import '../../models/master_project.dart';
import '../../providers/project_providers.dart';
import '../../providers/settings_providers.dart';

class ProjectFormScreen extends ConsumerStatefulWidget {
  final MasterProject? project;
  final String? filePath;

  const ProjectFormScreen({
    super.key,
    this.project,
    this.filePath,
  }) : assert(project != null || filePath == null);

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _ddayCtrl;
  late final TextEditingController _bgColorCtrl;
  late final TextEditingController _syncCtrl;
  late DateTime? _dday;
  late Color? _bgColor;
  late bool _syncWithCalendar;
  bool _calSyncEnabled = false;

  bool get _isEditing => widget.project != null;

  InputDecoration _decoration({
    required String labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    required ColorScheme colors,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: colors.outline),
    );
    return InputDecoration(
      labelText: labelText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: border,
      enabledBorder: border,
      focusedBorder: border,
      isDense: true,
    );
  }

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _titleCtrl = TextEditingController(text: p?.title ?? '');
    _titleCtrl.addListener(() => setState(() {}));
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _dday = p?.dday;
    _bgColor = p?.bgColor != null ? _parseBgColor(p!.bgColor!) : null;
    _syncWithCalendar = p?.syncWithCalendar ?? false;
    _ddayCtrl = TextEditingController(
      text: _dday != null ? MarkdoneDateFormatter.formatDate(_dday!) : 'Not set',
    );
    _bgColorCtrl = TextEditingController(
      text: _bgColor != null ? 'Set' : 'Not set',
    );
    _syncCtrl = TextEditingController(
      text: _syncWithCalendar ? 'Enabled' : 'Disabled',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _calSyncEnabled = ref.read(calendarSyncEnabledProvider);
        });
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _ddayCtrl.dispose();
    _bgColorCtrl.dispose();
    _syncCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    if (_isEditing) {
      final updated = widget.project!.copyWith(
        title: title,
        description: _descCtrl.text.trim().isNotEmpty
            ? _descCtrl.text.trim()
            : null,
        dday: _dday,
        bgColor: _bgColor != null
            ? colorToHexStringWithAlpha(_bgColor!)
            : null,
        syncWithCalendar: _syncWithCalendar,
        clearDescription: _descCtrl.text.trim().isEmpty,
        clearBgColor: _bgColor == null,
        clearDday: _dday == null,
      );
      await ref.read(projectsProvider.notifier).updateProjectMetadata(
        updated,
      );
    } else {
      await ref.read(projectsProvider.notifier).createProject(
        title: title,
        dday: _dday,
        description: _descCtrl.text.trim().isNotEmpty
            ? _descCtrl.text.trim()
            : null,
        bgColor: _bgColor != null
            ? colorToHexStringWithAlpha(_bgColor!)
            : null,
        syncWithCalendar: _syncWithCalendar,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Project' : 'New Project'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          TextField(
            controller: _titleCtrl,
            autofocus: !_isEditing,
            decoration: _decoration(
              labelText: 'Project name',
              prefixIcon: const Icon(Icons.folder_outlined),
              colors: colors,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            decoration: _decoration(
              labelText: 'Description (optional)',
              prefixIcon: const Icon(Icons.notes_rounded),
              colors: colors,
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            minLines: 1,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ddayCtrl,
            readOnly: true,
            decoration: _decoration(
              labelText: 'D-Day',
              prefixIcon: Icon(
                _dday != null
                    ? Icons.event_rounded
                    : Icons.event_outlined,
              ),
              suffixIcon: _dday != null
                  ? IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                      onPressed: () {
                        setState(() => _dday = null);
                        _ddayCtrl.text = 'Not set';
                      },
                    )
                  : null,
              colors: colors,
            ),
            onTap: _pickDday,
            style: TextStyle(
              color: _dday != null
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 16),
          if (_calSyncEnabled) ...[
            TextFormField(
              controller: _syncCtrl,
              readOnly: true,
              decoration: _decoration(
                labelText: 'Sync with calendar',
                prefixIcon: const Icon(Icons.sync_rounded),
                suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                colors: colors,
              ),
              onTap: () {
                setState(() {
                  _syncWithCalendar = !_syncWithCalendar;
                  _syncCtrl.text = _syncWithCalendar ? 'Enabled' : 'Disabled';
                });
              },
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _bgColorCtrl,
            readOnly: true,
            decoration: _decoration(
              labelText: 'Background color',
              prefixIcon: const Icon(Icons.palette_outlined),
              suffixIcon: _bgColor != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _bgColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                          ),
                          onPressed: () {
                            setState(() => _bgColor = null);
                            _bgColorCtrl.text = 'Not set';
                          },
                        ),
                      ],
                    )
                  : null,
              colors: colors,
            ),
            onTap: () async {
              final picked = await showBgColorPicker(context, _bgColor);
              if (picked != null) {
                setState(() => _bgColor = picked);
                _bgColorCtrl.text = 'Set';
              }
            },
            style: TextStyle(
              color: _bgColor != null
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _titleCtrl.text.trim().isEmpty ? null : _save,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(_isEditing ? 'Save' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dday ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: _dday != null
          ? _dday!.subtract(const Duration(days: 365))
          : DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _dday = picked);
      _ddayCtrl.text = MarkdoneDateFormatter.formatDate(picked);
    }
  }
}

Color? _parseBgColor(String? hex) {
  if (hex == null) return null;
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
  if (hex.length == 8) return Color(int.parse(hex, radix: 16));
  return null;
}
