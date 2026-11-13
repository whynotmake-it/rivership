// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/chat_message/chat_message_action.dart';
import 'package:coil/src/components/chat_message/chat_message_body.dart';
import 'package:coil/src/components/chat_message/chat_message_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilChatMessage]. Use them as keys of
/// [CoilChatMessage.motions] or [CoilThemeData.trackMotions].
final class CoilChatMessageTrack<T extends Object> extends Track<T> {
  CoilChatMessageTrack._(super.converter, {required String super.debugLabel});

  /// The entrance opacity. Default motion: `fade`.
  static final opacity = CoilChatMessageTrack<double>._(
    .single,
    debugLabel: 'CoilChatMessage.opacity',
  );

  /// The entrance rise and scale. Default motion: `standard`.
  static final travel = CoilChatMessageTrack<double>._(
    .single,
    debugLabel: 'CoilChatMessage.travel',
  );

  /// The entrance height, which makes room in the transcript. Default
  /// motion: `standard`.
  static final height = CoilChatMessageTrack<double>._(
    .single,
    debugLabel: 'CoilChatMessage.height',
  );

  /// The meta row's opacity as it shows and hides. Default motion: `fade`
  /// in, `fadeExit` out; an override applies to both.
  static final meta = CoilChatMessageTrack<double>._(
    .single,
    debugLabel: 'CoilChatMessage.meta',
  );
}

/// The words a [CoilChatMessage] gives screen readers. The defaults are
/// English.
@immutable
class CoilChatMessageLabels {
  /// Creates the labels.
  const CoilChatMessageLabels({
    this.user = 'You',
    this.assistant = 'Assistant',
  });

  /// The sender name of a [CoilChatSender.user] message.
  final String user;

  /// The sender name of a [CoilChatSender.assistant] message.
  final String assistant;

  @override
  bool operator ==(Object other) =>
      other is CoilChatMessageLabels &&
      other.user == user &&
      other.assistant == assistant;

  @override
  int get hashCode => Object.hash(user, assistant);
}

/// Who wrote a [CoilChatMessage].
enum CoilChatSender {
  /// The person using the app: a bubble at the end edge.
  user,

  /// The assistant: plain text across the full width, at the start edge.
  assistant,
}

/// Whether a [CoilChatMessage] animates in when it first builds.
enum CoilChatMessageEntrance {
  /// Fades in, rises 8 px and grows from 0.96 out of the sender's bottom
  /// corner. Its height opens at the same time, so in a bottom-anchored
  /// (reversed) list the earlier messages slide up to make room.
  animated,

  /// Shows at once. Use it for messages that were already in the transcript
  /// when it opened, and for messages a lazy list builds again on scroll.
  none,
}

/// One message in a chat transcript.
///
/// A message stacks [attachments], the message text ([child]) and a meta
/// row with the [time] and [actions].
///
/// * **User** messages sit in a tinted bubble at the end edge, at most 80 %
///   of the available width.
/// * **Assistant** messages are plain text across the full width.
///
/// The meta row shows on hover or when an action has keyboard focus. It
/// always shows on the touch tier, because touch can't hover, and while a
/// screen reader runs. A long press with a finger opens [actions] as a menu.
///
/// Screen readers read each message as one container labeled with the
/// sender and the time.
class CoilChatMessage extends StatelessWidget {
  /// Creates a chat message.
  const CoilChatMessage({
    required this.sender,
    super.key,
    this.child,
    this.attachments = const [],
    this.time,
    this.actions = const [],
    this.entrance = CoilChatMessageEntrance.animated,
    this.semanticLabel,
    this.labels = const CoilChatMessageLabels(),
    this.size,
    this.motion,
    this.motions,
    this.style,
  });

  /// Who wrote the message.
  final CoilChatSender sender;

  /// The message body, usually a [Text]. It gets the subtitle text style
  /// and wraps. Null leaves only the attachments.
  final Widget? child;

  /// Widgets above the body, such as file thumbnails, 6 px apart and
  /// aligned to the sender's side.
  final List<Widget> attachments;

  /// When the message was sent, already formatted for the locale.
  final String? time;

  /// Actions in the meta row and the long-press menu.
  final List<CoilChatMessageAction> actions;

  /// Whether the message animates in when it first builds.
  final CoilChatMessageEntrance entrance;

  /// Replaces the container's label, which is the sender's name from
  /// [labels] and the [time].
  final String? semanticLabel;

  /// The sender names screen readers hear.
  final CoilChatMessageLabels labels;

  /// Pins the message to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens ([CoilThemeData.motion]) for this
  /// message.
  final CoilMotion? motion;

  /// Per-track motions for this message, keyed by [CoilChatMessageTrack]s.
  /// They win over the theme's [CoilThemeData.trackMotions] and [motion].
  final Map<CoilChatMessageTrack<Object>, Motion>? motions;

  /// Overrides for this message's look, on top of the theme's
  /// [CoilChatMessageStyle] and the defaults.
  final CoilChatMessageStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: size);
    final tokens = CoilTheme.motionOf(context, override: motion);
    Motion motionOf(CoilChatMessageTrack<Object> track, Motion token) =>
        CoilTheme.trackMotionOf(
          context,
          track,
          instance: motions,
          token: token,
          spatial:
              track != CoilChatMessageTrack.opacity &&
              track != CoilChatMessageTrack.meta,
        );
    final style = CoilChatMessageStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilChatMessageStyle>(context)).merge(this.style);
    final user = sender == CoilChatSender.user;
    final name = user ? labels.user : labels.assistant;

    Widget message = Align(
      alignment: user
          ? AlignmentDirectional.topEnd
          : AlignmentDirectional.topStart,
      heightFactor: 1,
      child: _MaxWidth(
        factor: user ? style.maxWidthFactor! : 1,
        child: ChatMessageBody(
          user: user,
          attachments: attachments,
          time: time,
          actions: actions,
          metrics: metrics,
          metaIn: motionOf(CoilChatMessageTrack.meta, tokens.fade),
          metaOut: motionOf(CoilChatMessageTrack.meta, tokens.fadeExit),
          style: style,
          child: child,
        ),
      ),
    );
    if (entrance == CoilChatMessageEntrance.animated) {
      message = CoilCollapsible(
        expanded: true,
        appear: true,
        heightMotion: motionOf(CoilChatMessageTrack.height, tokens.standard),
        opacityMotion: motionOf(CoilChatMessageTrack.opacity, tokens.fade),
        debugLabel: 'CoilChatMessage.enter',
        child: _Travel(
          motion: motionOf(CoilChatMessageTrack.travel, tokens.standard),
          origin: user
              ? AlignmentDirectional.bottomEnd
              : AlignmentDirectional.bottomStart,
          child: message,
        ),
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel ?? [name, ?time].join(', '),
      child: MotorInspectionScope(group: 'CoilChatMessage', child: message),
    );
  }
}

/// Caps [child] at [factor] of the incoming max width.
class _MaxWidth extends StatelessWidget {
  const _MaxWidth({required this.factor, required this.child});

  final double factor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (factor >= 1) return child;
    return LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: constraints.hasBoundedWidth
              ? constraints.maxWidth * factor
              : double.infinity,
        ),
        child: child,
      ),
    );
  }
}

/// The entrance rise and scale, out of the sender's bottom corner.
class _Travel extends StatelessWidget {
  const _Travel({
    required this.motion,
    required this.origin,
    required this.child,
  });

  final Motion motion;
  final AlignmentDirectional origin;
  final Widget child;

  static const _rise = 8.0;
  static const _scale = 0.96;

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    from: 0,
    value: 1,
    motion: motion,
    debugLabel: 'CoilChatMessage.travel',
    child: child,
    builder: (context, p, child) => Transform.translate(
      offset: Offset(0, _rise * (1 - p)),
      child: Transform.scale(
        scale: _scale + (1 - _scale) * p,
        alignment: origin.resolve(Directionality.of(context)),
        child: child,
      ),
    ),
  );
}
