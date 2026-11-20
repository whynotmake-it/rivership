// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/queued_stack/queued_stack_card.dart';
import 'package:coil/src/components/queued_stack/queued_stack_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// The animated parts of a [CoilQueuedStack]. Use them as keys of
/// [CoilQueuedStack.motions] or [CoilQueuedStackStyle.motions].
final class CoilQueuedStackTrack<T extends Object> extends Track<T> {
  CoilQueuedStackTrack._(
    super.converter, {
    required String super.debugLabel,
    super.initial,
  });

  /// The stack fanning out and folding back. Default motion: `standard`
  /// out, `standardExit` back.
  static final expand = CoilQueuedStackTrack<double>._(
    .single,
    initial: 0,
    debugLabel: 'CoilQueuedStack.expand',
  );

  /// A card moving to a new place in the queue. Default motion: `standard`.
  static final slot = CoilQueuedStackTrack<double>._(
    .single,
    initial: 0,
    debugLabel: 'CoilQueuedStack.slot',
  );

  /// A card's opacity as it's queued or leaves. Default motion: `fade` in,
  /// `fadeExit` out.
  static final opacity = CoilQueuedStackTrack<double>._(
    .single,
    initial: 1,
    debugLabel: 'CoilQueuedStack.opacity',
  );

  /// A card's rise and scale as it's queued or leaves. Default motion:
  /// `standard` in, `standardExit` out.
  static final travel = CoilQueuedStackTrack<double>._(
    .single,
    initial: 1,
    debugLabel: 'CoilQueuedStack.travel',
  );

  /// The dragged card lifting. Default motion: `quick`.
  static final lift = CoilQueuedStackTrack<double>._(
    .single,
    initial: 0,
    debugLabel: 'CoilQueuedStack.lift',
  );

  /// The collapsed stack recoiling when a message is queued behind the
  /// visible cards. Default motion: `gentle`, coil's bounciest token; the
  /// original's one-off spring (bounce 0.5) isn't a tier.
  static final bump = CoilQueuedStackTrack<double>._(
    .single,
    initial: 0,
    debugLabel: 'CoilQueuedStack.bump',
  );
}

/// A message waiting in a [CoilQueuedStack].
@immutable
class CoilQueuedMessage {
  /// Creates a queued message.
  const CoilQueuedMessage({
    required this.id,
    required this.semanticLabel,
    this.child,
    this.attachments = const [],
  });

  /// Identifies the message across rebuilds, so it keeps its card while the
  /// queue changes.
  final Object id;

  /// The message as screen readers hear it, usually its text.
  final String semanticLabel;

  /// The message text, usually a [Text]. The card styles it in the subtitle
  /// role and keeps it to one line with an ellipsis.
  final Widget? child;

  /// Previews of attached files, such as `CoilFileThumbnail`s. The card
  /// shows the first three in small squares and counts the rest.
  final List<Widget> attachments;
}

/// The words a [CoilQueuedStack] gives screen readers. The defaults are
/// English.
@immutable
class CoilQueuedStackLabels {
  /// Creates the labels.
  const CoilQueuedStackLabels({
    this.editLabel = 'Edit',
    this.removeLabel = 'Remove',
    this.collapseLabel = 'Collapse queued messages',
    this.messageLabel = _message,
    this.countLabel = _count,
  });

  /// The edit button.
  final String editLabel;

  /// The remove button.
  final String removeLabel;

  /// The collapse button an expanded stack shows on touch.
  final String collapseLabel;

  /// A card: its place in the queue (from 1), the queue's length and the
  /// message's [CoilQueuedMessage.semanticLabel].
  final String Function(int position, int count, String label) messageLabel;

  /// The gutter: how many messages are queued.
  final String Function(int count) countLabel;

  static String _message(int position, int count, String label) =>
      'Queued message $position of $count: $label';

  static String _count(int count) =>
      count == 1 ? '1 queued message' : '$count queued messages';
}

/// Messages queued while a reply streams, as a pile of cards above the
/// composer.
///
/// The front card is the next to send; two more peek out behind it, and
/// the gutter counts the rest. The pile fans out while a mouse hovers it
/// or a card has keyboard focus. On touch, tap it to fan it out; it stays
/// open until the collapse button folds it. Fanned out, every card takes
/// taps, hovers and focus; folded, only the front card's controls do, and a
/// tap on a card peeking behind it fans the pile out.
///
/// Fanned out, drag a card to reorder the queue. Each card has remove and
/// edit buttons: on touch they always show; with a mouse, on hover.
/// Tab visits the cards in queue order, front first.
/// Double-clicking a card, or Enter or F2 on a focused card, edits it;
/// Delete or Backspace removes it; Alt+↑ and Alt+↓ move it.
///
/// [onChanged] gets the new queue after a reorder or a removal; [onEdit]
/// gets a message to move back into the composer (remove it from the
/// queue there). A message queued behind the visible cards makes the pile
/// recoil, so the user feels it land.
///
/// Place it right above the composer and pass the transcript as [child].
/// The transcript's `ListView` then keeps its last message clear of the
/// pile on its own:
///
/// ```dart
/// Column(children: [
///   Expanded(
///     child: CoilQueuedStack(
///       messages: queue,
///       onChanged: …,
///       onEdit: …,
///       child: ListView(reverse: true, children: transcript),
///     ),
///   ),
///   CoilInputMessage(onSend: …, onQueue: …),
/// ])
/// ```
class CoilQueuedStack extends StatefulWidget {
  /// Creates a queued-message stack.
  const CoilQueuedStack({
    required this.messages,
    required this.onChanged,
    required this.onEdit,
    super.key,
    this.child,
    this.icon,
    this.editIcon,
    this.removeIcon,
    this.labels = const CoilQueuedStackLabels(),
    this.size,
    this.motion,
    this.motions,
    this.style,
  });

  /// The queue, front first: the first message is sent next.
  final List<CoilQueuedMessage> messages;

  /// Called with the new queue after a reorder or a removal.
  final ValueChanged<List<CoilQueuedMessage>> onChanged;

  /// Called with a message to move back into the composer.
  final ValueChanged<CoilQueuedMessage> onEdit;

  /// The content the pile floats over, usually the transcript. With a
  /// child, the stack fills the space it's given, lays the child out under
  /// the pile, and adds the folded pile's height to the child's bottom
  /// `MediaQuery` padding, so a `ListView` keeps its last message clear of
  /// the pile. Null leaves only the pile, as tall as its cards.
  final Widget? child;

  /// The gutter glyph beside the front card, such as an arrow into the
  /// composer. Null leaves only the count.
  final Widget? icon;

  /// The edit button's glyph. Null leaves no edit button; double-click and
  /// the keyboard still edit.
  final Widget? editIcon;

  /// The remove button's glyph. Null shows the theme's [CoilIcons.close],
  /// or coil's drawn ×.
  final Widget? removeIcon;

  /// The words screen readers hear.
  final CoilQueuedStackLabels labels;

  /// Pins the size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens for this stack.
  final CoilMotion? motion;

  /// Per-track motions, keyed by [CoilQueuedStackTrack]s. They win over the
  /// style's [CoilQueuedStackStyle.motions] and the tokens.
  final Map<CoilQueuedStackTrack<Object>, Motion>? motions;

  /// Overrides for this stack's look.
  final CoilQueuedStackStyle? style;

  @override
  State<CoilQueuedStack> createState() => _CoilQueuedStackState();
}

class _Entry {
  _Entry(this.message, this.slot, {required this.appear});

  CoilQueuedMessage message;
  int slot;
  final bool appear;
  bool exiting = false;
  final focusNode = FocusNode(debugLabel: 'CoilQueuedStack.card');
}

class _CoilQueuedStackState extends State<CoilQueuedStack> {
  late List<_Entry> _entries = [
    for (final (i, m) in widget.messages.indexed) _Entry(m, i, appear: false),
  ];

  /// Fanned out by a tap until the collapse button folds it; reports
  /// whether the pile is fanned out.
  final _stack = CoilCardStackController();

  /// The card being dragged, and where it is, in places from the front.
  _Entry? _dragging;
  var _dragSlot = 0.0;
  var _dragStartSlot = 0.0;
  var _dragDistance = 0.0;
  var _pitch = 1.0;

  /// Counts recoils, to replay the bump.
  var _bumps = 0;

  @override
  void initState() {
    super.initState();
    _stack.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void didUpdateWidget(CoilQueuedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final live = {
      for (final e in _entries)
        if (!e.exiting) e.message.id: e,
    };
    final ids = {for (final m in widget.messages) m.id};
    final next = <_Entry>[];
    for (final (i, m) in widget.messages.indexed) {
      final entry = live[m.id];
      if (entry == null) {
        next.add(_Entry(m, i, appear: true));
      } else {
        next.add(
          entry
            ..message = m
            ..slot = i,
        );
      }
    }
    for (final entry in _entries) {
      if (entry.exiting || !ids.contains(entry.message.id)) {
        if (!entry.exiting && entry == _dragging) _dragging = null;
        next.add(entry..exiting = true);
      }
    }
    if (widget.messages.length > live.length &&
        live.isNotEmpty &&
        !_stack.expanded) {
      _bumps++;
    }
    _entries = next;
  }

  @override
  void dispose() {
    _stack
      ..removeListener(_rebuild)
      ..dispose();
    for (final entry in _entries) {
      entry.focusNode.dispose();
    }
    super.dispose();
  }

  void _gone(_Entry entry) {
    if (!mounted || !_entries.contains(entry)) return;
    setState(() => _entries.remove(entry));
    // A focused card leaves its node behind; drop it after the frame.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => entry.focusNode.dispose(),
    );
  }

  void _move(_Entry entry, int to) {
    final queue = [...widget.messages];
    final from = queue.indexWhere((m) => m.id == entry.message.id);
    if (from < 0 || to < 0 || to >= queue.length || from == to) return;
    queue.insert(to, queue.removeAt(from));
    widget.onChanged(queue);
  }

  void _remove(_Entry entry) => widget.onChanged([
    for (final m in widget.messages)
      if (m.id != entry.message.id) m,
  ]);

  void _dragStart(_Entry entry, double cardHeight) {
    setState(() {
      _dragging = entry;
      _pitch = cardHeight + CoilTheme.metricsOf(context, size: widget.size).gap;
      _dragStartSlot = _dragSlot = entry.slot.toDouble();
      _dragDistance = 0;
    });
  }

  void _dragUpdate(double dy) {
    final entry = _dragging;
    if (entry == null) return;
    _dragDistance += dy;
    final last = (widget.messages.length - 1).toDouble();
    setState(() {
      _dragSlot = (_dragStartSlot - _dragDistance / _pitch).clamp(0, last);
    });
    final to = _dragSlot.round();
    if (to != entry.slot) _move(entry, to);
  }

  void _dragEnd() => setState(() => _dragging = null);

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final tokens = CoilTheme.motionOf(context, override: widget.motion);
    final look = CoilQueuedStackStyle.fallback(theme, metrics)
        .merge(CoilTheme.styleOf<CoilQueuedStackStyle>(context))
        .merge(widget.style);

    /// The motion set for [track] on this stack or in its style, if any.
    Motion? customOf(CoilQueuedStackTrack<Object> track) =>
        widget.motions?[track] ?? look.motions?[track];
    Motion motionOf(
      CoilQueuedStackTrack<Object> track,
      Motion token, {
      bool spatial = true,
    }) => CoilTheme.trackMotionOf(
      context,
      track,
      instance: widget.motions,
      styled: look.motions,
      token: token,
      spatial: spatial,
    );

    final count = widget.messages.length;
    final hidden = count - (CoilCardStack.defaultMaxPeeks + 1);
    final touch = metrics.tier == CoilTier.touch;
    void pin() => _stack.pinned = true;
    // A pile of one has nothing to fold: the stack clears the pin after the
    // frame, and the button goes now.
    final collapsible = _stack.pinned && count >= 2;

    final gutter = MotionSwitcher(
      motion: tokens.fade,
      exitMotion: tokens.fadeExit,
      transitionBuilder: CoilBlurFade.transition(blur: 0),
      child: collapsible
          ? Center(
              key: const ValueKey('collapse'),
              child: CoilButton.icon(
                variant: CoilButtonVariant.ghost,
                size: CoilSize.compact,
                semanticLabel: widget.labels.collapseLabel,
                onPressed: () => _stack.pinned = false,
                icon: const CoilIcon(CoilIconRole.chevronDown),
              ),
            )
          : Semantics(
              key: const ValueKey('count'),
              label: count == 0 ? null : widget.labels.countLabel(count),
              child: ExcludeSemantics(
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: look.iconColor,
                    size: metrics.iconSize,
                    applyTextScaling: true,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    spacing: 4,
                    children: [
                      MotionSwitcher(
                        motion: tokens.quick,
                        exitMotion: tokens.quickExit,
                        transitionBuilder: CoilBlurFade.transition(
                          blur: 0,
                          scale: 0.6,
                        ),
                        child: hidden > 0
                            ? Text(
                                '$count',
                                key: ValueKey(count),
                                style: look.countStyle,
                              )
                            : const SizedBox.shrink(),
                      ),
                      ?widget.icon,
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),
    );

    QueuedStackCard card(_Entry entry) => QueuedStackCard(
      key: ObjectKey(entry),
      message: entry.message,
      appear: entry.appear,
      exiting: entry.exiting,
      lifted: entry == _dragging,
      front: entry.slot == 0 && !entry.exiting,
      showActions: touch,
      semanticLabel: widget.labels.messageLabel(
        entry.slot + 1,
        count,
        entry.message.semanticLabel,
      ),
      labels: widget.labels,
      editIcon: widget.editIcon,
      removeIcon: widget.removeIcon,
      focusNode: entry.focusNode,
      metrics: metrics,
      look: look,
      opacityMotion: motionOf(
        CoilQueuedStackTrack.opacity,
        entry.exiting ? tokens.fadeExit : tokens.fade,
        spatial: false,
      ),
      travelMotion: motionOf(
        CoilQueuedStackTrack.travel,
        entry.exiting ? tokens.standardExit : tokens.standard,
      ),
      liftMotion: motionOf(CoilQueuedStackTrack.lift, tokens.quick),
      onGone: () => _gone(entry),
      onTap: pin,
      onEdit: entry.exiting ? null : () => widget.onEdit(entry.message),
      onRemove: entry.exiting ? null : () => _remove(entry),
      onMove: entry.exiting ? null : (by) => _move(entry, entry.slot + by),
      onDragStart: entry.exiting ? null : (height) => _dragStart(entry, height),
      onDragUpdate: _dragUpdate,
      onDragEnd: _dragEnd,
    );

    final bumpMotion = motionOf(CoilQueuedStackTrack.bump, tokens.gentle);
    final body = widget.child;
    final expandMotion = customOf(CoilQueuedStackTrack.expand);
    final slotMotion = customOf(CoilQueuedStackTrack.slot);
    return MotorInspectionScope(
      group: 'CoilQueuedStack',
      child: TrackBuilder(
        restartTrigger: _bumps,
        animations: [
          if (_bumps > 0)
            CoilQueuedStackTrack.bump([.to(0, motion: bumpMotion)], from: -7),
        ],
        // The pile: folded peeks, fanned-out spacing by the cards' heights,
        // and which card takes input when, all from the shared card stack.
        builder: (context, bump, _) => CoilCardStack(
          controller: _stack,
          fold: CoilCardStackFold.manual,
          // Held open while a card is dragged; a tap's pin stays for after.
          expand: _dragging != null
              ? CoilCardStackExpand.always
              : CoilCardStackExpand.auto,
          // The stack's own size step, which the drag pitch uses too.
          gap: metrics.gap,
          motion: widget.motion,
          motions: {
            CoilCardStackTrack.expand: ?expandMotion,
            CoilCardStackTrack.slot: ?slotMotion,
            CoilCardStackTrack.leave: ?slotMotion,
          },
          // The recoil lifts the pile (a negative bump is up).
          shift: -bump(CoilQueuedStackTrack.bump),
          // The gutter's glyph and count grow with the text.
          sideWidth: MediaQuery.textScalerOf(
            context,
          ).scale(look.gutterWidth!),
          leading: count > 0 ? gutter : null,
          background: body == null ? null : _Body(child: body),
          items: [
            for (final entry in _entries)
              CoilCardStackItem(
                key: ObjectKey(entry),
                slot: entry == _dragging ? _dragSlot : entry.slot.toDouble(),
                slotMotion: entry == _dragging ? const Motion.instant() : null,
                lifted: entry == _dragging,
                leaving: entry.exiting,
                child: card(entry),
              ),
          ],
        ),
      ),
    );
  }
}

/// The content under the pile, with the folded pile's height added to its
/// bottom padding.
class _Body extends StatelessWidget {
  const _Body({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final extent = CoilCardStack.pileExtentOf(constraints);
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          padding: media.padding.copyWith(
            bottom: media.padding.bottom + extent,
          ),
        ),
        child: child,
      );
    },
  );
}
