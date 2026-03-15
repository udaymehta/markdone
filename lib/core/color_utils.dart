import 'package:flutter/material.dart';

/// Parses a hex color string (e.g. "#AARRGGBB" or "#RRGGBB") into a [Color].
Color? parseBgColor(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    final hex = value.replaceAll('#', '');
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    } else if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
  } catch (_) {}
  return null;
}

/// Converts a [Color] to "#AARRGGBB" hex string for storage.
String colorToHexString(Color color) {
  final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
  final a = (color.a * 255).round().toRadixString(16).padLeft(2, '0');
  return '#$a$r$g$b';
}

/// Shows a color picker dialog with preset colors and an opacity slider.
Future<Color?> showBgColorPicker(
  BuildContext context,
  Color? initialColor,
) async {
  Color selected = initialColor ?? const Color(0x33FF6B35);
  double opacity = initialColor?.a ?? 0.2;

  return showDialog<Color>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setPickerState) {
        final theme = Theme.of(ctx);
        final baseColor = selected.withValues(alpha: 1.0);
        final previewColor = selected.withValues(alpha: opacity);

        const presetColors = [
          Color(0xFFFF6B35), // Orange (accent)
          Color(0xFFFF3B30), // Red
          Color(0xFFFF9500), // Amber
          Color(0xFFFFCC02), // Yellow
          Color(0xFF34C759), // Green
          Color(0xFF30D158), // Mint
          Color(0xFF00C7BE), // Teal
          Color(0xFF007AFF), // Blue
          Color(0xFF5856D6), // Indigo
          Color(0xFFAF52DE), // Purple
          Color(0xFFFF2D55), // Pink
          Color(0xFF8E8E93), // Grey
        ];

        return AlertDialog(
          title: const Text('Background Color'),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Preview
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: previewColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Color grid
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presetColors.map((color) {
                    final isSelected = baseColor.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () => setPickerState(() {
                        selected = color.withValues(alpha: opacity);
                      }),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(
                                  color: theme.colorScheme.onSurface,
                                  width: 2.5,
                                )
                              : Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                // Opacity slider
                Row(
                  children: [
                    Text('Opacity', style: theme.textTheme.bodySmall),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: opacity,
                        min: 0.05,
                        max: 0.5,
                        onChanged: (v) => setPickerState(() {
                          opacity = v;
                          selected = baseColor.withValues(alpha: opacity);
                        }),
                      ),
                    ),
                    Text(
                      '${(opacity * 100).round()}%',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, previewColor),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    ),
  );
}
