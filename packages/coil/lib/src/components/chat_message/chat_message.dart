// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:math' as math;

import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/chat_message/chat_message_menu.dart';
import 'package:coil/src/components/chat_message/chat_message_style.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

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

/// An action on a [CoilChatMessage], such as Copy or Retry.
///
/// Each action shows as an icon-only ghost button in the meta row. On
/// touch, long-pressing the message lists the same actions in a menu.
@immutable
class CoilChatMessageAction {
  /// Creates an action.
  const CoilChatMessageAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  /// The name: the button's semantic label and the menu row's text.
  final String label;

  /// The button's icon, styled through [IconTheme].
  final Widget icon;

  /// Called when the action runs. Null disables it.
  final VoidCallback? onPressed;
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
    this.size,
    this.motion,
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

  /// Replaces the container's label, which is the sender ("You" or
  /// "Assistant") and the [time].
  final String? semanticLabel;

  /// Pins the message to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens ([CoilThemeData.motion]) for this
  /// message.
  final CoilMotion? motion;

  /// Overrides for this message's look, on top of the theme's
  /// [CoilChatMessageStyle] and the defaults.
  final CoilChatMessageStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: size);
    final motion = CoilTheme.motionOf(context, override: this.motion);
    final style = CoilChatMessageStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilChatMessageStyle>(context)).merge(this.style);
    final user = sender == CoilChatSender.user;
    final name = user ? 'You' : 'Assistant';

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel ?? [name, ?time].join(', '),
      child: MotorInspectionScope(
        group: 'CoilChatMessage',
        child: _Entrance(
          entrance: entrance,
          motion: motion,
          origin: user
              ? AlignmentDirectional.bottomEnd
              : AlignmentDirectional.bottomStart,
          child: Align(
            alignment: user
                ? AlignmentDirectional.topEnd
                : AlignmentDirectional.topStart,
            heightFactor: 1,
            child: _MaxWidth(
              factor: user ? style.maxWidthFactor! : 1,
              child: _Message(
                user: user,
                attachments: attachments,
                time: time,
                actions: actions,
                metrics: metrics,
                motion: motion,
                style: style,
                child: child,
              ),
            ),
          ),
        ),
      ),
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

/// The message column. Tracks hover and focus within, which reveal the meta
/// row on the pointer tier, and opens the action menu on a touch long press.
class _Message extends StatefulWidget {
  const _Message({
    required this.user,
    required this.attachments,
    required this.time,
    required this.actions,
    required this.metrics,
    required this.motion,
    required this.style,
    required this.child,
  });

  final bool user;
  final List<Widget> attachments;
  final String? time;
  final List<CoilChatMessageAction> actions;
  final CoilMetrics metrics;
  final CoilMotion motion;
  final CoilChatMessageStyle style;
  final Widget? child;

  @override
  State<_Message> createState() => _MessageState();
}

class _MessageState extends State<_Message> {
  final _states = WidgetStatesController();
  final _bubbleKey = GlobalKey();
  bool _focusWithin = false;

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  void _openMenu() {
    final anchor = _bubbleKey.currentContext ?? context;
    showChatMessageMenu(anchor, widget.actions);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final align = widget.user
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final hasMeta = widget.time != null || widget.actions.isNotEmpty;
    // Touch can't hover, and a screen reader can't act on hidden buttons.
    final alwaysMeta =
        widget.metrics.tier == CoilTier.touch ||
        MediaQuery.accessibleNavigationOf(context);

    Widget? body;
    if (widget.child case final child?) {
      body = DefaultTextStyle(
        style: style.textStyle!,
        // A bubble hugs its longest line instead of the full width.
        textWidthBasis: TextWidthBasis.longestLine,
        child: widget.user
            ? DecoratedBox(
                decoration: ShapeDecoration(
                  color: style.bubble,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(style.radius!),
                  ),
                ),
                child: Padding(padding: style.padding!, child: child),
              )
            : Padding(
                padding: EdgeInsets.symmetric(vertical: style.padding!.top),
                child: child,
              ),
      );
    }

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align,
      spacing: 6,
      children: [
        if (widget.attachments.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: widget.user ? WrapAlignment.end : WrapAlignment.start,
            children: widget.attachments,
          ),
        if (body != null) KeyedSubtree(key: _bubbleKey, child: body),
        if (hasMeta)
          ListenableBuilder(
            listenable: _states,
            builder: (context, _) => _MetaRow(
              visible:
                  alwaysMeta ||
                  _focusWithin ||
                  _states.value.contains(WidgetState.hovered),
              time: widget.time,
              actions: widget.actions,
              motion: widget.motion,
              style: style,
            ),
          ),
      ],
    );

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (focused) => setState(() => _focusWithin = focused),
      child: CoilInteractionDetector(
        states: _states,
        trackPress: false,
        child: GestureDetector(
          supportedDevices: const {PointerDeviceKind.touch},
          onLongPress: widget.actions.isEmpty ? null : _openMenu,
          child: column,
        ),
      ),
    );
  }
}

/// The time and the action buttons. It keeps its height while hidden, so
/// revealing it never moves the transcript.
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.visible,
    required this.time,
    required this.actions,
    required this.motion,
    required this.style,
  });

  final bool visible;
  final String? time;
  final List<CoilChatMessageAction> actions;
  final CoilMotion motion;
  final CoilChatMessageStyle style;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          if (time case final time?)
            // The container's label already says the time.
            ExcludeSemantics(child: Text(time, style: style.metaStyle)),
          if (actions.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                for (final action in actions)
                  CoilButton.icon(
                    onPressed: action.onPressed,
                    icon: action.icon,
                    semanticLabel: action.label,
                    variant: CoilButtonVariant.ghost,
                    size: CoilSize.compact,
                  ),
              ],
            ),
        ],
      ),
    );
    return IgnorePointer(
      ignoring: !visible,
      child: SingleMotionBuilder(
        value: visible ? 1 : 0,
        motion: visible ? motion.fade : motion.fadeExit,
        debugLabel: 'CoilChatMessage.meta',
        child: row,
        // Hidden only from sight: Tab still reaches the buttons.
        builder: (context, opacity, row) => Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          alwaysIncludeSemantics: true,
          child: row,
        ),
      ),
    );
  }
}

/// The entrance: opacity on `fade`; height, rise and scale on `standard`.
/// Under reduced motion only the fade remains.
class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.entrance,
    required this.motion,
    required this.origin,
    required this.child,
  });

  final CoilChatMessageEntrance entrance;
  final CoilMotion motion;
  final AlignmentDirectional origin;
  final Widget child;

  static const _rise = 8.0;
  static const _scale = 0.96;

  @override
  Widget build(BuildContext context) {
    if (entrance == CoilChatMessageEntrance.none) return child;
    return SingleMotionBuilder(
      from: 0,
      value: 1,
      motion: motion.fade,
      debugLabel: 'CoilChatMessage.enter.opacity',
      child: SingleMotionBuilder(
        from: 0,
        value: 1,
        motion: motion.standard,
        debugLabel: 'CoilChatMessage.enter.travel',
        child: child,
        builder: (context, p, child) => Align(
          // Opens downward, so the overflow while it grows never covers the
          // message above.
          alignment: Alignment.topCenter,
          heightFactor: math.max(p, 0),
          child: Transform.translate(
            offset: Offset(0, _rise * (1 - p)),
            child: Transform.scale(
              scale: _scale + (1 - _scale) * p,
              alignment: origin.resolve(Directionality.of(context)),
              child: child,
            ),
          ),
        ),
      ),
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
    );
  }
}
