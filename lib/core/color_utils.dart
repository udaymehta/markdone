import 'package:flutter/material.dart';

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

Color parseHexColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

String colorToHexString(Color color) {
  final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}

String colorToHexStringWithAlpha(Color color) {
  final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
  final a = (color.a * 255).round().toRadixString(16).padLeft(2, '0');
  return '#$a$r$g$b';
}

Future<Color?> showAccentColorPicker(
  BuildContext context,
  Color initialColor,
) async {
  final hsl = HSLColor.fromColor(initialColor);
  var hue = hsl.hue;
  var saturation = hsl.saturation;
  var lightness = hsl.lightness;
  var hexController = TextEditingController(
    text: colorToHexString(initialColor),
  );

  return showDialog<Color>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setPickerState) {
        final theme = Theme.of(ctx);
        final currentColor = HSLColor.fromAHSL(
          1.0,
          hue,
          saturation,
          lightness,
        ).toColor();

        return AlertDialog(
          scrollable: true,
          title: const Text('Accent Color'),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HueBar(
                    hue: hue,
                    onChanged: (v) => setPickerState(() => hue = v),
                  ),
                  const SizedBox(height: 12),
                  _SaturationLightnessPicker(
                    hue: hue,
                    saturation: saturation,
                    lightness: lightness,
                    onChanged: (s, l) => setPickerState(() {
                      saturation = s;
                      lightness = l;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.tag_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: hexController,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: '#RRGGBB',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (value) {
                            final parsed = parseBgColor(value);
                            if (parsed != null) {
                              final hsl = HSLColor.fromColor(parsed);
                              setPickerState(() {
                                hue = hsl.hue;
                                saturation = hsl.saturation;
                                lightness = hsl.lightness;
                              });
                            }
                          },
                        ),
                      ),
                      const Spacer(),
                      Text(
                        colorToHexString(currentColor),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, currentColor),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    ),
  );
}

class _HueBar extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;

  const _HueBar({required this.hue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hue', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onHorizontalDragUpdate: (details) {
                final renderBox = context.findRenderObject() as RenderBox;
                final localPos = renderBox.globalToLocal(
                  details.globalPosition,
                );
                final fraction = (localPos.dx / constraints.maxWidth).clamp(
                  0.0,
                  1.0,
                );
                onChanged(fraction * 360);
              },
              onTapDown: (details) {
                final fraction =
                    (details.localPosition.dx / constraints.maxWidth).clamp(
                      0.0,
                      1.0,
                    );
                onChanged(fraction * 360);
              },
              child: Container(
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: List.generate(
                      360 ~/ 10,
                      (i) =>
                          HSLColor.fromAHSL(1.0, i * 10.0, 1.0, 0.5).toColor(),
                    ),
                  ),
                ),
                child: Align(
                  alignment: Alignment(((hue / 360) * 2) - 1, 0),
                  child: Container(
                    width: 4,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: Colors.black26, width: 1),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SaturationLightnessPicker extends StatelessWidget {
  final double hue;
  final double saturation;
  final double lightness;
  final void Function(double saturation, double lightness) onChanged;

  const _SaturationLightnessPicker({
    required this.hue,
    required this.saturation,
    required this.lightness,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const size = 200.0;
    final hueColor = HSLColor.fromAHSL(1.0, hue, 1.0, 0.5).toColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saturation / Brightness',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            final renderBox = context.findRenderObject() as RenderBox;
            final localPos = renderBox.globalToLocal(details.globalPosition);
            final s = (localPos.dx / size).clamp(0.0, 1.0);
            final l = 1.0 - (localPos.dy / size).clamp(0.0, 1.0);
            onChanged(s, l);
          },
          onVerticalDragUpdate: (details) {
            final renderBox = context.findRenderObject() as RenderBox;
            final localPos = renderBox.globalToLocal(details.globalPosition);
            final s = (localPos.dx / size).clamp(0.0, 1.0);
            final l = 1.0 - (localPos.dy / size).clamp(0.0, 1.0);
            onChanged(s, l);
          },
          onTapDown: (details) {
            final s = (details.localPosition.dx / size).clamp(0.0, 1.0);
            final l = 1.0 - (details.localPosition.dy / size).clamp(0.0, 1.0);
            onChanged(s, l);
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: CustomPaint(
                size: const Size(size, size),
                painter: _SLPainter(hue: hue, hueColor: hueColor),
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(size, size),
                    painter: _SLIndicatorPainter(
                      saturation: saturation,
                      lightness: lightness,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SLPainter extends CustomPainter {
  final double hue;
  final Color hueColor;

  _SLPainter({required this.hue, required this.hueColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final satGradient = LinearGradient(
      colors: [Colors.white, hueColor],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    final paint = Paint()
      ..shader = satGradient.createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

    final lightGradient = LinearGradient(
      colors: [Colors.transparent, Colors.black],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    final lightPaint = Paint()
      ..shader = lightGradient.createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), lightPaint);
  }

  @override
  bool shouldRepaint(_SLPainter oldDelegate) => oldDelegate.hue != hue;
}

class _SLIndicatorPainter extends CustomPainter {
  final double saturation;
  final double lightness;

  _SLIndicatorPainter({required this.saturation, required this.lightness});

  @override
  void paint(Canvas canvas, Size size) {
    final x = saturation * size.width;
    final y = (1.0 - lightness) * size.height;
    final center = Offset(x, y);

    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SLIndicatorPainter oldDelegate) =>
      oldDelegate.saturation != saturation ||
      oldDelegate.lightness != lightness;
}

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
