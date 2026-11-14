import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:lucide_icons_flutter/lucide_icons_400.dart';

/// A Lucide glyph in two stroke weights: 1.5 at rest, 2 when a control
/// emphasizes its icon (coil raises `IconTheme.weight` from 400 to 533).
///
/// Lucide ships one font per stroke weight instead of a variable font, so
/// [CatalogIcon] picks the font from the ambient weight. Both are constant
/// [IconData]s, so release builds can still tree-shake the fonts.
class Glyph {
  const Glyph(this.rest, this.emphasis);

  final IconData rest;
  final IconData emphasis;

  static const back = Glyph(
    LucideIcons300.chevronLeftDir,
    LucideIcons400.chevronLeftDir,
  );
  static const forward = Glyph(
    LucideIcons300.chevronRightDir,
    LucideIcons400.chevronRightDir,
  );
  static const settings = Glyph(
    LucideIcons300.settings2,
    LucideIcons400.settings2,
  );
  static const plus = Glyph(LucideIcons300.plus, LucideIcons400.plus);
  static const trash = Glyph(LucideIcons300.trash2, LucideIcons400.trash2);
  static const download = Glyph(
    LucideIcons300.download,
    LucideIcons400.download,
  );
  static const arrowRight = Glyph(
    LucideIcons300.arrowRightDir,
    LucideIcons400.arrowRightDir,
  );
  static const search = Glyph(LucideIcons300.search, LucideIcons400.search);
  static const mail = Glyph(LucideIcons300.mail, LucideIcons400.mail);
  static const lock = Glyph(LucideIcons300.lock, LucideIcons400.lock);
  static const globe = Glyph(LucideIcons300.globe, LucideIcons400.globe);
  static const at = Glyph(LucideIcons300.atSign, LucideIcons400.atSign);
  static const user = Glyph(LucideIcons300.user, LucideIcons400.user);
  static const bold = Glyph(LucideIcons300.bold, LucideIcons400.bold);
  static const italic = Glyph(LucideIcons300.italic, LucideIcons400.italic);
  static const underline = Glyph(
    LucideIcons300.underline,
    LucideIcons400.underline,
  );
  static const strikethrough = Glyph(
    LucideIcons300.strikethrough,
    LucideIcons400.strikethrough,
  );
  static const home = Glyph(LucideIcons300.house, LucideIcons400.house);
  static const inbox = Glyph(LucideIcons300.inbox, LucideIcons400.inbox);
  static const calendar = Glyph(
    LucideIcons300.calendar,
    LucideIcons400.calendar,
  );
  static const chart = Glyph(
    LucideIcons300.chartLine,
    LucideIcons400.chartLine,
  );
  static const heart = Glyph(LucideIcons300.heart, LucideIcons400.heart);
  static const send = Glyph(LucideIcons300.send, LucideIcons400.send);
  static const sun = Glyph(LucideIcons300.sun, LucideIcons400.sun);
  static const moon = Glyph(LucideIcons300.moon, LucideIcons400.moon);
  static const monitor = Glyph(LucideIcons300.monitor, LucideIcons400.monitor);
  static const key = Glyph(LucideIcons300.keyRound, LucideIcons400.keyRound);
  static const play = Glyph(LucideIcons300.play, LucideIcons400.play);
  static const copy = Glyph(LucideIcons300.copy, LucideIcons400.copy);
  static const panelLeft = Glyph(
    LucideIcons300.panelLeft,
    LucideIcons400.panelLeft,
  );
  static const panelRight = Glyph(
    LucideIcons300.panelRight,
    LucideIcons400.panelRight,
  );
  static const brain = Glyph(LucideIcons300.brain, LucideIcons400.brain);
  static const bot = Glyph(LucideIcons300.bot, LucideIcons400.bot);
  static const book = Glyph(LucideIcons300.bookOpen, LucideIcons400.bookOpen);
  static const flask = Glyph(
    LucideIcons300.flaskConical,
    LucideIcons400.flaskConical,
  );
  static const folder = Glyph(LucideIcons300.folder, LucideIcons400.folder);
  static const message = Glyph(
    LucideIcons300.messageSquare,
    LucideIcons400.messageSquare,
  );
  static const pencil = Glyph(LucideIcons300.pencil, LucideIcons400.pencil);
  static const more = Glyph(
    LucideIcons300.ellipsisVertical,
    LucideIcons400.ellipsisVertical,
  );
  static const sliders = Glyph(
    LucideIcons300.slidersHorizontal,
    LucideIcons400.slidersHorizontal,
  );
  static const bell = Glyph(LucideIcons300.bell, LucideIcons400.bell);
  static const palette = Glyph(LucideIcons300.palette, LucideIcons400.palette);
  static const shield = Glyph(LucideIcons300.shield, LucideIcons400.shield);
  static const users = Glyph(LucideIcons300.users, LucideIcons400.users);
  static const chevronsUpDown = Glyph(
    LucideIcons300.chevronsUpDown,
    LucideIcons400.chevronsUpDown,
  );
  static const lightbulb = Glyph(
    LucideIcons300.lightbulb,
    LucideIcons400.lightbulb,
  );
  static const branch = Glyph(
    LucideIcons300.gitBranch,
    LucideIcons400.gitBranch,
  );
  static const link = Glyph(LucideIcons300.link, LucideIcons400.link);
  static const sparkles = Glyph(
    LucideIcons300.sparkles,
    LucideIcons400.sparkles,
  );
  static const logOut = Glyph(LucideIcons300.logOut, LucideIcons400.logOut);
  static const newThread = Glyph(
    LucideIcons300.squarePen,
    LucideIcons400.squarePen,
  );
  static const workflow = Glyph(
    LucideIcons300.workflow,
    LucideIcons400.workflow,
  );
  static const cornerDownRight = Glyph(
    LucideIcons300.cornerDownRightDir,
    LucideIcons400.cornerDownRightDir,
  );
}

/// Draws a [Glyph] styled by the ambient [IconTheme], like [Icon].
class CatalogIcon extends StatelessWidget {
  const CatalogIcon(this.glyph, {super.key, this.semanticLabel});

  final Glyph glyph;
  final String? semanticLabel;

  /// Halfway between coil's rest (400) and emphasis (533) weights.
  static const _emphasisFrom = 466.0;

  @override
  Widget build(BuildContext context) {
    final weight = IconTheme.of(context).weight ?? 400;
    return Icon(
      weight >= _emphasisFrom ? glyph.emphasis : glyph.rest,
      semanticLabel: semanticLabel,
    );
  }
}
