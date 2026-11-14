// MotorInspectionScope is @experimental; the motor example uses it too.
// ignore_for_file: experimental_member_use
import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/card/card_body.dart';
import 'package:coil/src/components/card/card_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// The animated parts of a [CoilCard] and a `CoilCardGroup`. Use them as
/// keys of [CoilCard.motions], `CoilCardGroup.motions` or
/// [CoilThemeData.trackMotions].
final class CoilCardTrack<T extends Object> extends Track<T> {
  CoilCardTrack._(super.converter, {required String super.debugLabel});

  /// The hover and press fill over a card with an action. Default motion:
  /// `fade` in, `fadeExit` out.
  static final overlay = CoilCardTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilCard.overlay',
  );

  /// The dismiss button's opacity as it shows and hides. Default motion:
  /// `fade` in, `fadeExit` out.
  static final dismissReveal = CoilCardTrack<double>._(
    .single,
    debugLabel: 'CoilCard.dismissReveal',
  );

  /// How open a dismissed card's height is, 0 to 1. Default motion:
  /// `standard`.
  static final dismissHeight = CoilCardTrack<double>._(
    .single,
    debugLabel: 'CoilCard.dismissHeight',
  );

  /// A dismissed card's blur-fade. Default motion: `fadeExit`.
  static final dismissFade = CoilCardTrack<double>._(
    .single,
    debugLabel: 'CoilCard.dismissFade',
  );

  /// The highlight gliding between the cards of a `CoilCardGroup`. Default
  /// motion: `quick`.
  static final highlight = CoilCardTrack<Rect>._(
    .rect,
    debugLabel: 'CoilCardGroup.highlight',
  );
}

/// A card: a surface with optional media, a title, a description, content
/// and actions.
///
/// With [onPressed], the whole card is one button: one tab stop with an
/// inset focus ring, a hover fill (or the group's gliding highlight) for
/// pointers and a press fill for touch. Buttons in [actions] stay separate
/// targets after it in Tab order.
///
/// With [onDismissed], the card shows a dismiss button at its top trailing
/// corner: on hover or focus for pointers, always on touch. Pressing it
/// plays the exit (a blur-fade while the height collapses) and *then* calls
/// [onDismissed], as [Dismissible] does. Remove the card from the tree in
/// that callback.
///
/// Put cards in a `CoilCardGroup` to divide them into one block or lay
/// them out in a grid with one highlight between them.
class CoilCard extends StatefulWidget {
  /// Creates a card.
  const CoilCard({
    super.key,
    this.title,
    this.description,
    this.child,
    this.media,
    this.icon,
    this.actions = const [],
    this.variant = CoilCardVariant.stacked,
    this.onPressed,
    this.onDismissed,
    this.dismissIcon,
    this.dismissLabel = 'Dismiss',
    this.semanticLabel,
    this.size,
    this.focusNode,
    this.autofocus = false,
    this.motion,
    this.motions,
    this.style,
  });

  /// The title, in the title role.
  final Widget? title;

  /// A line under the title, muted.
  final Widget? description;

  /// The content under the header.
  final Widget? child;

  /// An image: full-bleed on top for [CoilCardVariant.stacked], a square
  /// at the leading edge for [CoilCardVariant.inline].
  final Widget? media;

  /// An icon shown in a tinted tile before the header.
  final Widget? icon;

  /// The card's buttons, usually compact ghost [CoilButton]s. They sit under
  /// the content (or at the trailing edge when inline) and are sized
  /// compact.
  final List<Widget> actions;

  /// Where the media goes.
  final CoilCardVariant variant;

  /// Makes the whole card a button. Null leaves it static.
  final VoidCallback? onPressed;

  /// Shows a dismiss button; called after the exit animation, when the
  /// card should be removed.
  final VoidCallback? onDismissed;

  /// Replaces the dismiss button's drawn ✕.
  final Widget? dismissIcon;

  /// The dismiss button's name for assistive technology.
  final String dismissLabel;

  /// Names the card's button. Defaults to the text inside it.
  final String? semanticLabel;

  /// Pins the card to one size step.
  final CoilSize? size;

  /// The focus node of the card's button.
  final FocusNode? focusNode;

  /// Whether the card's button takes focus when first built.
  final bool autofocus;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions for this card, keyed by [CoilCardTrack]s. They win
  /// over the theme's [CoilThemeData.trackMotions] and the tokens.
  final Map<CoilCardTrack<Object>, Motion>? motions;

  /// Overrides for this card's look, on top of the theme's [CoilCardStyle]
  /// and the defaults.
  final CoilCardStyle? style;

  @override
  State<CoilCard> createState() => _CoilCardState();
}

class _CoilCardState extends State<CoilCard> {
  final _states = WidgetStatesController();
  bool _focusWithin = false;
  bool _dismissing = false;
  bool _dismissed = false;

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissing) return;
    // The focus would be lost with the card; leave it before it goes.
    if (_focusWithin) FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _dismissing = true);
  }

  void _onExitEnd() {
    if (!_dismissing || _dismissed) return;
    _dismissed = true;
    widget.onDismissed?.call();
  }

  Motion _motionFor(
    CoilCardTrack<Object> track,
    Motion token, {
    bool spatial = true,
  }) => CoilTheme.trackMotionOf(
    context,
    track,
    instance: widget.motions,
    token: token,
    spatial: spatial,
  );

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final style = CoilCardStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilCardStyle>(context)).merge(widget.style);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final slot = CardSlot.maybeOf(context);
    final radius = BorderRadius.circular(style.radius!);
    final actionable = widget.onPressed != null && !_dismissing;

    final body = Stack(
      children: [
        CardBody(
          variant: widget.variant,
          title: widget.title,
          description: widget.description,
          content: widget.child,
          media: widget.media,
          icon: widget.icon,
          actions: widget.actions,
          style: style,
          metrics: metrics,
          reserveEnd: widget.onDismissed == null
              ? 0
              : CoilTheme.metricsOf(
                  context,
                  tier: metrics.tier,
                  size: CoilSize.compact,
                ).controlHeight,
        ),
        if (widget.onDismissed != null)
          PositionedDirectional(
            top: style.dismissInset,
            end: style.dismissInset,
            child: ListenableBuilder(
              listenable: _states,
              builder: (context, _) => CardDismissButton(
                // Touch has no hover to reveal it, so it always shows.
                visible:
                    metrics.tier == CoilTier.touch ||
                    _focusWithin ||
                    _states.value.contains(WidgetState.hovered),
                icon: widget.dismissIcon,
                semanticLabel: widget.dismissLabel,
                showMotion: _motionFor(
                  CoilCardTrack.dismissReveal,
                  motion.fade,
                  spatial: false,
                ),
                hideMotion: _motionFor(
                  CoilCardTrack.dismissReveal,
                  motion.fadeExit,
                  spatial: false,
                ),
                onPressed: _dismissing ? null : _dismiss,
              ),
            ),
          ),
      ],
    );

    Widget decorate(
      BuildContext context,
      Set<WidgetState> states,
      Widget? child,
    ) {
      final hovered = states.contains(WidgetState.hovered);
      final pressed = states.contains(WidgetState.pressed);
      final overlay = style.overlay!.resolve({
        // In a group the gliding highlight shows hover, and a hovering
        // pointer's press needs no extra fill (DESIGN.md §8.1).
        if (actionable && hovered && slot == null) WidgetState.hovered,
        if (actionable && pressed && !hovered) WidgetState.pressed,
      })!;
      return CoilFocusRing(
        visible: states.contains(WidgetState.focused),
        borderRadius: radius,
        // Inset, inside the card's clip.
        offset: -(1 + theme.focusRingWidth),
        child: MotionBuilder<Color>(
          value: overlay,
          converter: MotionConverter.colorRgb,
          motion: _motionFor(
            CoilCardTrack.overlay,
            pressed || hovered ? motion.fade : motion.fadeExit,
            spatial: false,
          ),
          debugLabel: 'CoilCard overlay',
          builder: (context, color, child) => DecoratedBox(
            decoration: ShapeDecoration(
              color: color,
              shape: RoundedSuperellipseBorder(borderRadius: radius),
            ),
            child: child,
          ),
          child: child,
        ),
      );
    }

    Widget card = widget.onPressed != null
        ? CoilInteraction(
            onPressed: actionable ? widget.onPressed : null,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            statesController: _states,
            builder: decorate,
            child: body,
          )
        // A static card still tracks hover, to reveal its dismiss button.
        : CoilInteractionDetector(
            states: _states,
            trackPress: false,
            child: ListenableBuilder(
              listenable: _states,
              builder: (context, child) =>
                  decorate(context, _states.value, child),
              child: body,
            ),
          );

    card = Semantics(
      container: true,
      button: widget.onPressed != null,
      enabled: widget.onPressed == null ? null : actionable,
      label: widget.semanticLabel,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onFocusChange: (focused) => setState(() => _focusWithin = focused),
        child: ClipRSuperellipse(borderRadius: radius, child: card),
      ),
    );

    // In a group the group paints the surface, under its highlight.
    if (slot == null) {
      card = DecoratedBox(
        decoration: ShapeDecoration(
          color: style.surface,
          shadows: style.shadows,
          shape: RoundedSuperellipseBorder(
            borderRadius: radius,
            side: style.border!,
          ),
        ),
        child: card,
      );
    }

    if (widget.onDismissed != null) {
      final fade = _motionFor(
        CoilCardTrack.dismissFade,
        motion.fadeExit,
        spatial: false,
      );
      card = CoilCollapsible(
        expanded: !_dismissing,
        heightMotion: _motionFor(CoilCardTrack.dismissHeight, motion.standard),
        // The blur-fade below does the fading.
        fade: false,
        onEnd: _onExitEnd,
        debugLabel: 'CoilCard dismiss',
        child: MotionSwitcher(
          motion: motion.fade,
          exitMotion: fade,
          debugLabel: 'CoilCard dismiss fade',
          transitionBuilder: CoilBlurFade.transition(),
          // The leaving card keeps its size, so the height collapses from it.
          layoutBuilder: (current, previous) => Stack(
            children: [...previous, ?current],
          ),
          child: _dismissing
              ? null
              : KeyedSubtree(key: const ValueKey('card'), child: card),
        ),
      );
    }

    if (slot != null) {
      card = CoilHoverItem(
        index: slot.index,
        enabled: actionable,
        child: card,
      );
    }
    return MotorInspectionScope(group: 'CoilCard', child: card);
  }
}

/// Tells a [CoilCard] which cell of a `CoilCardGroup` it is in.
class CardSlot extends InheritedWidget {
  /// Puts [child] in cell [index].
  const CardSlot({required this.index, required super.child, super.key});

  /// The cell.
  final int index;

  /// The nearest slot, if the card is in a group.
  static CardSlot? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CardSlot>();

  @override
  bool updateShouldNotify(CardSlot oldWidget) => oldWidget.index != index;
}
