import 'package:coil/foundation.dart';
import 'package:coil/src/components/reveal/reveal.dart' show CoilRevealTrack;
import 'package:motor/motor.dart';

/// Overrides for how a `CoilReveal` moves. A reveal paints nothing of its
/// own, so its style carries only [motions], and it has no `fallback`: an
/// unset motion comes from the tokens. Set a style app-wide or for a
/// subtree with `CoilThemeData.withComponentStyle`, or per instance with
/// `style:`.
class CoilRevealStyle extends CoilComponentStyle<CoilRevealStyle> {
  /// Creates a style.
  const CoilRevealStyle({this.motions});

  /// Springs for the reveal's animated parts, keyed by [CoilRevealTrack]s:
  /// `{CoilRevealTrack.presence: const Motion.smoothSpring()}`. A reveal's
  /// own `motions:` win over these; these win over the motion tokens.
  /// [merge] combines the maps key by key.
  final Map<CoilRevealTrack<Object>, Motion>? motions;

  @override
  CoilRevealStyle merge(CoilRevealStyle? other) => other == null
      ? this
      : CoilRevealStyle(
          motions: other.motions == null
              ? motions
              : {...?motions, ...?other.motions},
        );

  @override
  List<Object?> get props => [motions];
}
