// MotorInspectionScope is @experimental; the motor example uses it too.
// ignore_for_file: experimental_member_use
import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/card/card_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// Where a [CoilCard] puts its media.
enum CoilCardVariant {
  /// Media on top, full-bleed at 16:9; the text below.
  stacked,

  /// Media at the leading edge (a 160 square); the text beside it and the
  /// actions at the trailing edge.
  inline,
}

/// How a [CoilCardGroup] separates its cards.
enum CoilCardGroupLayout {
  /// One block with hairlines between the cards.
  divided,

  /// Separate cards with a gap between them.
  separated,
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
/// Put cards in a [CoilCardGroup] to divide them into one block or lay
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
    this.style,
  });

  /// The title, in the title role.
  final Widget? title;

  /// A line under the title, muted.
  final Widget? description;

  /// The content under the header.
  final Widget? child;

  /// An image: full-bleed on top for [CoilCardVariant.stacked], a 160
  /// square at the leading edge for [CoilCardVariant.inline].
  final Widget? media;

  /// An icon shown in a tinted 32 tile before the header.
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

  void _onExitStatus(AnimationStatus status) {
    if (!_dismissing || _dismissed || status.isAnimating) return;
    _dismissed = true;
    widget.onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final style = CoilCardStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilCardStyle>(context)).merge(widget.style);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final slot = _CardSlot.maybeOf(context);
    final radius = BorderRadius.circular(style.radius!);
    final actionable = widget.onPressed != null && !_dismissing;

    final body = Stack(
      children: [
        _CardBody(
          card: widget,
          style: style,
          metrics: metrics,
          reserveEnd: widget.onDismissed == null ? 0 : _dismissExtent(metrics),
        ),
        if (widget.onDismissed != null)
          PositionedDirectional(
            top: _dismissInset(metrics),
            end: _dismissInset(metrics),
            child: ListenableBuilder(
              listenable: _states,
              builder: (context, _) => _DismissButton(
                // Touch has no hover to reveal it, so it always shows.
                visible:
                    metrics.tier == CoilTier.touch ||
                    _focusWithin ||
                    _states.value.contains(WidgetState.hovered),
                icon: widget.dismissIcon,
                label: widget.dismissLabel,
                motion: motion,
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
          motion: pressed || hovered ? motion.fade : motion.fadeExit,
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

    card = _DismissExit(
      dismissing: _dismissing,
      motion: motion,
      onStatus: _onExitStatus,
      child: card,
    );

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

/// The dismiss button's visual size.
double _dismissExtent(CoilMetrics metrics) => const CoilMetricsTable()
    .resolve(metrics.tier, CoilSize.compact)
    .controlHeight;

/// Where the dismiss button's layout box sits, so its visual is 8 from the
/// corner while its hit box can be larger.
double _dismissInset(CoilMetrics metrics) {
  final compact = const CoilMetricsTable().resolve(
    metrics.tier,
    CoilSize.compact,
  );
  final grow = compact.minHitTarget > compact.controlHeight
      ? (compact.minHitTarget - compact.controlHeight) / 2
      : 0.0;
  return 8 - grow;
}

/// The slots, laid out for the card's variant.
class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.card,
    required this.style,
    required this.metrics,
    required this.reserveEnd,
  });

  final CoilCard card;
  final CoilCardStyle style;
  final CoilMetrics metrics;

  /// Room at the header's end for the dismiss button.
  final double reserveEnd;

  @override
  Widget build(BuildContext context) {
    final pad = style.padding!;
    final header = _header();
    final actions = _actions();
    final content = card.child == null
        ? null
        : DefaultTextStyle(style: style.contentStyle!, child: card.child!);

    if (card.variant == CoilCardVariant.inline) {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: card.media == null ? 0 : 160),
        child: Row(
          children: [
            if (card.media case final media?)
              SizedBox.square(dimension: 160, child: media),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: Row(
                  spacing: 12,
                  children: [
                    if (card.icon case final icon? when card.media == null)
                      _Tile(style: style, metrics: metrics, child: icon),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 12,
                        children: [?header, ?content],
                      ),
                    ),
                    ?actions,
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final text = EdgeInsets.symmetric(horizontal: pad);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (card.media case final media?)
          AspectRatio(aspectRatio: 16 / 9, child: media),
        SizedBox(height: pad),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            if (card.icon case final icon?)
              Padding(
                padding: text,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _Tile(style: style, metrics: metrics, child: icon),
                ),
              ),
            if (header != null) Padding(padding: text, child: header),
            if (content != null) Padding(padding: text, child: content),
            if (actions != null)
              // Compact ghost buttons pad their labels; starting the row
              // closer to the edge by that padding lines the labels up
              // with the title.
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: (pad - _compact.buttonPaddingX).clamp(0, pad),
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: actions,
                ),
              ),
          ],
        ),
        SizedBox(height: pad),
      ],
    );
  }

  CoilMetrics get _compact =>
      const CoilMetricsTable().resolve(metrics.tier, CoilSize.compact);

  Widget? _header() {
    if (card.title == null && card.description == null) return null;
    return Padding(
      padding: EdgeInsetsDirectional.only(end: reserveEnd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          if (card.title case final title?)
            DefaultTextStyle(style: style.titleStyle!, child: title),
          if (card.description case final description?)
            DefaultTextStyle(
              style: style.descriptionStyle!,
              child: description,
            ),
        ],
      ),
    );
  }

  Widget? _actions() {
    if (card.actions.isEmpty) return null;
    return CoilAdaptiveScope(
      size: CoilSize.compact,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: card.actions,
      ),
    );
  }
}

/// The tinted tile behind a card's icon.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.style,
    required this.metrics,
    required this.child,
  });

  final CoilCardStyle style;
  final CoilMetrics metrics;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: style.tile,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(
              CoilTheme.radiiOf(context).item,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: IconTheme(
            data: IconThemeData(
              size: metrics.iconSize,
              applyTextScaling: true,
              color: style.titleStyle!.color,
            ),
            child: Center(widthFactor: 1, heightFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}

/// The dismiss ✕: a compact ghost icon button that fades in and out.
class _DismissButton extends StatelessWidget {
  const _DismissButton({
    required this.visible,
    required this.icon,
    required this.label,
    required this.motion,
    required this.onPressed,
  });

  final bool visible;
  final Widget? icon;
  final String label;
  final CoilMotion motion;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return MotionOpacity(
      opacity: visible ? 1 : 0,
      motion: visible ? motion.fade : motion.fadeExit,
      debugLabel: 'CoilCard dismiss',
      // Screen readers always reach it.
      alwaysIncludeSemantics: true,
      // Hidden, it stays focusable (focus reveals it) but never takes a
      // tap meant for the card.
      child: IgnorePointer(
        ignoring: !visible,
        child: CoilButton.icon(
          onPressed: onPressed,
          variant: CoilButtonVariant.ghost,
          size: CoilSize.compact,
          semanticLabel: label,
          icon: icon ?? const _Cross(),
        ),
      ),
    );
  }
}

/// The default ✕, drawn in the [IconTheme]'s size and color.
class _Cross extends StatelessWidget {
  const _Cross();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(CoilIconSize.of(context)),
    painter: _CrossPainter(
      IconTheme.of(context).color ?? const Color(0xFF000000),
    ),
  );
}

class _CrossPainter extends CustomPainter {
  _CrossPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.drawPath(
      Path()
        ..moveTo(7 * s, 7 * s)
        ..lineTo(17 * s, 17 * s)
        ..moveTo(17 * s, 7 * s)
        ..lineTo(7 * s, 17 * s),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.color != color;
}

/// The dismiss exit: the card blur-fades while its height collapses on
/// `standard`. [onStatus] hears when the collapse ends.
class _DismissExit extends StatelessWidget {
  const _DismissExit({
    required this.dismissing,
    required this.motion,
    required this.onStatus,
    required this.child,
  });

  final bool dismissing;
  final CoilMotion motion;
  final ValueChanged<AnimationStatus> onStatus;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SingleMotionBuilder(
      value: dismissing ? 0 : 1,
      motion: motion.standard,
      onAnimationStatusChanged: onStatus,
      debugLabel: 'CoilCard dismiss height',
      builder: (context, height, child) => ClipRect(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          heightFactor: height.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: MotionSwitcher(
        motion: motion.fade,
        exitMotion: motion.fadeExit,
        debugLabel: 'CoilCard dismiss fade',
        // Reduced motion keeps the fade and drops the blur and scale.
        transitionBuilder: CoilBlurFade.transition(
          blur: reduced ? 0 : 4,
          scale: reduced ? 1 : 0.96,
        ),
        // The leaving card keeps its size, so the height collapses from it.
        layoutBuilder: (current, previous) => Stack(
          children: [...previous, ?current],
        ),
        child: dismissing
            ? null
            : KeyedSubtree(key: const ValueKey('card'), child: child),
      ),
    );
  }
}

/// Tells a [CoilCard] which cell of a [CoilCardGroup] it is in.
class _CardSlot extends InheritedWidget {
  const _CardSlot({required this.index, required super.child});

  final int index;

  static _CardSlot? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CardSlot>();

  @override
  bool updateShouldNotify(_CardSlot oldWidget) => oldWidget.index != index;
}

/// Lays out [CoilCard]s as one divided block or as separate cards, in
/// [columns], with one hover highlight gliding between the cards that have
/// an action.
class CoilCardGroup extends StatefulWidget {
  /// Creates a card group.
  const CoilCardGroup({
    required this.children,
    super.key,
    this.layout = CoilCardGroupLayout.divided,
    this.columns = 1,
    this.size,
    this.style,
  }) : assert(columns > 0, 'A group needs at least one column');

  /// The cards, in reading order.
  final List<Widget> children;

  /// Divided into one block, or separated.
  final CoilCardGroupLayout layout;

  /// How many cards per row.
  final int columns;

  /// Pins the group to one size step.
  final CoilSize? size;

  /// Overrides for the group's look, on top of the theme's [CoilCardStyle]
  /// and the defaults.
  final CoilCardStyle? style;

  @override
  State<CoilCardGroup> createState() => _CoilCardGroupState();
}

class _CoilCardGroupState extends State<CoilCardGroup> {
  final _surfaces = _SurfacePainter();

  @override
  void dispose() {
    _surfaces.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final style = CoilCardStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilCardStyle>(context)).merge(widget.style);
    final separated = widget.layout == CoilCardGroupLayout.separated;
    final columns = widget.columns;
    final count = widget.children.length;
    final rowCount = (count / columns).ceil();
    final gap = separated ? style.spacing! : 0.0;
    final radius = BorderRadius.circular(style.radius!);
    final surface = ShapeDecoration(
      color: style.surface,
      shadows: style.shadows,
      shape: RoundedSuperellipseBorder(
        borderRadius: radius,
        side: style.border!,
      ),
    );
    _surfaces.update(separated ? surface : null, count);

    Widget cell(int index) {
      final row = index ~/ columns;
      final column = index % columns;
      final card = _CardSlot(index: index, child: widget.children[index]);
      if (separated) return card;
      return _Divider(
        index: index,
        below: row < rowCount - 1 && index + columns < count
            ? index + columns
            : null,
        after: column < columns - 1 && index + 1 < count ? index + 1 : null,
        color: style.divider!,
        child: card,
      );
    }

    Widget grid = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        for (var row = 0; row < rowCount; row++)
          if (columns == 1)
            cell(row)
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: gap,
                children: [
                  for (var column = 0; column < columns; column++)
                    Expanded(
                      child: row * columns + column < count
                          ? cell(row * columns + column)
                          : const SizedBox(),
                    ),
                ],
              ),
            ),
      ],
    );

    grid = CoilHoverRegion(
      axis: CoilHoverAxis.xy,
      child: CoilHoverHighlight(
        color: style.highlight,
        radius: style.radius,
        background: [_surfaces],
        child: grid,
      ),
    );

    if (!separated) {
      grid = DecoratedBox(
        decoration: surface,
        child: ClipRSuperellipse(borderRadius: radius, child: grid),
      );
    }
    return CoilAdaptiveScope(size: widget.size, child: grid);
  }
}

/// The hairlines below and after one card of a divided group. They hide
/// next to the lit card, so the highlight reads as one shape.
class _Divider extends StatelessWidget {
  const _Divider({
    required this.index,
    required this.below,
    required this.after,
    required this.color,
    required this.child,
  });

  final int index;
  final int? below;
  final int? after;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lit = CoilHoverRegion.maybeOf(context)?.activeIndex;
    BorderSide side(int? neighbor) =>
        neighbor == null || lit == index || lit == neighbor
        ? BorderSide.none
        : BorderSide(color: color);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(bottom: side(below), end: side(after)),
      ),
      child: child,
    );
  }
}

/// Paints the surface of every card of a separated group under the group's
/// highlight, so the highlight shows on the card it lights.
class _SurfacePainter extends CoilLayerPainter {
  Decoration? _decoration;
  BoxPainter? _painter;
  int _count = 0;

  void update(Decoration? decoration, int count) {
    if (decoration == _decoration && count == _count) return;
    if (decoration != _decoration) {
      _painter?.dispose();
      _painter = null;
      _decoration = decoration;
    }
    _count = count;
    notifyListeners();
  }

  @override
  void paint(Canvas canvas, Offset offset, CoilLayerGeometry geometry) {
    final decoration = _decoration;
    if (decoration == null) return;
    final painter = _painter ??= decoration.createBoxPainter(notifyListeners);
    for (var i = 0; i < _count; i++) {
      final rect = geometry.rectOf(i);
      if (rect == null || rect.isEmpty) continue;
      painter.paint(
        canvas,
        rect.topLeft + offset,
        ImageConfiguration(size: rect.size, textDirection: TextDirection.ltr),
      );
    }
  }

  @override
  void dispose() {
    _painter?.dispose();
    super.dispose();
  }
}
