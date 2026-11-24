import 'package:flutter/foundation.dart';
import 'package:merging_dots/src/animation/dot_sequence.dart';
import 'package:merging_dots/src/character/dot_idle.dart';
import 'package:merging_dots/src/model/dot_scene.dart';
import 'package:merging_dots/src/rendering/dot_styles.dart';
import 'package:motor/motor.dart';

/// One state of a [DotCharacter]: what it plays while it is in that state.
@immutable
class CharacterState {
  /// A state that plays [animation].
  ///
  /// When [animation] doesn't loop, the character moves on to [next] once
  /// it is over, or rests on its last frame.
  ///
  /// [idles] play on top of it the whole time, like breathing and
  /// blinking, so a character doesn't freeze while it waits.
  const CharacterState(this.animation, {this.idles = const [], this.next});

  /// A state that rests on [pose], moving into it with [motion].
  CharacterState.pose(
    DotScene pose, {
    Motion motion = const CupertinoMotion.smooth(),
    Duration hold = Duration.zero,
    this.idles = const [],
    this.next,
  }) : animation = DotSequence(
         [DotKeyframe(pose, hold: hold)],
         motion: motion,
         loop: LoopMode.none,
       );

  /// What the character plays in this state.
  final DotSequence<DotScene> animation;

  /// What plays on top of [animation].
  final List<DotIdle> idles;

  /// The state to move on to when [animation] is over, if it doesn't loop.
  final String? next;

  @override
  bool operator ==(Object other) =>
      other is CharacterState &&
      other.animation == animation &&
      listEquals(other.idles, idles) &&
      other.next == next;

  @override
  int get hashCode => Object.hash(animation, Object.hashAll(idles), next);
}

/// How a [DotCharacter] gets from one state to another.
///
/// Without a transition, the character springs straight into the next
/// state's animation. A transition first passes through [via], for example
/// letting three dots melt into a blob before eyes open in it.
@immutable
class CharacterTransition {
  /// A transition from [from] to [to] through [via].
  ///
  /// Leave [from] or [to] null to match any state. Keyframes without a
  /// motion of their own use [motion].
  const CharacterTransition({
    required this.via,
    this.from,
    this.to,
    this.motion = const CupertinoMotion.smooth(),
  });

  /// The state this transition leaves, or null for any.
  final String? from;

  /// The state this transition leads to, or null for any.
  final String? to;

  /// The poses passed on the way.
  final List<DotKeyframe<DotScene>> via;

  /// The motion between the poses.
  final Motion motion;

  /// Whether this transition leads from [from] to [to].
  bool matches(String from, String to) =>
      (this.from == null || this.from == from) &&
      (this.to == null || this.to == to);

  /// How specific this transition is: the more states it names, the higher.
  int get specificity => (from == null ? 0 : 1) + (to == null ? 0 : 1);

  @override
  bool operator ==(Object other) =>
      other is CharacterTransition &&
      other.from == from &&
      other.to == to &&
      listEquals(other.via, via) &&
      other.motion == motion;

  @override
  int get hashCode => Object.hash(from, to, Object.hashAll(via), motion);
}

/// A character made of merging dots: named [states], [transitions] between
/// them, and how it is drawn.
///
/// Every pose of every state is a [DotScene] with the same layers and size,
/// and the same dot means the same thing in all of them, so any state can
/// animate into any other. A dot can be a body in one state and an eye in
/// the next by changing its layer.
///
/// Show one with `DotCharacterView`, and change its state by giving the
/// view a new state name.
@immutable
class DotCharacter {
  /// Creates a character that starts in [initial].
  const DotCharacter({
    required this.states,
    required this.initial,
    this.transitions = const [],
    this.style = const DotSceneStyle(),
  });

  /// The states, by name.
  final Map<String, CharacterState> states;

  /// The state the character starts in.
  final String initial;

  /// How the character gets from one state to another.
  final List<CharacterTransition> transitions;

  /// How the character's layers are drawn.
  final DotSceneStyle style;

  /// The state called [name]. Throws when there is none.
  CharacterState state(String name) {
    final state = states[name];
    if (state == null) {
      throw ArgumentError.value(
        name,
        'name',
        'Not a state of this character. Its states are '
            '${states.keys.join(', ')}',
      );
    }
    return state;
  }

  /// The most specific transition from [from] to [to], or null.
  CharacterTransition? transition(String from, String to) {
    CharacterTransition? best;
    for (final transition in transitions) {
      if (!transition.matches(from, to)) continue;
      if (best == null || transition.specificity > best.specificity) {
        best = transition;
      }
    }
    return best;
  }

  /// The first pose of the initial state.
  DotScene get firstPose => state(initial).animation.frames.first.state;

  @override
  bool operator ==(Object other) =>
      other is DotCharacter &&
      mapEquals(other.states, states) &&
      other.initial == initial &&
      listEquals(other.transitions, transitions) &&
      other.style == style;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(states.entries.map((e) => (e.key, e.value))),
    initial,
    Object.hashAll(transitions),
    style,
  );
}
