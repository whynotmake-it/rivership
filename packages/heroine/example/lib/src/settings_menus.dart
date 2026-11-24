import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:heroine/heroine.dart';
import 'package:heroine_example/src/icons.dart';

/// The springs the photo grid and its detail page can fly with.
enum DemoSpring {
  bouncy('Bouncy', CupertinoMotion.bouncy()),
  snappy('Snappy', CupertinoMotion.snappy()),
  smooth('Smooth', CupertinoMotion.smooth());

  const DemoSpring(this.label, this.motion);

  final String label;
  final Motion motion;
}

/// How a photo changes between its tile and its card.
enum DemoShuttle {
  flip('Flip'),
  fade('Fade'),
  fadeThrough('Fade through'),
  flipAndFade('Flip and fade'),
  destinationOnly('Destination only');

  const DemoShuttle(this.label);

  final String label;

  /// The shuttle builder for this choice. The fade-through color is the
  /// page's background, so photos dip into the page.
  HeroineShuttleBuilder build(BuildContext context) {
    final fadeColor = CoilTheme.of(context).colors.background;
    return switch (this) {
      flip => const FlipShuttleBuilder(),
      fade => const FadeShuttleBuilder(),
      fadeThrough => FadeThroughShuttleBuilder(fadeColor: fadeColor),
      flipAndFade => ChainedShuttleBuilder(
        builders: [
          const FlipShuttleBuilder(),
          FadeThroughShuttleBuilder(fadeColor: fadeColor),
          const FadeShuttleBuilder(),
        ],
      ),
      destinationOnly => const SingleShuttleBuilder(),
    };
  }
}

/// The spring and shuttle the photo grid uses, shared with its detail page.
final demoSpring = ValueNotifier(DemoSpring.bouncy);
final demoShuttle = ValueNotifier(DemoShuttle.flip);

/// A ghost settings button that opens the spring and shuttle choices.
class TransitionSettingsButton extends StatelessWidget {
  const TransitionSettingsButton({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([demoSpring, demoShuttle]),
    builder: (context, _) => CoilDropdown(
      entries: [
        const CoilMenuLabel(Text('Spring')),
        for (final option in DemoSpring.values)
          CoilAction(
            label: Text(option.label),
            mark: CoilActionMark.radio,
            selected: demoSpring.value == option,
            onPressed: () => demoSpring.value = option,
          ),
        const CoilMenuSeparator(),
        const CoilMenuLabel(Text('Shuttle')),
        for (final option in DemoShuttle.values)
          CoilAction(
            label: Text(option.label),
            mark: CoilActionMark.radio,
            selected: demoShuttle.value == option,
            onPressed: () => demoShuttle.value = option,
          ),
      ],
      builder: (context, menu) => CoilButton.icon(
        variant: CoilButtonVariant.ghost,
        selected: menu.isOpen,
        onPressed: menu.open,
        icon: const DemoIcon(Glyph.settings),
        semanticLabel: 'Transition settings',
      ),
    ),
  );
}
