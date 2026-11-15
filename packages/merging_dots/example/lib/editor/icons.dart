import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:lucide_icons_flutter/lucide_icons_400.dart';

/// A Lucide glyph in two stroke weights: lighter at rest, heavier when a
/// coil control emphasizes its icon (coil raises `IconTheme.weight`).
class Glyph {
  const Glyph(this.rest, this.emphasis);

  final IconData rest;
  final IconData emphasis;

  static const flip = Glyph(
    LucideIcons300.mousePointerClick,
    LucideIcons400.mousePointerClick,
  );
  static const draw = Glyph(LucideIcons300.pencil, LucideIcons400.pencil);
  static const erase = Glyph(LucideIcons300.eraser, LucideIcons400.eraser);
  static const add = Glyph(
    LucideIcons300.circlePlus,
    LucideIcons400.circlePlus,
  );
  static const move = Glyph(LucideIcons300.move, LucideIcons400.move);
  static const symmetry = Glyph(
    LucideIcons300.flipHorizontal2,
    LucideIcons400.flipHorizontal2,
  );
  static const undo = Glyph(LucideIcons300.undo2, LucideIcons400.undo2);
  static const redo = Glyph(LucideIcons300.redo2, LucideIcons400.redo2);
  static const minus = Glyph(LucideIcons300.minus, LucideIcons400.minus);
  static const plus = Glyph(LucideIcons300.plus, LucideIcons400.plus);
  static const invert = Glyph(LucideIcons300.contrast, LucideIcons400.contrast);
  static const clear = Glyph(LucideIcons300.trash2, LucideIcons400.trash2);
  static const play = Glyph(LucideIcons300.play, LucideIcons400.play);
  static const pause = Glyph(LucideIcons300.pause, LucideIcons400.pause);
  static const library = Glyph(
    LucideIcons300.layoutGrid,
    LucideIcons400.layoutGrid,
  );
  static const export = Glyph(LucideIcons300.download, LucideIcons400.download);
  static const import = Glyph(LucideIcons300.upload, LucideIcons400.upload);
  static const save = Glyph(LucideIcons300.save, LucideIcons400.save);
  static const copy = Glyph(LucideIcons300.copy, LucideIcons400.copy);
  static const check = Glyph(LucideIcons300.check, LucideIcons400.check);
  static const duplicate = Glyph(
    LucideIcons300.squareDashed,
    LucideIcons400.squareDashed,
  );
  static const close = Glyph(LucideIcons300.x, LucideIcons400.x);
  static const gauge = Glyph(LucideIcons300.gauge, LucideIcons400.gauge);
  static const loaders = Glyph(
    LucideIcons300.loaderCircle,
    LucideIcons400.loaderCircle,
  );
  static const left = Glyph(
    LucideIcons300.chevronLeft,
    LucideIcons400.chevronLeft,
  );
  static const right = Glyph(
    LucideIcons300.chevronRight,
    LucideIcons400.chevronRight,
  );
}

/// Shows a [Glyph] in the stroke weight coil asks for.
class GlyphIcon extends StatelessWidget {
  const GlyphIcon(this.glyph, {super.key});

  final Glyph glyph;

  @override
  Widget build(BuildContext context) {
    final weight = IconTheme.of(context).weight ?? 400;
    return Icon(weight >= 466 ? glyph.emphasis : glyph.rest);
  }
}
