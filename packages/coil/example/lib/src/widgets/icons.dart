import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:lucide_icons_flutter/lucide_icons_400.dart';
import 'package:motor/motor.dart';

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
  static const type = Glyph(LucideIcons300.type, LucideIcons400.type);
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
  static const shuffle = Glyph(LucideIcons300.shuffle, LucideIcons400.shuffle);
  static const sort = Glyph(
    LucideIcons300.arrowDown01,
    LucideIcons400.arrowDown01,
  );
  static const grip = Glyph(
    LucideIcons300.gripVertical,
    LucideIcons400.gripVertical,
  );
  static const cornerDownRight = Glyph(
    LucideIcons300.cornerDownRightDir,
    LucideIcons400.cornerDownRightDir,
  );
  static const smartphone = Glyph(
    LucideIcons300.smartphone,
    LucideIcons400.smartphone,
  );
  static const tablet = Glyph(LucideIcons300.tablet, LucideIcons400.tablet);
  static const rotate = Glyph(
    LucideIcons300.rotateCcw,
    LucideIcons400.rotateCcw,
  );
  static const grid = Glyph(
    LucideIcons300.layoutGrid,
    LucideIcons400.layoutGrid,
  );
  static const component = Glyph(
    LucideIcons300.component,
    LucideIcons400.component,
  );
  static const arrowUpRight = Glyph(
    LucideIcons300.arrowUpRight,
    LucideIcons400.arrowUpRight,
  );
  static const keyboard = Glyph(
    LucideIcons300.keyboard,
    LucideIcons400.keyboard,
  );
  static const star = Glyph(LucideIcons300.star, LucideIcons400.star);
  static const paperclip = Glyph(
    LucideIcons300.paperclip,
    LucideIcons400.paperclip,
  );
  static const arrowUp = Glyph(LucideIcons300.arrowUp, LucideIcons400.arrowUp);
  static const mic = Glyph(LucideIcons300.mic, LucideIcons400.mic);
  static const image = Glyph(LucideIcons300.image, LucideIcons400.image);
  static const filter = Glyph(LucideIcons300.filter, LucideIcons400.filter);
  static const check = Glyph(LucideIcons300.check, LucideIcons400.check);
  static const zap = Glyph(LucideIcons300.zap, LucideIcons400.zap);
  static const bookmark = Glyph(
    LucideIcons300.bookmark,
    LucideIcons400.bookmark,
  );
  static const pointer = Glyph(
    LucideIcons300.mousePointer2,
    LucideIcons400.mousePointer2,
  );
  static const pause = Glyph(LucideIcons300.pause, LucideIcons400.pause);
  static const skipBack = Glyph(
    LucideIcons300.skipBack,
    LucideIcons400.skipBack,
  );
  static const skipForward = Glyph(
    LucideIcons300.skipForward,
    LucideIcons400.skipForward,
  );
  static const listMusic = Glyph(
    LucideIcons300.listMusic,
    LucideIcons400.listMusic,
  );
  static const archive = Glyph(
    LucideIcons300.archive,
    LucideIcons400.archive,
  );
  static const clock = Glyph(LucideIcons300.clock, LucideIcons400.clock);
  static const truck = Glyph(LucideIcons300.truck, LucideIcons400.truck);
  static const creditCard = Glyph(
    LucideIcons300.creditCard,
    LucideIcons400.creditCard,
  );
  static const tag = Glyph(LucideIcons300.tag, LucideIcons400.tag);
  static const info = Glyph(LucideIcons300.info, LucideIcons400.info);
  static const circleCheck = Glyph(
    LucideIcons300.circleCheck,
    LucideIcons400.circleCheck,
  );
  static const triangleAlert = Glyph(
    LucideIcons300.triangleAlert,
    LucideIcons400.triangleAlert,
  );
  static const circleAlert = Glyph(
    LucideIcons300.circleAlert,
    LucideIcons400.circleAlert,
  );
  static const refresh = Glyph(
    LucideIcons300.refreshCw,
    LucideIcons400.refreshCw,
  );
  static const fileText = Glyph(
    LucideIcons300.fileText,
    LucideIcons400.fileText,
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

/// Lucide's heart, drawn rather than set from the font so it can fill:
/// the outline at rest, and a fill that springs in from the center when
/// [filled] turns on (and leaves the same way), with a small lift of the
/// whole glyph on the way. It follows [IconTheme] for size, color and
/// stroke weight like [CatalogIcon].
class HeartGlyph extends StatelessWidget {
  const HeartGlyph({required this.filled, super.key, this.semanticLabel});

  final bool filled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    final size = icon.size ?? 16;
    final color = icon.color ?? const Color(0xFF000000);
    final emphasis = (icon.weight ?? 400) > 450;
    final motion = CoilTheme.motionOf(context);
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel == null,
      child: SizedBox.square(
        dimension: size,
        child: SingleMotionBuilder(
          value: filled ? 1 : 0,
          motion: filled ? motion.gentle : motion.standardExit,
          debugLabel: 'HeartGlyph',
          builder: (context, t, _) => CustomPaint(
            painter: _HeartPainter(
              fill: t.clamp(0, 1.2),
              color: color,
              stroke: emphasis ? 2 : 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeartPainter extends CustomPainter {
  const _HeartPainter({
    required this.fill,
    required this.color,
    required this.stroke,
  });

  /// 0 empty to 1 full; the spring may overshoot a little.
  final double fill;
  final Color color;

  /// In Lucide's 24-unit grid.
  final double stroke;

  // Lucide's heart, in its 24-unit grid.
  static final _heart = Path()
    ..moveTo(19, 14)
    ..relativeCubicTo(1.49, -1.46, 3, -3.21, 3, -5.5)
    ..arcToPoint(
      const Offset(16.5, 3),
      radius: const Radius.circular(5.5),
      clockwise: false,
    )
    ..relativeCubicTo(-1.76, 0, -3, 0.5, -4.5, 2)
    ..relativeCubicTo(-1.5, -1.5, -2.74, -2, -4.5, -2)
    ..arcToPoint(
      const Offset(2, 8.5),
      radius: const Radius.circular(5.5),
      clockwise: false,
    )
    ..relativeCubicTo(0, 2.3, 1.5, 4.05, 3, 5.5)
    ..relativeLineTo(7, 7)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 24;
    // A lift that peaks half-way through filling and settles at 1.
    final lift = 1 + 0.16 * math.sin(math.pi * fill.clamp(0, 1));
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(unit * lift)
      ..translate(-12, -12);
    if (fill > 0) {
      canvas
        ..save()
        ..translate(12, 12)
        ..scale(fill)
        ..translate(-12, -12)
        ..drawPath(
          _heart,
          Paint()..color = color.withValues(alpha: color.a * fill.clamp(0, 1)),
        )
        ..restore();
    }
    canvas
      ..drawPath(
        _heart,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_HeartPainter old) =>
      old.fill != fill || old.color != color || old.stroke != stroke;
}
