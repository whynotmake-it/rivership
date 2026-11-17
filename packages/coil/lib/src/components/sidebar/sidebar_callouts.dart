import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/sidebar/sidebar_scaffold.dart';
import 'package:coil/src/components/sidebar/sidebar_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// When a [CoilSidebarCalloutStack] fans its pile out.
enum CoilSidebarCalloutExpand {
  /// While a mouse rests on the pile or focus is inside it (Tab, or a
  /// field being typed in), and on touch after a tap on the pile until a
  /// tap outside it. For short inline cards.
  onHover,

  /// Never; only the front card shows in full. For tall banners, which
  /// fanned out would fill the sidebar.
  never,
}

/// A pile of callouts for the sidebar's footer, such as news and offers.
///
/// [children] are cards, usually dismissible `CoilCard`s, front first, each
/// with its own key. A [CoilCardStack] lays them out: at rest the front
/// card shows with up to two more peeking evenly behind it, each a step
/// smaller, whatever their heights. [expand] decides whether the pile fans
/// out into a list, the cards spaced by the theme's gap: under a hovering
/// mouse or focus inside, or on touch after a tap on the pile, until a tap
/// outside it. Fanned out, every card takes taps, hovers, text and focus;
/// folded, only the front card does, and a tap on a card peeking behind it
/// fans the pile out. A dismissed card fades while the next one moves
/// forward; remove it from [children] in its `onDismissed`.
class CoilSidebarCalloutStack extends StatelessWidget {
  /// Creates a callout stack.
  const CoilSidebarCalloutStack({
    required this.children,
    super.key,
    this.expand = CoilSidebarCalloutExpand.onHover,
    this.motion,
    this.motions,
  });

  /// The cards, front first. Each needs a key.
  final List<Widget> children;

  /// When the pile fans out.
  final CoilSidebarCalloutExpand expand;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions for this instance, keyed by [CoilSidebarTrack]s.
  /// They win over the theme's [CoilSidebarStyle.motions] and the tokens.
  final Map<CoilSidebarTrack<Object>, Motion>? motions;

  /// How far each card behind the front one peeks out, at rest.
  static const peek = CoilCardStack.defaultPeek;

  /// How many cards peek behind the front one.
  static const maxPeeking = CoilCardStack.defaultMaxPeeks;

  /// How much smaller each peeking card is.
  static const scaleStep = CoilCardStack.defaultPeekScale;

  @override
  Widget build(BuildContext context) {
    final tokens = CoilTheme.motionOf(context, override: motion);
    // No `style:` of its own: the theme's sidebar style is the styled one.
    Motion motionFor(Motion token) => CoilTheme.trackMotionOf(
      context,
      CoilSidebarTrack.callouts,
      instance: motions,
      styled: CoilTheme.styleOf<CoilSidebarStyle>(context)?.motions,
      token: token,
    );
    return CoilCardStack(
      expand: switch (expand) {
        CoilSidebarCalloutExpand.onHover => CoilCardStackExpand.auto,
        CoilSidebarCalloutExpand.never => CoilCardStackExpand.never,
      },
      expandMotion: motionFor(tokens.standard),
      foldMotion: motionFor(tokens.standardExit),
      slotMotion: motionFor(tokens.standard),
      leaveMotion: motionFor(tokens.standard),
      items: [
        for (final (i, card) in children.indexed)
          CoilCardStackItem(key: card.key ?? ValueKey(i), child: card),
      ],
    );
  }
}
