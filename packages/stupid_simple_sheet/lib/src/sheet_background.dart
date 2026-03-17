import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';
import 'package:stupid_simple_sheet/src/optimized_clip.dart';

/// A widget that provides a background for a sheet, including shape and color.
///
/// Will also extend the background color below the sheet to account for
/// dragging the sheet further than its content height.
class SheetBackground extends StatelessWidget {
  /// Creates a [SheetBackground].
  const SheetBackground({
    required this.child,
    super.key,
    this.backgroundColor,
    this.shape = const RoundedSuperellipseBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    this.clipBehavior = Clip.antiAlias,
    this.elevateCupertinoUserInterfaceLevel = true,
    this.extensionAtBottom,
  });

  /// The shape that the sheet should have.
  ///
  /// The child will be clipped to fit that shape, if [clipBehavior] is not
  /// [Clip.none].
  /// Defaults to a rounded superellipse with 24px radius at the top.
  final ShapeBorder shape;

  /// The background color of the sheet.
  ///
  /// If null, the sheet will try to use the scaffoldBackgroundColor from
  /// the current [CupertinoTheme] if one exists in the context and will resolve
  /// that color with the current interface level.
  ///
  /// If there is no [CupertinoTheme], it will fall back to using the material
  /// [Theme].
  final Color? backgroundColor;

  /// The [Clip] behavior to use for the sheet's content.
  ///
  /// Defaults to [Clip.antiAlias].
  /// If you set this to [Clip.none], the sheet's content will not be clipped.
  final Clip clipBehavior;

  /// How much to extend the sheet background below the sheet itself.
  ////
  /// This is useful to cover up any content below the sheet when the user
  /// drags the sheet up further than its content height.
  ///
  /// If null (default), it will extend by the full height of the screen.
  final double? extensionAtBottom;

  /// Whether the sheet should live on the elevated Cupertino user interface
  /// level, which some [CupertinoDynamicColor]s will respond to.
  ///
  /// If you set this to false, the sheet will inherit the current user
  /// interface level from the context, or default to
  /// [CupertinoUserInterfaceLevelData.base] if there is no level in the
  /// context.
  ///
  /// Defaults to `true`.
  final bool elevateCupertinoUserInterfaceLevel;

  /// The content of the sheet.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final bottomExtension =
        extensionAtBottom ?? MediaQuery.sizeOf(context).height;
    return CupertinoUserInterfaceLevel(
      data: elevateCupertinoUserInterfaceLevel
          ? CupertinoUserInterfaceLevelData.elevated
          : CupertinoUserInterfaceLevel.maybeOf(context) ??
              CupertinoUserInterfaceLevelData.base,
      child: Builder(
        builder: (context) {
          final color = backgroundColor ?? _getDefaultBackgroundColor(context);
          return PaddingExtended(
            padding: EdgeInsets.only(bottom: -bottomExtension),
            child: DecoratedBox(
              decoration: ShapeDecoration(shape: shape, color: color),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomExtension),
                child: OptimizedClip(
                  clipBehavior: clipBehavior,
                  shape: shape,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getDefaultBackgroundColor(BuildContext context) {
    final cupertinoTheme = context
        .dependOnInheritedWidgetOfExactType<InheritedCupertinoTheme>()
        ?.theme
        .data;
    if (cupertinoTheme != null) {
      return CupertinoDynamicColor.resolve(
        cupertinoTheme.scaffoldBackgroundColor,
        context,
      );
    } else {
      return Theme.of(context).colorScheme.surface;
    }
  }
}
