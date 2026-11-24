import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:lucide_icons_flutter/lucide_icons_400.dart';

/// A Lucide glyph in two stroke weights: the lighter one at rest, the
/// heavier one when a coil control emphasizes its icon (coil raises
/// `IconTheme.weight` from 400 to 533 on hover and selection).
///
/// Lucide ships one font per stroke weight instead of a variable font, so
/// [GlyphIcon] picks the font from the ambient weight. Both are constant
/// [IconData]s, so release builds can still tree-shake the fonts.
@immutable
class Glyph {
  const Glyph(this.rest, this.emphasis);

  final IconData rest;
  final IconData emphasis;

  static const home = Glyph(LucideIcons300.house, LucideIcons400.house);
  static const panelLeft = Glyph(
    LucideIcons300.panelLeft,
    LucideIcons400.panelLeft,
  );
  static const eye = Glyph(LucideIcons300.eye, LucideIcons400.eye);
  static const copy = Glyph(LucideIcons300.copy, LucideIcons400.copy);
  static const check = Glyph(LucideIcons300.check, LucideIcons400.check);
  static const arrowRight = Glyph(
    LucideIcons300.arrowRightDir,
    LucideIcons400.arrowRightDir,
  );
  static const arrowLeft = Glyph(
    LucideIcons300.arrowLeftDir,
    LucideIcons400.arrowLeftDir,
  );
  static const play = Glyph(LucideIcons300.play, LucideIcons400.play);
  static const pause = Glyph(LucideIcons300.pause, LucideIcons400.pause);
  static const rotateCcw = Glyph(
    LucideIcons300.rotateCcw,
    LucideIcons400.rotateCcw,
  );
  static const send = Glyph(LucideIcons300.send, LucideIcons400.send);
  static const bell = Glyph(LucideIcons300.bell, LucideIcons400.bell);
  static const bellRing = Glyph(
    LucideIcons300.bellRing,
    LucideIcons400.bellRing,
  );
  static const heart = Glyph(LucideIcons300.heart, LucideIcons400.heart);
  static const wifi = Glyph(LucideIcons300.wifi, LucideIcons400.wifi);
  static const batteryFull = Glyph(
    LucideIcons300.batteryFull,
    LucideIcons400.batteryFull,
  );
  static const sun = Glyph(LucideIcons300.sun, LucideIcons400.sun);
  static const moon = Glyph(LucideIcons300.moon, LucideIcons400.moon);
  static const music = Glyph(LucideIcons300.music, LucideIcons400.music);
  static const skipBack = Glyph(
    LucideIcons300.skipBack,
    LucideIcons400.skipBack,
  );
  static const skipForward = Glyph(
    LucideIcons300.skipForward,
    LucideIcons400.skipForward,
  );
  static const spade = Glyph(LucideIcons300.spade, LucideIcons400.spade);
  static const diamond = Glyph(LucideIcons300.diamond, LucideIcons400.diamond);
  static const club = Glyph(LucideIcons300.club, LucideIcons400.club);
  static const gauge = Glyph(LucideIcons300.gauge, LucideIcons400.gauge);
  static const activity = Glyph(
    LucideIcons300.activity,
    LucideIcons400.activity,
  );
  static const hand = Glyph(LucideIcons300.hand, LucideIcons400.hand);
  static const layers = Glyph(LucideIcons300.layers, LucideIcons400.layers);
  static const listOrdered = Glyph(
    LucideIcons300.listOrdered,
    LucideIcons400.listOrdered,
  );
  static const timer = Glyph(LucideIcons300.timer, LucideIcons400.timer);
  static const blocks = Glyph(LucideIcons300.blocks, LucideIcons400.blocks);
  static const squareStack = Glyph(
    LucideIcons300.squareStack,
    LucideIcons400.squareStack,
  );
  static const spline = Glyph(LucideIcons300.spline, LucideIcons400.spline);
  static const move = Glyph(LucideIcons300.move, LucideIcons400.move);
  static const gripVertical = Glyph(
    LucideIcons300.gripVertical,
    LucideIcons400.gripVertical,
  );
  static const repeat = Glyph(LucideIcons300.repeat, LucideIcons400.repeat);
  static const infinity = Glyph(
    LucideIcons300.infinity,
    LucideIcons400.infinity,
  );
  static const plus = Glyph(LucideIcons300.plus, LucideIcons400.plus);
  static const minus = Glyph(LucideIcons300.minus, LucideIcons400.minus);
  static const chevronDown = Glyph(
    LucideIcons300.chevronDown,
    LucideIcons400.chevronDown,
  );
  static const cloudUpload = Glyph(
    LucideIcons300.cloudUpload,
    LucideIcons400.cloudUpload,
  );
  static const cloudOff = Glyph(
    LucideIcons300.cloudOff,
    LucideIcons400.cloudOff,
  );
  static const slidersHorizontal = Glyph(
    LucideIcons300.slidersHorizontal,
    LucideIcons400.slidersHorizontal,
  );
}

/// Shows a [Glyph] in the ambient [IconTheme]'s size and color.
class GlyphIcon extends StatelessWidget {
  const GlyphIcon(this.glyph, {super.key, this.size, this.semanticLabel});

  final Glyph glyph;

  /// Overrides the [IconTheme]'s size.
  final double? size;

  final String? semanticLabel;

  /// Halfway between coil's rest (400) and emphasis (533) weights.
  static const _emphasisFrom = 466.0;

  @override
  Widget build(BuildContext context) {
    final weight = IconTheme.of(context).weight ?? 400;
    return Icon(
      weight >= _emphasisFrom ? glyph.emphasis : glyph.rest,
      size: size,
      semanticLabel: semanticLabel,
    );
  }
}
