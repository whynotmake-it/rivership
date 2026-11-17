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
    required this.front,
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

  /// Whether this is the front card, the only one a folded pile lets
  /// pointers reach.
  final bool front;
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
          reachable: expanded || front,
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

    // A card peeking out of the folded pile takes no taps (a tap there
    // fans the pile out), and its buttons are drawn smaller than a hit
    // target. Screen readers get its actions on the card instead.
    final reachable = card.expanded || card.front;
    Widget actions() => ExcludeSemantics(
      excluding: !reachable,
      // On a card too narrow for both buttons, remove goes under edit.
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (card.editIcon case final icon?)
            CoilButton.icon(
              variant: CoilButtonVariant.ghost,
              size: CoilSize.compact,
              semanticLabel: card.labels.editLabel,
              onPressed: edit,
              icon: icon,
            ),
          CoilButton.icon(
            variant: CoilButtonVariant.ghost,
            size: CoilSize.compact,
            semanticLabel: card.labels.removeLabel,
            onPressed: remove,
            icon: card.removeIcon ?? const CoilDrawnGlyph(CoilGlyph.cross),
          ),
        ],
      ),
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
                child: _CardRow(
                  gap: metrics.gap,
                  children: [
                    // Double-clicking the message edits it. The actions
                    // sit outside this region, so their taps aren't held
                    // back waiting for a second tap.
                    GestureDetector(
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
                                child: message.child ?? const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ],
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

    return Shortcuts(
      shortcuts: {
        if (edit != null) ...const {
          SingleActivator(LogicalKeyboardKey.enter): _EditIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): _EditIntent(),
          SingleActivator(LogicalKeyboardKey.f2): _EditIntent(),
        },
        if (remove != null) ...const {
          SingleActivator(LogicalKeyboardKey.delete): _RemoveIntent(),
          SingleActivator(LogicalKeyboardKey.backspace): _RemoveIntent(),
        },
        if (move != null) ...const {
          SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): _MoveIntent(
            1,
          ),
          SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): _MoveIntent(
            -1,
          ),
        },
      },
      child: Actions(
        actions: {
          _EditIntent: CallbackAction<_EditIntent>(
            onInvoke: (_) => edit?.call(),
          ),
          _RemoveIntent: CallbackAction<_RemoveIntent>(
            onInvoke: (_) => remove?.call(),
          ),
          _MoveIntent: CallbackAction<_MoveIntent>(
            onInvoke: (intent) => move?.call(intent.by),
          ),
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
                CustomSemanticsAction(label: card.labels.editLabel): edit,
              if (remove != null && !reachable)
                CustomSemanticsAction(label: card.labels.removeLabel): remove,
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

/// Edits the focused card: Enter or F2.
class _EditIntent extends Intent {
  const _EditIntent();
}

/// Removes the focused card: Delete or Backspace.
class _RemoveIntent extends Intent {
  const _RemoveIntent();
}

/// Moves the focused card [by] places toward the back: Alt+Up and
/// Alt+Down.
class _MoveIntent extends Intent {
  const _MoveIntent(this.by);

  final int by;
}

/// A card's content row: the message (first child) and, when shown, its
/// actions (second child) at the end.
///
/// The message gets what the actions leave. When that would be narrower
/// than the actions themselves (a narrow screen at a large text scale),
/// the actions move to a line of their own under the message, at the end,
/// so they stay whole and the message keeps the card's width to ellipsize
/// in.
class _CardRow extends MultiChildRenderObjectWidget {
  const _CardRow({required this.gap, required super.children});

  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCardRow(gap: gap, textDirection: Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderCardRow renderObject) {
    renderObject
      ..gap = gap
      ..textDirection = Directionality.of(context);
  }
}

class _CardRowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderCardRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CardRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CardRowParentData> {
  _RenderCardRow({required this._gap, required this._textDirection});

  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _body => firstChild!;
  RenderBox? get _actions => childAfter(firstChild!);

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CardRowParentData) {
      child.parentData = _CardRowParentData();
    }
  }

  /// Lays the row out in [constraints], measuring children with [measure],
  /// and places them when [place].
  Size _layout(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) measure, {
    bool place = false,
  }) {
    final width = constraints.maxWidth;
    final actions = _actions;
    final actionsSize = actions == null
        ? Size.zero
        : measure(actions, BoxConstraints(maxWidth: width));
    // The message keeps at least the actions' width beside them.
    final stacked =
        actions != null && width - gap - actionsSize.width < actionsSize.width;
    final bodyWidth = actions == null || stacked
        ? width
        : width - gap - actionsSize.width;
    final body = measure(
      _body,
      BoxConstraints(
        minWidth: bodyWidth,
        maxWidth: bodyWidth,
        maxHeight: constraints.maxHeight,
      ),
    );
    if (stacked) {
      final band = math.max(constraints.minHeight, body.height);
      if (place) {
        _place(_body, 0, (band - body.height) / 2, body.width, width);
        _place(
          actions,
          width - actionsSize.width,
          band,
          actionsSize.width,
          width,
        );
      }
      return constraints.constrain(Size(width, band + actionsSize.height));
    }
    final height = math.max(
      constraints.minHeight,
      math.max(body.height, actionsSize.height),
    );
    if (place) {
      _place(_body, 0, (height - body.height) / 2, body.width, width);
      if (actions != null) {
        _place(
          actions,
          width - actionsSize.width,
          (height - actionsSize.height) / 2,
          actionsSize.width,
          width,
        );
      }
    }
    return constraints.constrain(Size(width, height));
  }

  /// Puts [child], [childWidth] wide, [start] from the start edge and
  /// [top] from the top.
  void _place(
    RenderBox child,
    double start,
    double top,
    double childWidth,
    double width,
  ) {
    final left = textDirection == TextDirection.ltr
        ? start
        : width - start - childWidth;
    (child.parentData! as _CardRowParentData).offset = Offset(left, top);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _layout(constraints, (child, c) => child.getDryLayout(c));

  @override
  void performLayout() {
    size = _layout(constraints, (child, c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    }, place: true);
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _body.getMinIntrinsicWidth(height),
    _actions?.getMinIntrinsicWidth(height) ?? 0,
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _body.getMaxIntrinsicWidth(height) +
      switch (_actions) {
        final actions? => gap + actions.getMaxIntrinsicWidth(height),
        null => 0,
      };

  double _intrinsicHeight(double width, {required bool max}) => _layout(
    BoxConstraints(maxWidth: width),
    (child, c) => Size(
      c.constrainWidth(child.getMaxIntrinsicWidth(double.infinity)),
      max
          ? child.getMaxIntrinsicHeight(c.maxWidth)
          : child.getMinIntrinsicHeight(c.maxWidth),
    ),
  ).height;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight(width, max: false);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight(width, max: true);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
