import 'package:flutter/widgets.dart';

/// Fades a word with its presence and, when [rise] is on, moves it up: an
/// entering word rises from 80 % of its height below, a leaving one rises
/// 80 % above.
class ThinkingRoll extends StatelessWidget {
  /// Creates a vertical roll/fade transition driven by [presence].
  const ThinkingRoll({
    required this.presence,
    required this.rise,
    required this.child,
    super.key,
  });

  /// Animation driving presence (0 = absent, 1 = present).
  final Animation<double> presence;

  /// Whether to translate vertically in addition to fading.
  final bool rise;

  /// The transitioning child.
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: presence,
    child: child,
    builder: (context, child) {
      final p = presence.value;
      final leaving = presence.status == AnimationStatus.reverse;
      return ExcludeSemantics(
        excluding: leaving,
        child: FractionalTranslation(
          translation: Offset(
            0,
            rise ? (1 - p) * 0.8 * (leaving ? -1 : 1) : 0,
          ),
          // An entering word names the live region from its first frame,
          // while it's still transparent.
          child: Opacity(
            opacity: p.clamp(0, 1),
            alwaysIncludeSemantics: true,
            child: child,
          ),
        ),
      );
    },
  );
}
