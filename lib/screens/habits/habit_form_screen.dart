import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/color_utils.dart';
import '../../models/habit.dart';
import '../../providers/habit_providers.dart';

class HabitFormScreen extends ConsumerStatefulWidget {
  final Habit? habit;

  const HabitFormScreen({super.key, this.habit});

  @override
  ConsumerState<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends ConsumerState<HabitFormScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _notifCtrl;
  late final TextEditingController _reminderCtrl;
  late final TextEditingController _goalCtrl;
  late Color _color;
  late bool _reminderSet;
  late int _reminderHour;
  late int _reminderMinute;

  bool get _isEditing => widget.habit != null;

  InputDecoration _decoration({
    required String labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? hintText,
    required ColorScheme colors,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: colors.outline),
    );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
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
    final h = widget.habit;
    _nameCtrl = TextEditingController(text: h?.name ?? '');
    _nameCtrl.addListener(() => setState(() {}));
    _notifCtrl = TextEditingController(
      text: h?.notificationMessage ?? 'Did you complete this habit today?',
    );
    _color = h != null ? _parseColor(h.color) : const Color(0xFF1e88e5);
    _reminderSet = h?.reminderEnabled ?? false;
    _reminderHour = h?.reminderHour ?? 9;
    _reminderMinute = h?.reminderMinute ?? 0;
    _reminderCtrl = TextEditingController(
      text: _reminderSet
          ? '${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')}'
          : 'Off',
    );
    _goalCtrl = TextEditingController(
      text: h?.goal != null && h!.goal > 0 ? h.goal.toString() : '',
    );
    _goalCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notifCtrl.dispose();
    _reminderCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final goalVal = int.tryParse(_goalCtrl.text.trim()) ?? 0;

    if (_isEditing) {
      final updated = widget.habit!.copyWith(
        name: name,
        color: colorToHexString(_color),
        reminderEnabled: _reminderSet,
        reminderHour: _reminderHour,
        reminderMinute: _reminderMinute,
        notificationMessage: _notifCtrl.text.trim().isNotEmpty
            ? _notifCtrl.text.trim()
            : 'Did you complete this habit today?',
        goal: goalVal,
      );
      await ref.read(habitListProvider.notifier).updateHabit(updated);
    } else {
      await ref.read(habitListProvider.notifier).addHabit(
        name,
        colorToHexString(_color),
        reminderEnabled: _reminderSet,
        reminderHour: _reminderHour,
        reminderMinute: _reminderMinute,
        notificationMessage: _notifCtrl.text.trim().isNotEmpty
            ? _notifCtrl.text.trim()
            : 'Did you complete this habit today?',
        goal: goalVal,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _reminderHour,
        minute: _reminderMinute,
      ),
    );
    if (time != null) {
      setState(() {
        _reminderHour = time.hour;
        _reminderMinute = time.minute;
        _reminderSet = true;
        _reminderCtrl.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _clearReminder() {
    setState(() {
      _reminderSet = false;
      _reminderCtrl.text = 'Off';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Habit' : 'New Habit'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  autofocus: !_isEditing,
                  decoration: _decoration(labelText: 'Habit name', colors: colors),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: GestureDetector(
                  onTap: () async {
                    final result = await showAccentColorPicker(
                      context,
                      _color,
                    );
                    if (result != null) setState(() => _color = result);
                  },
                  child: Container(
                    width: 48,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notifCtrl,
            decoration: _decoration(
              labelText: 'Notification message',
              hintText: 'Did you complete this habit today?',
              colors: colors,
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            minLines: 1,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _reminderCtrl,
            readOnly: true,
            decoration: _decoration(
              labelText: 'Daily Reminder',
              suffixIcon: _reminderSet
                  ? IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                      onPressed: _clearReminder,
                    )
                  : null,
              colors: colors,
            ),
            onTap: _pickTime,
            style: TextStyle(
              color: _reminderSet
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              fontWeight:
                  _reminderSet ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _goalCtrl,
            keyboardType: TextInputType.number,
            decoration: _decoration(
              labelText: 'Goal (optional)',
              hintText: 'e.g. 7',
              colors: colors,
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
                  onPressed: _nameCtrl.text.trim().isEmpty ? null : _save,
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
}

Color _parseColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}
