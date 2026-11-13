import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Size, color and stroke width for [FluidIcon]s in a subtree.
///
/// Controls set this for their icon slots: a button's icons are 16 px at a
/// 1.5 stroke and thicken to 2 on hover. Any widget can sit in an icon slot;
/// widgets that want to follow the control's state read this (or the
/// ambient [IconTheme], which controls also set).
class FluidIconTheme extends InheritedWidget {
  /// Creates an icon theme.
  const FluidIconTheme({
    required this.data,
    required super.child,
    super.key,
  });

  /// The icon style.
  final FluidIconThemeData data;

  /// The nearest icon style, or a 16 px, 1.5 stroke default.
  static FluidIconThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FluidIconTheme>()?.data ??
      const FluidIconThemeData();

  @override
  bool updateShouldNotify(FluidIconTheme oldWidget) => oldWidget.data != data;
}

/// The style of a [FluidIcon].
@immutable
class FluidIconThemeData {
  /// Creates an icon style.
  const FluidIconThemeData({
    this.size = 16,
    this.strokeWidth = 1.5,
    this.color,
  });

  /// Edge length in logical pixels.
  final double size;

  /// Stroke width in the icon's 24-unit grid, as lucide-style web icons
  /// take it: 1.5 on a 16 px icon draws a 1 px line.
  final double strokeWidth;

  /// Stroke color; falls back to the ambient text color.
  final Color? color;

  @override
  bool operator ==(Object other) =>
      other is FluidIconThemeData &&
      other.size == size &&
      other.strokeWidth == strokeWidth &&
      other.color == color;

  @override
  int get hashCode => Object.hash(size, strokeWidth, color);
}

/// A stroke icon drawn on a 24×24 grid, like the web's icon sets.
@immutable
class FluidIconData {
  /// Creates icon data from a path builder in 24-unit grid coordinates.
  const FluidIconData(this._build);

  final void Function(ui.Path path) _build;

  /// The icon's outline in grid coordinates.
  ui.Path get path {
    final p = ui.Path();
    _build(p);
    return p;
  }
}

/// A small built-in stroke icon set for the components and demos.
///
/// Slots take any [Widget]; these exist so the package has no icon-font
/// dependency and so icons can animate their stroke with the control.
abstract final class FluidIcons {
  /// A plus.
  static const plus = FluidIconData(_plus);

  /// A minus.
  static const minus = FluidIconData(_minus);

  /// A check mark.
  static const check = FluidIconData(_check);

  /// An arrow pointing right.
  static const arrowRight = FluidIconData(_arrowRight);

  /// A chevron pointing down.
  static const chevronDown = FluidIconData(_chevronDown);

  /// A magnifying glass.
  static const search = FluidIconData(_search);

  /// A cross.
  static const x = FluidIconData(_x);

  /// A heart.
  static const heart = FluidIconData(_heart);

  /// A house.
  static const home = FluidIconData(_home);

  /// A gear-ish sun (settings).
  static const settings = FluidIconData(_settings);

  /// A person.
  static const user = FluidIconData(_user);

  /// A trash can.
  static const trash = FluidIconData(_trash);

  static void _plus(ui.Path p) => p
    ..moveTo(5, 12)
    ..lineTo(19, 12)
    ..moveTo(12, 5)
    ..lineTo(12, 19);

  static void _minus(ui.Path p) => p
    ..moveTo(5, 12)
    ..lineTo(19, 12);

  static void _check(ui.Path p) => p
    ..moveTo(20, 6)
    ..lineTo(9, 17)
    ..lineTo(4, 12);

  static void _arrowRight(ui.Path p) => p
    ..moveTo(5, 12)
    ..lineTo(19, 12)
    ..moveTo(12, 5)
    ..lineTo(19, 12)
    ..lineTo(12, 19);

  static void _chevronDown(ui.Path p) => p
    ..moveTo(6, 9)
    ..lineTo(12, 15)
    ..lineTo(18, 9);

  static void _search(ui.Path p) => p
    ..addOval(Rect.fromCircle(center: const Offset(11, 11), radius: 8))
    ..moveTo(21, 21)
    ..lineTo(16.65, 16.65);

  static void _x(ui.Path p) => p
    ..moveTo(18, 6)
    ..lineTo(6, 18)
    ..moveTo(6, 6)
    ..lineTo(18, 18);

  static void _heart(ui.Path p) => p
    ..moveTo(12, 20)
    ..cubicTo(12, 20, 3, 14.5, 3, 8.5)
    ..cubicTo(3, 5.5, 5.5, 3.5, 8, 3.5)
    ..cubicTo(9.8, 3.5, 11.2, 4.5, 12, 6)
    ..cubicTo(12.8, 4.5, 14.2, 3.5, 16, 3.5)
    ..cubicTo(18.5, 3.5, 21, 5.5, 21, 8.5)
    ..cubicTo(21, 14.5, 12, 20, 12, 20)
    ..close();

  static void _home(ui.Path p) => p
    ..moveTo(3, 10)
    ..lineTo(12, 3)
    ..lineTo(21, 10)
    ..lineTo(21, 20)
    ..lineTo(15, 20)
    ..lineTo(15, 14)
    ..lineTo(9, 14)
    ..lineTo(9, 20)
    ..lineTo(3, 20)
    ..close();

  static void _settings(ui.Path p) {
    p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 3.5));
    const spokes = [
      (12.0, 2.0, 12.0, 5.0),
      (12.0, 19.0, 12.0, 22.0),
      (2.0, 12.0, 5.0, 12.0),
      (19.0, 12.0, 22.0, 12.0),
      (4.9, 4.9, 7.0, 7.0),
      (17.0, 17.0, 19.1, 19.1),
      (4.9, 19.1, 7.0, 17.0),
      (17.0, 7.0, 19.1, 4.9),
    ];
    for (final (x1, y1, x2, y2) in spokes) {
      p
        ..moveTo(x1, y1)
        ..lineTo(x2, y2);
    }
  }

  static void _user(ui.Path p) => p
    ..addOval(Rect.fromCircle(center: const Offset(12, 8), radius: 4))
    ..moveTo(4, 21)
    ..cubicTo(4, 17, 7.5, 14.5, 12, 14.5)
    ..cubicTo(16.5, 14.5, 20, 17, 20, 21);

  static void _trash(ui.Path p) => p
    ..moveTo(3, 6)
    ..lineTo(21, 6)
    ..moveTo(19, 6)
    ..lineTo(18, 20)
    ..cubicTo(18, 21, 17, 22, 16, 22)
    ..lineTo(8, 22)
    ..cubicTo(7, 22, 6, 21, 6, 20)
    ..lineTo(5, 6)
    ..moveTo(8, 6)
    ..lineTo(8, 4)
    ..cubicTo(8, 3, 9, 2, 10, 2)
    ..lineTo(14, 2)
    ..cubicTo(15, 2, 16, 3, 16, 4)
    ..lineTo(16, 6);
}

/// Draws a [FluidIconData] with the ambient [FluidIconTheme].
class FluidIcon extends StatelessWidget {
  /// Creates an icon.
  const FluidIcon(
    this.icon, {
    super.key,
    this.size,
    this.strokeWidth,
    this.color,
    this.semanticLabel,
  });

  /// The icon to draw.
  final FluidIconData icon;

  /// Overrides the theme's size.
  final double? size;

  /// Overrides the theme's stroke width.
  final double? strokeWidth;

  /// Overrides the theme's color.
  final Color? color;

  /// A label for assistive technology; the icon is decorative without one.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = FluidIconTheme.of(context);
    final s = size ?? theme.size;
    final paint = CustomPaint(
      size: Size.square(s),
      painter: _IconPainter(
        icon: icon,
        strokeWidth: strokeWidth ?? theme.strokeWidth,
        color:
            color ??
            theme.color ??
            DefaultTextStyle.of(context).style.color ??
            const Color(0xFF000000),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: paint);
    return Semantics(label: semanticLabel, image: true, child: paint);
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter({
    required this.icon,
    required this.strokeWidth,
    required this.color,
  });

  final FluidIconData icon;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas
      ..save()
      ..scale(scale)
      ..drawPath(
        icon.path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          // The web passes strokeWidth in grid units (lucide-style): a 1.5
          // stroke on a 16 px icon is 1 px on screen.
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.strokeWidth != strokeWidth || old.color != color;
}
