import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/shell/motor_shell.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/code_block.dart';
import 'package:motor_example/widgets/icons.dart';
import 'package:motor_example/widgets/motor_logo.dart';

/// The gallery's front page: what Motor is, four motions racing to follow
/// the pointer, and every demo by section.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final gap = CoilTheme.metricsOf(context).gap;
    final columns = MediaQuery.sizeOf(context).width >= 1000 ? 2 : 1;
    return GalleryPage(
      title: 'Overview',
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scales down rather than overflow in a very narrow window.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MotorLogo(size: 32),
                  const SizedBox(width: 12),
                  Text('Motor', style: text.display),
                  const SizedBox(width: 8),
                  const CoilBadge(child: Text('2.0')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'One motion system for Flutter. Springs, curves and '
              'choreography share one API, and anything you interrupt keeps '
              'its velocity.',
              style: text.muted.subtitle,
            ),
            SizedBox(height: gap * 2),
            const CodeBlock("flutter pub add 'motor:^2.0.0-dev.0'"),
          ],
        ),
        const _Race(),
        for (final group in ChapterGroup.values)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  group.title,
                  style: text.subtitle.copyWith(fontWeight: text.emphasis),
                ),
              ),
              const SizedBox(height: 12),
              CoilCardGroup(
                layout: CoilCardGroupLayout.divided,
                columns: columns,
                children: [
                  for (final chapter in chapters.where((c) => c.group == group))
                    CoilCard(
                      variant: CoilCardVariant.inline,
                      icon: GlyphIcon(chapter.glyph),
                      title: Text(chapter.title),
                      description: Text(chapter.idea),
                      onPressed: () => unawaited(
                        openChapter(AutoRouter.of(context), chapter),
                      ),
                    ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

/// The motions in the race, top to bottom.
const _racers = <(String, Motion)>[
  ('Smooth spring', .smoothSpring()),
  ('Snappy spring', .snappySpring()),
  ('Bouncy spring', .bouncySpring()),
  ('Ease-in-out curve', .curved(Duration(milliseconds: 500), Curves.easeInOut)),
];

/// Four dots follow the pointer, each on its own motion. Until someone
/// moves over it, the target swings between two points by itself.
class _Race extends StatefulWidget {
  const _Race();

  @override
  State<_Race> createState() => _RaceState();
}

class _RaceState extends State<_Race> {
  /// Where the dots head, from 0 (start) to 1 (end).
  var _target = .2;
  Timer? _swing;

  @override
  void initState() {
    super.initState();
    _swing = Timer.periodic(
      const Duration(milliseconds: 1800),
      (_) => setState(() => _target = _target < .5 ? .8 : .2),
    );
    // Start moving right away.
    scheduleMicrotask(() {
      if (mounted) setState(() => _target = .8);
    });
  }

  @override
  void dispose() {
    _swing?.cancel();
    super.dispose();
  }

  void _follow(double x, double width) {
    _swing?.cancel();
    _swing = null;
    setState(() => _target = (x / width).clamp(0, 1));
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final colors = CoilTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Follow the pointer',
            style: text.subtitle.copyWith(fontWeight: text.emphasis),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Move across the stage, or drag on a touch screen, and change '
          'direction before the dots arrive. The springs turn around '
          'smoothly; the curve starts over.',
          style: text.muted.caption,
        ),
        const SizedBox(height: 12),
        DemoStage(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const padding = 24.0;
              const dot = 16.0;
              final track = constraints.maxWidth - padding * 2;
              void follow(Offset local) => _follow(local.dx - padding, track);
              return MouseRegion(
                onHover: (event) => follow(event.localPosition),
                child: ExcludeScrollDrag(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanDown: (details) => follow(details.localPosition),
                    onPanUpdate: (details) => follow(details.localPosition),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          for (final (label, motion) in _racers)
                            SizedBox(
                              height: 48,
                              child: Stack(
                                children: [
                                  PositionedDirectional(
                                    start: padding,
                                    top: 4,
                                    child: Text(
                                      label,
                                      style: text.muted.caption,
                                    ),
                                  ),
                                  Positioned(
                                    left: padding,
                                    right: padding,
                                    bottom: 12 + dot / 2,
                                    child: Container(
                                      height: 1,
                                      color: colors.border,
                                    ),
                                  ),
                                  SingleMotionBuilder(
                                    value: _target * (track - dot),
                                    motion: motion,
                                    debugLabel: label,
                                    builder: (context, x, child) => Positioned(
                                      left: padding + x,
                                      bottom: 12,
                                      child: child!,
                                    ),
                                    child: Container(
                                      width: dot,
                                      height: dot,
                                      decoration: ShapeDecoration(
                                        color: label.endsWith('curve')
                                            ? colors.mutedForeground
                                            : colors.foreground,
                                        shape: const CircleBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        const CodeBlock(
          'SingleMotionBuilder(\n'
          '  value: pointer.dx,\n'
          '  motion: .bouncySpring(),\n'
          '  builder: (context, x, child) => Positioned(left: x, child: child!),\n'
          '  child: dot,\n'
          ')',
        ),
      ],
    );
  }
}
