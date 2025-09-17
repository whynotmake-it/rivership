import 'package:flutter/material.dart';

/// A widget that adds a colored extension to the bottom of a sheet to
/// account for dragging the sheet further than its content height.
class ExtendSheetAtBottom extends StatelessWidget {
  /// Creates an [ExtendSheetAtBottom].
  const ExtendSheetAtBottom({
    required this.color,
    required this.child,
    this.by,
    super.key,
  });

  /// How much to extend the bottom by.
  ///
  /// If not set, this will use the current [MediaQuery]'s height.
  final double? by;

  /// The color to use for the extended area.
  final Color color;

  /// The child widget to extend.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final by = this.by ?? MediaQuery.sizeOf(context).height;
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
