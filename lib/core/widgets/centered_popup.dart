import 'dart:math' as math;

import 'package:flutter/material.dart';

Future<T?> showCenteredPopup<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  double maxWidth = 520,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      final mediaQuery = MediaQuery.of(dialogContext);
      final availableHeight = math.max(
        220,
        mediaQuery.size.height -
            mediaQuery.viewInsets.bottom -
            mediaQuery.padding.top -
            mediaQuery.padding.bottom -
            48,
      );

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: availableHeight.toDouble(),
          ),
          child: builder(dialogContext),
        ),
      );
    },
  );
}

class CenteredPopupContent extends StatelessWidget {
  const CenteredPopupContent({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.scrollable = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(padding: padding, child: child);

    if (scrollable) {
      content = SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: content,
      );
    }

    return SafeArea(top: false, child: content);
  }
}
