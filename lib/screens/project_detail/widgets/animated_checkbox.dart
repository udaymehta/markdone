import 'package:flutter/material.dart';

/// A beautiful custom animated checkbox with a check mark animation.
class AnimatedCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;
  final double size;

  const AnimatedCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.size = 24,
  });

  @override
  State<AnimatedCheckbox> createState() => _AnimatedCheckboxState();
}

class _AnimatedCheckboxState extends State<AnimatedCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.85,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.85,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.1,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    _checkAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    );

    if (widget.value) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _controller.forward(from: 0);
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.activeColor ?? theme.colorScheme.primary;

    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.value ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(widget.size * 0.3),
                border: Border.all(
                  color: widget.value
                      ? color
                      : theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                  width: 2,
                ),
                boxShadow: widget.value
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: widget.value
                  ? CustomPaint(
                      painter: _CheckPainter(
                        progress: _checkAnimation.value,
                        color: Colors.white,
                        strokeWidth: 2.0,
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

/// Draws an animated check mark.
class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Check mark points relative to size
    final start = Offset(size.width * 0.22, size.height * 0.52);
    final mid = Offset(size.width * 0.42, size.height * 0.72);
    final end = Offset(size.width * 0.78, size.height * 0.28);

    // Calculate how far along the path we are
    if (progress <= 0.5) {
      // First segment: start to mid
      final t = progress * 2;
      path.moveTo(start.dx, start.dy);
      path.lineTo(
        start.dx + (mid.dx - start.dx) * t,
        start.dy + (mid.dy - start.dy) * t,
      );
    } else {
      // Full first segment + partial second
      final t = (progress - 0.5) * 2;
      path.moveTo(start.dx, start.dy);
      path.lineTo(mid.dx, mid.dy);
      path.lineTo(
        mid.dx + (end.dx - mid.dx) * t,
        mid.dy + (end.dy - mid.dy) * t,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
