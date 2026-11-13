import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/slider/slider_painters.dart';
import 'package:coil/src/components/slider/slider_scale.dart';
import 'package:coil/src/components/slider/slider_shortcuts.dart';
import 'package:coil/src/components/slider/slider_style.dart';
import 'package:coil/src/components/slider/slider_visuals.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilSlider], as Motor tracks. Use them as keys
/// of [CoilSlider.motions] or [CoilThemeData.trackMotions].
///
/// A custom motion replaces both the enter and the exit of its part.
final class CoilSliderTrack<T extends Object> extends Track<T> {
  CoilSliderTrack._(super.converter, {required String super.debugLabel});

  /// The thumb and fill settling after a jump, a key or a release. While
  /// dragging they follow the value directly. Default motion: `standard`.
  static final thumb = CoilSliderTrack<double>._(
    .single,
    debugLabel: 'CoilSlider.thumb',
  );

  /// The hover preview following the pointer. Default motion: `quick`.
  static final preview = CoilSliderTrack<double>._(
    .single,
    debugLabel: 'CoilSlider.preview',
  );

  /// The preview bar's opacity. Default motion: `fade`.
  static final previewOpacity = CoilSliderTrack<double>._(
    .single,
    debugLabel: 'CoilSlider.previewOpacity',
  );

  /// The value bubble's opacity. Default motion: `fade`.
  static final bubble = CoilSliderTrack<double>._(
    .single,
    debugLabel: 'CoilSlider.bubble',
  );

  /// The handle line's color. Default motion: `fade`.
  static final handle = CoilSliderTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilSlider.handle',
  );

  /// The label and value turning foreground and semibold, and the handle
  /// growing. Default motion: `fade`.
  static final emphasis = CoilSliderTrack<double>._(
    .single,
    debugLabel: 'CoilSlider.emphasis',
  );
}

/// How a [CoilSlider] draws its track.
enum CoilSliderVariant {
  /// A full-width row with a continuous fill and a handle line.
  scrubber,

  /// Like [scrubber], plus a dot at every step. Needs
  /// [CoilSlider.divisions].
  pips,

  /// A thin pill track with a knob, between the label and the value.
  pill,
}

/// A slider for one value between [min] and [max].
///
/// The slider is controlled: it shows [value] and asks for changes through
/// [onChanged].
///
/// Dragging moves the value with the pointer and never coasts. A tap jumps.
/// A pointer that hovers previews the value under it. A touch shows the
/// value above the thumb.
///
/// Arrows step by one division, or 1 % without [divisions]. Shift+arrow,
/// Page Up and Page Down step 10 %. Home and End go to [min] and [max].
/// Left and right follow the reading direction.
///
/// The animated parts are [CoilSliderTrack]s; override them with [motions].
class CoilSlider extends StatefulWidget {
  /// Creates a slider.
  const CoilSlider({
    required this.value,
    required this.onChanged,
    super.key,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.label,
    this.valueFormatter,
    this.variant = CoilSliderVariant.scrubber,
    this.size,
    this.focusNode,
    this.autofocus = false,
    this.statesController,
    this.motion,
    this.motions,
    this.style,
    this.semanticLabel,
  }) : assert(min < max, 'min must be less than max'),
       assert(
         divisions == null || divisions > 0,
         'divisions must be positive',
       ),
       assert(
         variant != CoilSliderVariant.pips || divisions != null,
         'pips need divisions',
       );

  /// The current value, between [min] and [max].
  final double value;

  /// Called with the new value, snapped to [divisions]. Null disables the
  /// slider.
  final ValueChanged<double>? onChanged;

  /// The smallest value.
  final double min;

  /// The largest value.
  final double max;

  /// How many equal steps [min]..[max] is split into. Null is continuous.
  final int? divisions;

  /// Called with the current value when a change starts: a drag, a tap, a
  /// key or a screen reader action.
  final ValueChanged<double>? onChangeStart;

  /// Called with the new value when that change ends.
  final ValueChanged<double>? onChangeEnd;

  /// The text before the track. It is built once, so a [GlobalKey] on it is
  /// safe.
  final Widget? label;

  /// Formats the value for the row, the bubble and screen readers. The
  /// default shows up to two decimals without trailing zeros, with a `.`
  /// decimal mark; it isn't localized.
  final String Function(double value)? valueFormatter;

  /// How the track looks.
  final CoilSliderVariant variant;

  /// Pins the slider to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// The focus node.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// Observes, and can force, hover/focus/press states.
  final WidgetStatesController? statesController;

  /// Overrides the theme's motion tokens ([CoilThemeData.motion]) for this
  /// instance.
  final CoilMotion? motion;

  /// Per-part motions for this instance, keyed by [CoilSliderTrack]s.
  final Map<CoilSliderTrack<Object>, Motion>? motions;

  /// Overrides for this slider's look.
  final CoilSliderStyle? style;

  /// A label for assistive technology when [label] is not plain text.
  final String? semanticLabel;

  @override
  State<CoilSlider> createState() => _CoilSliderState();
}

class _CoilSliderState extends State<CoilSlider>
    with SingleTickerProviderStateMixin {
  /// The thumb: dragging sets it, everything else springs it.
  late final _controller = TrackController(
    vsync: this,
    debugLabel: 'CoilSlider',
  );

  /// The thumb's fraction, read by the track paint while painting.
  double _thumbFraction() => _controller.value(CoilSliderTrack.thumb);

  /// The fraction under a hovering pointer, null when there is none.
  final _hover = ValueNotifier<double?>(null);

  WidgetStatesController? _ownStates;
  WidgetStatesController get _states =>
      widget.statesController ?? (_ownStates ??= WidgetStatesController());

  late final FocusNode _ownFocus = FocusNode(debugLabel: 'CoilSlider');
  FocusNode get _focusNode => widget.focusNode ?? _ownFocus;

  bool _dragging = false;
  PointerDeviceKind _kind = PointerDeviceKind.mouse;
  double _downFraction = 0;

  bool get _enabled => widget.onChanged != null;
  bool get _compactTrack => widget.variant == CoilSliderVariant.pill;

  SliderScale get _scale => SliderScale(
    min: widget.min,
    max: widget.max,
    divisions: widget.divisions,
  );

  /// The motions of one part: a custom one replaces enter and exit.
  ({Motion enter, Motion exit}) _motionFor(
    CoilSliderTrack<Object> track,
    CoilMotion tokens,
  ) {
    final (enter, exit, spatial) = switch (track) {
      _ when track == CoilSliderTrack.thumb => (
        tokens.standard,
        tokens.standardExit,
        true,
      ),
      _ when track == CoilSliderTrack.preview => (
        tokens.quick,
        tokens.quickExit,
        true,
      ),
      _ => (tokens.fade, tokens.fadeExit, false),
    };
    final resolved = CoilTheme.trackMotionOf(
      context,
      track,
      instance: widget.motions,
      token: enter,
      spatial: spatial,
    );
    return identical(resolved, enter)
        ? (enter: enter, exit: exit)
        : (enter: resolved, exit: resolved);
  }

  CoilMotion get _tokens =>
      CoilTheme.motionOf(context, override: widget.motion);

  String _format(double v) {
    final custom = widget.valueFormatter;
    if (custom != null) return custom(v);
    final fixed = v.toStringAsFixed(2);
    return fixed.contains('.')
        ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
        : fixed;
  }

  @override
  void initState() {
    super.initState();
    _controller.set([CoilSliderTrack.thumb.value(_scale.norm(widget.value))]);
    _states.addListener(_forgetHover);
  }

  void _forgetHover() {
    if (!_states.value.contains(WidgetState.hovered)) _hover.value = null;
  }

  @override
  void didUpdateWidget(CoilSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statesController != widget.statesController) {
      (oldWidget.statesController ?? _ownStates)?.removeListener(_forgetHover);
      _states.addListener(_forgetHover);
    }
    final to = _scale.norm(widget.value);
    if (_controller.value(CoilSliderTrack.thumb) == to) return;
    if (_dragging) {
      // The thumb shows the value, which the pointer changed through the
      // parent: follow it directly.
      _controller.set([CoilSliderTrack.thumb.value(to)]);
    } else {
      _controller.animate([
        CoilSliderTrack.thumb([
          .to(to, motion: _motionFor(CoilSliderTrack.thumb, _tokens).enter),
        ]),
      ]);
    }
  }

  @override
  void dispose() {
    _states.removeListener(_forgetHover);
    _ownStates?.dispose();
    _ownFocus.dispose();
    _hover.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ---- changes ---------------------------------------------------------

  /// A whole change that isn't a drag: tap, key or screen reader action.
  void _change(double to) {
    final next = _scale.snap(to);
    widget.onChangeStart?.call(widget.value);
    if (next != widget.value) widget.onChanged?.call(next);
    widget.onChangeEnd?.call(next);
  }

  void _dragStart(DragStartDetails d, double width, SliderReach reach) {
    _dragging = true;
    setState(() {});
    widget.onChangeStart?.call(widget.value);
    _dragTo(d.localPosition.dx, width, reach);
  }

  void _dragTo(double dx, double width, SliderReach reach) {
    final f = reach.fractionAt(dx, width, rtl: _rtl);
    final value = _scale.valueAt(f);
    if (value != widget.value) widget.onChanged?.call(value);
  }

  void _dragEnd() {
    if (!_dragging) return;
    _dragging = false;
    setState(() {});
    widget.onChangeEnd?.call(widget.value);
  }

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  void _step(SliderStepIntent intent) {
    if (!_enabled) return;
    final delta = intent.page ? _scale.page : _scale.step;
    _change(widget.value + intent.steps * delta);
  }

  void _end(SliderEndIntent intent) {
    if (!_enabled) return;
    _change(intent.max ? widget.max : widget.min);
  }

  // ---- build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final style = CoilSliderStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilSliderStyle>(context)).merge(widget.style);
    final rtl = _rtl;
    final scale = _scale;
    final value = widget.value.clamp(widget.min, widget.max);
    final reach = SliderReach(switch (widget.variant) {
      CoilSliderVariant.scrubber => 0,
      CoilSliderVariant.pips => metrics.controlPaddingX,
      CoilSliderVariant.pill => style.knobBox! / 2,
    });

    return Semantics(
      container: true,
      slider: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      value: _format(value),
      increasedValue: _format(scale.snap(value + scale.step)),
      decreasedValue: _format(scale.snap(value - scale.step)),
      onIncrease: _enabled ? () => _step(const SliderStepIntent(1)) : null,
      onDecrease: _enabled ? () => _step(const SliderStepIntent(-1)) : null,
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        shortcuts: sliderShortcuts(rtl: rtl),
        actions: {
          SliderStepIntent: CallbackAction<SliderStepIntent>(onInvoke: _step),
          SliderEndIntent: CallbackAction<SliderEndIntent>(onInvoke: _end),
        },
        child: CoilInteractionDetector(
          states: _states,
          enabled: _enabled,
          focusNode: _focusNode,
          // A tap jumps to where the pointer went down.
          onTap: () => _change(_scale.valueAt(_downFraction)),
          cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: Opacity(
            opacity: _enabled ? 1 : metrics.disabledOpacity,
            child: ListenableBuilder(
              listenable: _states,
              builder: (context, _) => _buildVisuals(
                theme: theme,
                metrics: metrics,
                style: style,
                reach: reach,
                value: value,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisuals({
    required CoilThemeData theme,
    required CoilMetrics metrics,
    required CoilSliderStyle style,
    required SliderReach reach,
    required double value,
  }) {
    final states = _states.value;
    final tokens = _tokens;
    final rtl = _rtl;
    final scale = _scale;
    final pressed = states.contains(WidgetState.pressed) || _dragging;
    final hovered = states.contains(WidgetState.hovered);
    final active = hovered || pressed || states.contains(WidgetState.focused);
    final visualStates = {
      if (hovered) WidgetState.hovered,
      if (pressed) WidgetState.pressed,
      if (states.contains(WidgetState.focused)) WidgetState.focused,
    };

    final preview = _motionFor(CoilSliderTrack.preview, tokens);
    final previewOpacity = _motionFor(CoilSliderTrack.previewOpacity, tokens);
    final bubble = _motionFor(CoilSliderTrack.bubble, tokens);
    final handle = _motionFor(CoilSliderTrack.handle, tokens);
    final emphasis = _motionFor(CoilSliderTrack.emphasis, tokens);
    // Retarget only what changed; a fade out uses the exit spring.
    Motion pick(({Motion enter, Motion exit}) m, {required bool entering}) =>
        entering ? m.enter : m.exit;

    final thumbAt = scale.norm(widget.value);
    return ValueListenableBuilder<double?>(
      valueListenable: _hover,
      builder: (context, hovering, _) {
        final pointed = hovering != null;
        final showPreview = _enabled && hovered && pointed && !pressed;
        final showBubble =
            _enabled &&
            ((hovered && pointed) ||
                (pressed && _kind != PointerDeviceKind.mouse));
        return TrackBuilder(
          animations: [
            CoilSliderTrack.preview([
              .to(hovering ?? thumbAt, motion: preview.enter),
            ]),
            CoilSliderTrack.previewOpacity([
              .to(
                showPreview ? 1 : 0,
                motion: pick(previewOpacity, entering: showPreview),
              ),
            ]),
            CoilSliderTrack.bubble([
              .to(
                showBubble ? 1 : 0,
                motion: pick(bubble, entering: showBubble),
              ),
            ]),
            CoilSliderTrack.handle([
              .to(style.handle!.resolve(visualStates)!, motion: handle.enter),
            ]),
            CoilSliderTrack.emphasis([
              .to(active ? 1 : 0, motion: pick(emphasis, entering: active)),
            ]),
          ],
          builder: (context, v, _) {
            final e = v(CoilSliderTrack.emphasis).clamp(0.0, 1.0);
            final paint = SliderPaintState(
              reach: reach,
              rtl: rtl,
              previewFraction: v(CoilSliderTrack.preview),
              previewOpacity: v(CoilSliderTrack.previewOpacity).clamp(0.0, 1.0),
              previewColor: style.preview!,
            );
            final labelColor = Color.lerp(
              style.label!.resolve({}),
              style.label!.resolve({WidgetState.hovered}),
              e,
            )!;
            final valueColor = Color.lerp(
              style.value!.resolve({}),
              style.value!.resolve({WidgetState.hovered}),
              e,
            )!;
            final reserve = {
              _format(widget.min),
              _format(widget.max),
              _format(value),
            };
            final pill = _compactTrack;
            final pillPaint = !pill
                ? null
                : SliderPillPaint(
                    thumb: _controller,
                    fraction: _thumbFraction,
                    state: paint,
                    fill: style.pillFill!,
                    border: style.border!,
                    height: style.pillHeight!,
                  );
            final rowPaint = pill
                ? null
                : SliderRowPaint(
                    thumb: _controller,
                    fraction: _thumbFraction,
                    state: paint,
                    fill: style.fill!,
                    handle: v(CoilSliderTrack.handle),
                    emphasis: e,
                    handleWidth: style.handleWidth!,
                    handleInset: style.handleInset!,
                    divisions: widget.variant == CoilSliderVariant.pips
                        ? widget.divisions
                        : null,
                    pipSize: style.pipSize!,
                    pipGrowth: style.pipGrowth!,
                    pip: style.pip!,
                    activePip: style.activePip!,
                  );

            final bubbleText = _format(
              pressed ? value : scale.valueAt(hovering ?? thumbAt),
            );

            final radius = pill
                ? BorderRadius.circular(style.pillHeight! / 2)
                : BorderRadius.circular(style.radius!);
            final Widget body = pill
                ? SliderPill(
                    painter: pillPaint!,
                    style: style,
                    metrics: metrics,
                    label: widget.label,
                    valueText: _format(value),
                    reserve: reserve,
                    labelColor: labelColor,
                    valueColor: valueColor,
                    emphasis: e,
                    thumb: _controller,
                    thumbFraction: () =>
                        _controller.value(CoilSliderTrack.thumb),
                    track: (track) => CoilFocusRing(
                      visible: states.contains(WidgetState.focused),
                      borderRadius: radius,
                      offset: 2,
                      child: _gestures(track, reach),
                    ),
                  )
                : CoilFocusRing(
                    visible: states.contains(WidgetState.focused),
                    borderRadius: radius,
                    offset: 2,
                    child: _gestures(
                      DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: RoundedSuperellipseBorder(
                            borderRadius: radius,
                            side: BorderSide(color: style.border!),
                          ),
                        ),
                        child: SliderRow(
                          painter: rowPaint!,
                          style: style,
                          metrics: metrics,
                          label: widget.label,
                          valueText: _format(value),
                          reserve: reserve,
                          labelColor: labelColor,
                          valueColor: valueColor,
                          emphasis: e,
                        ),
                      ),
                      reach,
                    ),
                  );
            return Stack(
              clipBehavior: Clip.none,
              children: [
                body,
                // The bubble tracks the thumb while it moves.
                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => SliderBubble(
                    style: style,
                    fraction: pressed
                        ? _controller.value(CoilSliderTrack.thumb)
                        : v(CoilSliderTrack.preview),
                    reach: reach,
                    rtl: rtl,
                    opacity: v(CoilSliderTrack.bubble),
                    text: bubbleText,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Maps pointer events on [track] to values.
  Widget _gestures(Widget track, SliderReach reach) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Listener(
          onPointerDown: (e) {
            _kind = e.kind;
            _downFraction = reach.fractionAt(
              e.localPosition.dx,
              width,
              rtl: _rtl,
            );
          },
          onPointerHover: (e) {
            if (!_enabled || !CoilInputModality.canHover(e.kind)) return;
            _hover.value = _scale.norm(
              _scale.valueAt(
                reach.fractionAt(e.localPosition.dx, width, rtl: _rtl),
              ),
            );
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onHorizontalDragStart: _enabled
                ? (d) => _dragStart(d, width, reach)
                : null,
            onHorizontalDragUpdate: _enabled
                ? (d) => _dragTo(d.localPosition.dx, width, reach)
                : null,
            onHorizontalDragEnd: _enabled ? (_) => _dragEnd() : null,
            onHorizontalDragCancel: _enabled ? _dragEnd : null,
            child: track,
          ),
        );
      },
    );
  }
}
