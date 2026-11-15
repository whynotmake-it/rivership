import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/type_roles.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

const motionEntry = CatalogEntry(
  slug: 'motion',
  title: 'Motion',
  group: CatalogGroup.foundations,
  summary: 'Trigger and compare quick, standard, gentle and fade.',
  page: MotionPage.new,
);

/// One motion token pair and how a lane shows it.
enum _Lane {
  quick('quick', 'Hover glide, press collapse, focus ring travel'),
  standard('standard', 'Tab pill, switch thumb, merge/split, popovers'),
  gentle('gentle', 'Sheets, dialogs, large surfaces. The only bounce'),
  fade('fade', 'Opacity and color. Kept under reduced motion');

  const _Lane(this.label, this.use);

  final String label;
  final String use;

  (Motion enter, Motion exit) of(CoilMotion m) => switch (this) {
    quick => (m.quick, m.quickExit),
    standard => (m.standard, m.standardExit),
    gentle => (m.gentle, m.gentleExit),
    fade => (m.fade, m.fadeExit),
  };
}

class MotionPage extends StatefulWidget {
  const MotionPage({super.key});

  @override
  State<MotionPage> createState() => _MotionPageState();
}

class _MotionPageState extends State<MotionPage> {
  var _atEnd = false;

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return CatalogPage(
      title: 'Motion',
      summary:
          'Every token is a spring, exits included. Play runs the enter '
          'springs, play again runs the exits. Tap mid-flight to see a '
          'spring reverse with its velocity instead of restarting.',
      children: [
        DemoSection(
          title: 'Tokens side by side',
          description: reduced
              ? 'Reduced motion is on: spatial tokens are instant, fade stays.'
              : 'Slow motion in the settings stretches all of them 5×.',
          child: DemoColumn(
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: CoilButton(
                  leading: const CatalogIcon(Glyph.play),
                  onPressed: () => setState(() => _atEnd = !_atEnd),
                  child: Text(_atEnd ? 'Play exit' : 'Play enter'),
                ),
              ),
              for (final lane in _Lane.values)
                _LaneView(lane: lane, motion: motion, atEnd: _atEnd),
            ],
          ),
        ),
        DemoSection(
          title: 'Holds',
          description: 'Durations next to the springs.',
          child: DemoColumn(
            spacing: 8,
            children: [
              _Hold(
                'minPressDuration',
                motion.minPressDuration,
                'A quick tap still shows its press.',
              ),
              _Hold(
                'acknowledgeDuration',
                motion.acknowledgeDuration,
                'A picked row stays visible before the list closes.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LaneView extends StatelessWidget {
  const _LaneView({
    required this.lane,
    required this.motion,
    required this.atEnd,
  });

  final _Lane lane;
  final CoilMotion motion;
  final bool atEnd;

  static String describe(Motion m) => switch (m) {
    CupertinoMotion(:final duration, :final bounce) =>
      '${duration.inMilliseconds} ms'
          '${bounce == 0 ? '' : ', bounce $bounce'}',
    _ when m == const Motion.instant() => 'instant',
    _ => m.runtimeType.toString(),
  };

  @override
  Widget build(BuildContext context) {
    final (enter, exit) = lane.of(motion);
    final colors = CoilTheme.of(context).colors;
    final dot = MediaQuery.textScalerOf(context).scale(20);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: lane.label,
                style: TypeRole.body.styleOf(
                  context,
                  weight: CoilWeight.semibold,
                ),
              ),
              TextSpan(
                text: '  ${describe(enter)} · exit ${describe(exit)}',
                style: TypeRole.caption
                    .styleOf(context, color: colors.mutedForeground)
                    .copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
        ),
        RoleText(lane.use, role: TypeRole.caption, muted: true),
        const SizedBox(height: 6),
        SizedBox(
          height: dot + 8,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: colors.muted,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular((dot + 8) / 2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: SingleMotionBuilder(
                value: atEnd ? 1 : 0,
                motion: atEnd ? enter : exit,
                debugLabel: 'MotionPage.${lane.label}',
                builder: (context, t, child) => lane == _Lane.fade
                    ? Center(
                        child: Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: child,
                        ),
                      )
                    : Align(
                        alignment: AlignmentDirectional(-1 + 2 * t, 0),
                        child: child,
                      ),
                child: SizedBox.square(
                  dimension: dot,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.foreground,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(dot / 2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Hold extends StatelessWidget {
  const _Hold(this.name, this.duration, this.use);

  final String name;
  final Duration duration;
  final String use;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$name  ${duration.inMilliseconds} ms\n',
          style: TypeRole.body.styleOf(context, weight: CoilWeight.semibold),
        ),
        TextSpan(
          text: use,
          style: TypeRole.caption.styleOf(
            context,
            color: CoilTheme.of(context).colors.mutedForeground,
          ),
        ),
      ],
    ),
  );
}
