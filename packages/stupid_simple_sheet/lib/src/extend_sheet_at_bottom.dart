import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/material.dart';

/// A widget that adds a colored extension to the bottom of a sheet to
/// account for dragging the sheet further than its content height.
class ExtendSheetAtBottom extends HookWidget {
  const ExtendSheetAtBottom({
    required this.color,
    required this.child,
    this.by = 1000,
    super.key,
  });

  final double by;

  final Color color;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: -by,
          height: by,
          child: ColoredBox(
            color: color,
          ),
        ),
        child,
      ],
    );
  }
}
