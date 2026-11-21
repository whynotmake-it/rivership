import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:lucide_icons_flutter/lucide_icons_400.dart';

/// A Lucide glyph in two stroke weights: 1.5 at rest, 2 when a control
/// emphasizes its icon (coil raises `IconTheme.weight` from 400 to 533).
///
/// Lucide ships one font per stroke weight instead of a variable font, so
/// [DemoIcon] picks the font from the ambient weight. Both are constant
/// [IconData]s, so release builds can still tree-shake the fonts.
class Glyph {
  const Glyph(this.rest, this.emphasis);

  final IconData rest;
  final IconData emphasis;

  static const back = Glyph(
    LucideIcons300.chevronLeftDir,
    LucideIcons400.chevronLeftDir,
  );
  static const close = Glyph(LucideIcons300.x, LucideIcons400.x);
  static const settings = Glyph(
    LucideIcons300.settings2,
    LucideIcons400.settings2,
  );
  static const grid = Glyph(
    LucideIcons300.layoutGrid,
    LucideIcons400.layoutGrid,
  );
  static const zoom = Glyph(LucideIcons300.maximize2, LucideIcons400.maximize2);
  static const keyboard = Glyph(
    LucideIcons300.keyboard,
    LucideIcons400.keyboard,
  );
}

/// Draws a [Glyph] styled by the ambient [IconTheme], like [Icon].
class DemoIcon extends StatelessWidget {
  const DemoIcon(this.glyph, {super.key});

  final Glyph glyph;

  /// Halfway between coil's rest (400) and emphasis (533) weights.
  static const _emphasisFrom = 466.0;

  @override
  Widget build(BuildContext context) {
    final weight = IconTheme.of(context).weight ?? 400;
    return Icon(weight >= _emphasisFrom ? glyph.emphasis : glyph.rest);
  }
}
