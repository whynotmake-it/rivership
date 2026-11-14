// Internal to CoilQueuedStack; not exported.
// ignore_for_file: public_member_api_docs

import 'dart:math' as math;

import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/queued_stack/queued_stack.dart';
import 'package:coil/src/components/queued_stack/queued_stack_layout.dart';
import 'package:coil/src/components/queued_stack/queued_stack_style.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// How much smaller each card behind the front one is in the folded pile.
const _peekScale = 0.05;

/// Where a queued card starts: 14 px low at 0.96.
const _enterRise = 14.0;
const _enterScale = 0.96;

/// Where a leaving card ends: 0.9.
const _exitScale = 0.9;

/// The dragged card grows by this much.
const _liftScale = 0.03;

/// The inset around attachment previews.
const _thumbInset = 8.0;

/// One card of a `CoilQueuedStack`: its place, its arrival and departure,
/// and its content.
class QueuedStackCard extends StatelessWidget {
  /// Creates a card.
  const QueuedStackCard({
    required this.message,
    required this.slot,
    required this.appear,
    required this.exiting,
    required this.lifted,
    required this.expand,
    required this.expanded,
    required this.showActions,
    required this.semanticLabel,
    required this.labels,
    required this.editIcon,
    required this.removeIcon,
    required this.focusNode,
    required this.metrics,
    required this.look,
    required this.slotMotion,
    required this.opacityMotion,
    required this.travelMotion,
    required this.liftMotion,
    required this.onGone,
    required this.onFocusChange,
    required this.onTap,
    required this.onEdit,
    required this.onRemove,
    required this.onMove,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    super.key,
  });

  final CoilQueuedMessage message;
  final double slot;
  final bool appear;
  final bool exiting;
  final bool lifted;
  final double expand;
  final bool expanded;
  final bool showActions;
  final String semanticLabel;
  final CoilQueuedStackLabels labels;
  final Widget? editIcon;
  final Widget? removeIcon;
  final FocusNode focusNode;
  final CoilMetrics metrics;
  final CoilQueuedStackStyle look;
  final Motion slotMotion;
  final Motion opacityMotion;
  final Motion travelMotion;
  final Motion liftMotion;
  final VoidCallback onGone;
  final ValueChanged<bool> onFocusChange;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final ValueChanged<int>? onMove;
  final ValueChanged<double>? onDragStart;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final present = TrackBuilder(
      debugLabel: 'CoilQueuedStack.card',
      initialValues: [
        CoilQueuedStackTrack.opacity.value(appear ? 0 : 1),
        CoilQueuedStackTrack.travel.value(appear ? 0 : 1),
      ],
      animations: [
        CoilQueuedStackTrack.opacity([
          .to(exiting ? 0 : 1, motion: opacityMotion),
        ]),
        CoilQueuedStackTrack.travel([
          .to(exiting ? 0 : 1, motion: travelMotion),
        ]),
        CoilQueuedStackTrack.lift([.to(lifted ? 1 : 0, motion: liftMotion)]),
      ],
      onAnimationStatusChanged: (status) {
        if (exiting && !status.isAnimating) onGone();
      },
      builder: (context, value, child) {
        final t = value(CoilQueuedStackTrack.travel);
        final scale =
            (exiting
                ? _exitScale + (1 - _exitScale) * t
                : _enterScale + (1 - _enterScale) * t) +
            _liftScale * value(CoilQueuedStackTrack.lift);
        final rise = exiting ? 0.0 : _enterRise * (1 - t);
        return Opacity(
          opacity: value(CoilQueuedStackTrack.opacity).clamp(0, 1),
          child: _Scaled(scale: scale, dy: rise, child: child!),
        );
      },
      child: _CardBody(card: this),
    );

    return SingleMotionBuilder(
      value: slot,
      motion: slotMotion,
      debugLabel: 'CoilQueuedStack.slot',
      child: IgnorePointer(ignoring: exiting, child: present),
      builder: (context, slot, child) {
        // Folded, cards behind the front one peek out smaller, and those
        // past the visible peeks fade away. Fanned out, every card is whole.
        final peek = math.min(math.max(slot, 0), queuedStackMaxPeek.toDouble());
        final folded = (queuedStackMaxPeek + 1 - slot).clamp(0.0, 1.0);
        final peekScale = 1 - peek * _peekScale;
        return QueuedStackSlot(
          slot: slot,
          lifted: lifted,
          child: Opacity(
            opacity: folded + (1 - folded) * expand,
            child: _Scaled(
              scale: peekScale + (1 - peekScale) * expand,
              child: child!,
            ),
          ),
        );
      },
    );
  }
}

/// Scales [child] from its bottom center and moves it down [dy], resampling
/// it as an image while it's off its rest size so text doesn't jitter.
class _Scaled extends StatelessWidget {
  const _Scaled({required this.scale, required this.child, this.dy = 0});

  final double scale;
  final double dy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final moving = scale != 1 || dy != 0;
    return Transform(
      transform: Matrix4.translationValues(0, dy, 0)
        ..scaleByDouble(scale, scale, 1, 1),
      alignment: Alignment.bottomCenter,
      filterQuality: moving ? FilterQuality.medium : null,
      child: child,
    );
  }
}

class _CardBody extends StatefulWidget {
  const _CardBody({required this.card});

  final QueuedStackCard card;

  @override
  State<_CardBody> createState() => _CardBodyState();
}

class _CardBodyState extends State<_CardBody> {
  final _states = WidgetStatesController();
  var _focusWithin = false;

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final look = card.look;
    final metrics = card.metrics;
    final radius = look.radius!;
    final message = card.message;
    final files = message.attachments;
    final thumb = look.cardMinHeight! - 2 * _thumbInset;
    final edit = card.onEdit;
    final remove = card.onRemove;
    final move = card.onMove;

    Widget actions() => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        if (card.editIcon case final icon?)
          CoilButton.icon(
            variant: CoilButtonVariant.ghost,
            size: CoilSize.compact,
            semanticLabel: card.labels.edit,
            onPressed: edit,
            icon: icon,
          ),
        CoilButton.icon(
          variant: CoilButtonVariant.ghost,
          size: CoilSize.compact,
          semanticLabel: card.labels.remove,
          onPressed: remove,
          icon: card.removeIcon ?? const CoilDrawnGlyph(CoilGlyph.cross),
        ),
      ],
    );

    final content = ListenableBuilder(
      listenable: _states,
      builder: (context, _) {
        final states = _states.value;
        final showActions =
            card.showActions ||
            _focusWithin ||
            states.contains(WidgetState.hovered);
        return CoilFocusRing(
          visible: states.contains(WidgetState.focused),
          borderRadius: BorderRadius.circular(radius),
          offset: 2,
          child: CoilSurface(
            offset: 1,
            shadowLevel: look.shadowLevel,
            color: look.cardColor,
            borderRadius: BorderRadius.circular(radius),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: look.cardMinHeight!),
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: files.isEmpty ? metrics.controlPaddingX : _thumbInset,
                  end: 6,
                ),
                child: Row(
                  spacing: metrics.gap,
                  children: [
                    // Double-clicking the message edits it. The actions
                    // sit outside this region, so their taps aren't held
                    // back waiting for a second tap.
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onDoubleTap: card.expanded ? edit : null,
                        child: Row(
                          spacing: metrics.gap,
                          children: [
                            // The previews give way to the text when the
                            // card is narrow, as the text gives way to its
                            // ellipsis.
                            if (files.isNotEmpty)
                              Flexible(
                                child: UnconstrainedBox(
                                  constrainedAxis: Axis.vertical,
                                  alignment: AlignmentDirectional.centerStart,
                                  clipBehavior: Clip.hardEdge,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    spacing: 4,
                                    children: [
                                      for (final file in files.take(3))
                                        ClipRSuperellipse(
                                          borderRadius: BorderRadius.circular(
                                            math.max(0, radius - _thumbInset),
                                          ),
                                          child: SizedBox.square(
                                            dimension: thumb,
                                            child: file,
                                          ),
                                        ),
                                      if (files.length > 3)
                                        _More(
                                          count: files.length - 3,
                                          size: thumb,
                                          radius: math.max(
                                            0,
                                            radius - _thumbInset,
                                          ),
                                          style: look.countStyle!,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            Expanded(
                              child: ExcludeSemantics(
                                child: DefaultTextStyle.merge(
                                  style: look.textStyle,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  child:
                                      message.child ?? const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showActions) actions(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    return CallbackShortcuts(
      bindings: {
        if (edit != null) ...{
          const SingleActivator(LogicalKeyboardKey.enter): edit,
          const SingleActivator(LogicalKeyboardKey.numpadEnter): edit,
          const SingleActivator(LogicalKeyboardKey.f2): edit,
        },
        if (remove != null) ...{
          const SingleActivator(LogicalKeyboardKey.delete): remove,
          const SingleActivator(LogicalKeyboardKey.backspace): remove,
        },
        if (move != null) ...{
          const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): () =>
              move(1),
          const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): () =>
              move(-1),
        },
      },
      child: Focus(
        // Fires for the card and for a button inside it.
        focusNode: card.focusNode,
        onFocusChange: (focused) {
          setState(() => _focusWithin = focused);
          card.onFocusChange(focused);
        },
        child: Semantics(
          container: true,
          label: card.semanticLabel,
          customSemanticsActions: {
            if (edit != null)
              CustomSemanticsAction(label: card.labels.edit): edit,
          },
          child: GestureDetector(
            onVerticalDragStart: card.onDragStart == null
                ? null
                : (_) => card.onDragStart!(context.size!.height),
            onVerticalDragUpdate: card.onDragStart == null
                ? null
                : (details) => card.onDragUpdate(details.delta.dy),
            onVerticalDragEnd: card.onDragStart == null
                ? null
                : (_) => card.onDragEnd(),
            onVerticalDragCancel: card.onDragStart == null
                ? null
                : card.onDragEnd,
            child: CoilInteractionDetector(
              states: _states,
              focusNode: card.focusNode,
              onTap: card.onTap,
              trackPress: card.onTap != null,
              excludeFromSemantics: true,
              cursor: card.expanded
                  ? (card.lifted
                        ? SystemMouseCursors.grabbing
                        : SystemMouseCursors.grab)
                  : MouseCursor.defer,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// The count of attachments past the first three.
class _More extends StatelessWidget {
  const _More({
    required this.count,
    required this.size,
    required this.radius,
    required this.style,
  });

  final int count;
  final double size;
  final double radius;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: CoilColorMix.withTransparent(
          CoilTheme.of(context).colors.background,
          0.4,
        ),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      child: Center(child: Text('+$count', style: style)),
    ),
  );
}
