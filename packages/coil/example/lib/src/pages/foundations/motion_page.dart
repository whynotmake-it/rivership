import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/shell/catalog_shell.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/reference.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

const motionEntry = CatalogEntry(
  slug: 'motion',
  title: 'Motion',
  group: CatalogGroup.foundations,
  summary:
      'Compare the quick, standard, gentle and fade springs, and the '
      'frame rates they tick at.',
  page: MotionPage.new,
);

/// Overriding the motion tokens on a theme.
const _tokenSnippet = '''
CoilThemeData(
  motion: CoilMotion(
    standard: CupertinoMotion(
      duration: Duration(milliseconds: 180),
    ),
  ),
)''';

/// Pinning a subtree's springs to a fixed frame rate.
const _rateSnippet = '''
TickerRateScope(
  rate: TickerRate.fps(30),
  child: const ActivityFeed(),
)''';

/// One motion token pair and how a lane shows it.
enum _Lane {
  quick('quick', 'The hover highlight, a press and the focus ring'),
  standard('standard', 'Tab pills, switch thumbs, merging rows and popovers'),
  gentle('gentle', 'Sheets, dialogs and large surfaces'),
  fade('fade', 'Opacity and color, kept under reduced motion');

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
  var _ratesAtEnd = false;

  static final _rates = <(String, TickerRate)>[
    ('Display rate', const TickerRate.vsync()),
    ('60 fps', TickerRate.fps(60)),
    ('30 fps', TickerRate.fps(30)),
    ('15 fps', TickerRate.fps(15)),
  ];

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return CatalogPage(
      title: 'Motion',
      summary:
          'Every token is a spring, including its exit. Press play to run the '
          'enter springs, and press again for the exits. Tapping mid-flight '
          'reverses from the current velocity instead of restarting.',
      usage: _tokenSnippet,
      notes: const [
        CatalogNote(
          'Motor',
          "Coil's motion runs on Motor 2.0, so each token is a Motor "
              'CupertinoMotion you can reuse directly.',
        ),
        CatalogNote(
          'Motion',
          "Coil's springs follow the nearest TickerRateScope, so a fixed rate "
              'reduces per-frame work for low-priority motion. Use the '
              'frame-rate option in preview settings to test it.',
        ),
        CatalogNote(
          'Accessibility',
          'Reduced motion makes spatial tokens instant while keeping fades. '
              'Slow motion in preview settings runs them 5× slower.',
        ),
      ],
      children: [
        DemoSection(
          title: 'Tokens side by side',
          description: reduced
              ? 'Reduced motion is on, so spatial tokens are instant and '
                    'only the fade still plays.'
              : 'Slow motion in preview settings runs them 5× slower.',
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
          title: 'Frame rates',
          description:
              'The same spring ticked at four rates. A lower rate samples the '
              'spring less often and reduces per-frame work, while the motion '
              'takes the same total time.',
          child: DemoColumn(
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: CoilButton(
                  leading: const CatalogIcon(Glyph.play),
                  onPressed: () => setState(() => _ratesAtEnd = !_ratesAtEnd),
                  child: Text(_ratesAtEnd ? 'Play back' : 'Play'),
                ),
              ),
              for (final (label, rate) in _rates)
                _RateTrack(
                  label: label,
                  rate: rate,
                  motion: motion.gentle,
                  atEnd: _ratesAtEnd,
                ),
              const SizedBox(height: 4),
              const UsageSnippet(code: _rateSnippet),
              const _MotorExampleLink(),
            ],
          ),
        ),
        DemoSection(
          title: 'Holds',
          description:
              'The two timing tokens that hold a state for a moment, shown '
              'with their durations.',
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

/// A ghost button to the Motor example, shown only when the catalog runs
/// inside the aggregate app that can open it.
class _MotorExampleLink extends StatelessWidget {
  const _MotorExampleLink();

  @override
  Widget build(BuildContext context) {
    final open = CatalogHome.openPackageOf(context, 'motor');
    if (open == null) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: CoilButton(
        variant: CoilButtonVariant.ghost,
        trailing: const CatalogIcon(Glyph.arrowUpRight),
        onPressed: open,
        child: const Text('Open the Motor example'),
      ),
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
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: lane.label,
                style: text.body.copyWith(fontWeight: text.emphasis),
              ),
              TextSpan(
                text: '  ${describe(enter)} · exit ${describe(exit)}',
                style: text.muted.caption.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        Text(lane.use, style: text.muted.caption),
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
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$name  ${duration.inMilliseconds} ms\n',
            style: text.body.copyWith(fontWeight: text.emphasis),
          ),
          TextSpan(text: use, style: text.muted.caption),
        ],
      ),
    );
  }
}

/// One spring on its own track, ticked at [rate] by a [TickerRateScope].
class _RateTrack extends StatelessWidget {
  const _RateTrack({
    required this.label,
    required this.rate,
    required this.motion,
    required this.atEnd,
  });

  final String label;
  final TickerRate rate;
  final Motion motion;
  final bool atEnd;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final dot = MediaQuery.textScalerOf(context).scale(20);
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: text.body.copyWith(fontWeight: text.emphasis),
        ),
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
              child: TickerRateScope(
                rate: rate,
                child: SingleMotionBuilder(
                  value: atEnd ? 1 : 0,
                  motion: motion,
                  debugLabel: 'MotionPage.rate $label',
                  builder: (context, t, child) => Align(
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
        ),
      ],
    );
  }
}
