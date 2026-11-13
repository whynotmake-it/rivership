// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/slider/slider_style.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilSlider], as Motor tracks. Use them as keys
/// of [CoilSlider.motions] or [CoilThemeData.trackMotions].
final class CoilSliderTrack<T extends Object> extends Track<T> {
  CoilSliderTrack._(super.converter, {required String super.debugLabel});

  /// Where the thumb and fill are, 0 (min) to 1 (max). Dragging sets it
  /// directly; a jump, a key step or a release springs it. Default motion:
  /// `standard`.
  static final thumb = CoilSliderTrack<double>._(
    .single,
    debugLabel: 'CoilSlider.thumb',
  );

  /// Where the hover preview is, 0 to 1. Default motion: `quick`.
  static final preview = CoilSliderTrack<double>._(
    .single,
    debugLabel: 'CoilSlider.preview',
  );

  /// The preview bar's opacity, 0 to 1. Default motion: `fade`.
  static final previewOpacity = CoilSliderTrack<double>._(
    .single,
    debugLabel: 'CoilSlider.previewOpacity',
  );

  /// The value bubble's opacity, 0 to 1. Default motion: `fade`.
  static final bubble = CoilSliderTrack<double>._(
    .single,
    debugLabel: 'CoilSlider.bubble',
  );
}

/// How a [CoilSlider] draws its comfortable row.
enum CoilSliderVariant {
  /// A continuous fill with a handle line at the value.
  scrubber,

  /// Like [scrubber], plus a dot at every step. Needs
  /// [CoilSlider.divisions].
  pips,
}

/// A slider for one value (DESIGN.md §14.2).
///
/// * **Regular** size: a full-width bordered row with the [label] at the
///   start, the value at the end, a fill up to the value and a handle line.
/// * **Compact** size: an 18 high pill track with a knob.
///
/// Dragging sets the value directly: the thumb follows the pointer 1:1
/// ([TrackController.set]) and the value never coasts. A tap jumps. A jump,
/// a key step and a release settle on `standard`. Pointers that hover show
/// a preview bar and a value bubble at the snapped hover value; a touch
/// shows the bubble above the thumb while it is down.
///
/// Keys: arrows ±one step (a step is `(max - min) / divisions`, or 1 % of
/// the range), Shift+arrow and PageUp/PageDown ±10 %, Home and End go to
/// [min] and [max]. Left and right follow the reading direction.
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

  /// Called with the new value (snapped to [divisions]) while the user
  /// drags, taps or presses keys. Null disables the slider.
  final ValueChanged<double>? onChanged;

  /// The smallest value.
  final double min;

  /// The largest value.
  final double max;

  /// How many equal steps [min]..[max] is split into. Null is continuous.
  final int? divisions;

  /// Called when a drag starts, with the value then.
  final ValueChanged<double>? onChangeStart;

  /// Called when a drag ends, with the final value.
  final ValueChanged<double>? onChangeEnd;

  /// The text before the track (inside the row when regular). Muted until
  /// the slider is hovered, pressed or focused.
  final Widget? label;

  /// Formats the value for the display, the bubble and assistive
  /// technology. The default trims trailing zeros of two decimals.
  final String Function(double value)? valueFormatter;

  /// How the regular row draws its track.
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

  /// Per-track motions for this instance, keyed by [CoilSliderTrack]s.
  final Map<CoilSliderTrack<Object>, Motion>? motions;

  /// Overrides for this slider's look.
  final CoilSliderStyle? style;

  /// A label for assistive technology when [label] is not plain text.
  final String? semanticLabel;

  @override
  State<CoilSlider> createState() => _CoilSliderState();
}

class _StepIntent extends Intent {
  const _StepIntent(this.steps, {this.page = false});

  /// Signed: positive increases.
  final int steps;

  /// Whether this is a 10 % step.
  final bool page;
}

class _EndIntent extends Intent {
  const _EndIntent({required this.max});

  final bool max;
}

/// The reach of the handle line from the row's ends.
const _handleInset = 5.0;

class _CoilSliderState extends State<CoilSlider>
    with SingleTickerProviderStateMixin {
  CoilMotion get _motion =>
      CoilTheme.motionOf(context, override: widget.motion);

  late final _controller = TrackController(
    vsync: this,
    debugLabel: 'CoilSlider',
  );

  final _thumb = CoilSliderTrack.thumb;
  final _preview = CoilSliderTrack.preview;
  final _previewOpacity = CoilSliderTrack.previewOpacity;
  final _bubble = CoilSliderTrack.bubble;

  Motion _motionFor(CoilSliderTrack<Object> track, Motion token) =>
      CoilTheme.trackMotionOf(
        context,
        track,
        instance: widget.motions,
        token: token,
        spatial:
            track == CoilSliderTrack.thumb || track == CoilSliderTrack.preview,
      );

  WidgetStatesController? _ownStates;
  WidgetStatesController get _states =>
      widget.statesController ?? (_ownStates ??= WidgetStatesController());

  late final FocusNode _ownFocus = FocusNode(debugLabel: 'CoilSlider');
  FocusNode get _focusNode => widget.focusNode ?? _ownFocus;

  bool _dragging = false;
  PointerDeviceKind _lastKind = PointerDeviceKind.mouse;
  double _hoverValue = 0;
  double _thumbTarget = 0;
  double _previewTarget = -1;
  double _previewOpacityTarget = 0;
  double _bubbleTarget = 0;

  bool get _enabled => widget.onChanged != null;
  double get _range => widget.max - widget.min;

  double _norm(double v) => ((v - widget.min) / _range).clamp(0.0, 1.0);

  /// Snaps [v] into range and onto [CoilSlider.divisions].
  double _snap(double v) {
    final clamped = v.clamp(widget.min, widget.max);
    final n = widget.divisions;
    if (n == null) return clamped;
    final step = _range / n;
    return (widget.min + ((clamped - widget.min) / step).round() * step).clamp(
      widget.min,
      widget.max,
    );
  }

  double get _step => _range / (widget.divisions ?? 100);

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
    _thumbTarget = _norm(widget.value);
    _controller.set([
      _thumb.value(_thumbTarget),
      _preview.value(0),
      _previewOpacity.value(0),
      _bubble.value(0),
    ]);
    _states.addListener(_onStates);
  }

  @override
  void didUpdateWidget(CoilSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statesController != widget.statesController) {
      (oldWidget.statesController ?? _ownStates)?.removeListener(_onStates);
      _states.addListener(_onStates);
    }
    if (!_dragging) _settle();
    _syncOverlays();
  }

  @override
  void dispose() {
    _states.removeListener(_onStates);
    _ownStates?.dispose();
    _ownFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onStates() {
    // The interaction detector writes its first states while building.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncOverlays();
      });
    } else {
      _syncOverlays();
    }
  }

  /// Springs the thumb to the controlled value, unless it is already
  /// headed there.
  void _settle() {
    final to = _norm(widget.value);
    if (to == _thumbTarget) return;
    _thumbTarget = to;
    _controller.animate([
      _thumb([.to(to, motion: _motionFor(_thumb, _motion.standard))]),
    ]);
  }

  bool get _hovering => _states.value.contains(WidgetState.hovered);
  bool get _pressed => _states.value.contains(WidgetState.pressed);

  /// Fades the preview and the bubble in or out for the current states.
  void _syncOverlays() {
    final preview = _enabled && _hovering && !_pressed ? 1.0 : 0.0;
    final bubble =
        _enabled &&
            (_hovering || (_pressed && _lastKind != PointerDeviceKind.mouse))
        ? 1.0
        : 0.0;
    final animations = [
      if (preview != _previewOpacityTarget)
        _previewOpacity([
          .to(preview, motion: _motionFor(_previewOpacity, _fadeFor(preview))),
        ]),
      if (bubble != _bubbleTarget)
        _bubble([
          .to(bubble, motion: _motionFor(_bubble, _fadeFor(bubble))),
        ]),
    ];
    _previewOpacityTarget = preview;
    _bubbleTarget = bubble;
    if (animations.isNotEmpty) _controller.animate(animations);
  }

  Motion _fadeFor(double target) =>
      target > 0 ? _motion.fade : _motion.fadeExit;

  void _setPressed(bool value) {
    if (value && !_enabled) return;
    _states.update(WidgetState.pressed, value);
  }

  // ---- values ----------------------------------------------------------

  /// Reports [v] (snapped) and springs the thumb to it.
  void _commit(double v, {bool animate = true}) {
    final snapped = _snap(v);
    if (snapped != widget.value) widget.onChanged?.call(snapped);
    if (!animate) return;
    final to = _norm(snapped);
    _thumbTarget = to;
    _controller.animate([
      _thumb([.to(to, motion: _motionFor(_thumb, _motion.standard))]),
    ]);
    // If the parent kept another value, come back to it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_dragging) _settle();
    });
  }

  /// The slider fraction (0 at the min end) for an x in the track box.
  double _fractionAt(double dx, double width) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final x = rtl ? width - dx : dx;
    final (start, end) = _reach(width);
    if (end <= start) return 0;
    return ((x - start) / (end - start)).clamp(0.0, 1.0);
  }

  /// The x range the value travels over in a [width] wide track box (in
  /// the min-to-max direction).
  (double, double) _reach(double width) {
    final compact = _compact;
    if (compact) {
      final box = _style.knobBox!;
      return (box / 2, math.max(box / 2, width - box / 2));
    }
    if (widget.variant == CoilSliderVariant.pips) {
      final pad = _metrics.controlPaddingX;
      return (pad, math.max(pad, width - pad));
    }
    return (0, width);
  }

  late CoilSliderStyle _style;
  late CoilMetrics _metrics;
  bool get _compact => _metrics.size == CoilSize.compact;

  void _dragStart(DragStartDetails d, double width) {
    if (!_enabled) return;
    _dragging = true;
    _setPressed(true);
    widget.onChangeStart?.call(widget.value);
    _dragTo(d.localPosition.dx, width);
  }

  void _dragTo(double dx, double width) {
    final fraction = _fractionAt(dx, width);
    _thumbTarget = fraction;
    _controller.set([_thumb.value(fraction)]);
    final value = _snap(widget.min + fraction * _range);
    if (value != widget.value) widget.onChanged?.call(value);
  }

  void _dragEnd() {
    if (!_dragging) return;
    _dragging = false;
    _setPressed(false);
    // No fling: the value never coasts; it only settles onto its step.
    final to = _norm(_snap(widget.min + _thumbTarget * _range));
    _thumbTarget = to;
    _controller.animate([
      _thumb([.to(to, motion: _motionFor(_thumb, _motion.standard))]),
    ]);
    widget.onChangeEnd?.call(_snap(widget.min + to * _range));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_dragging) _settle();
    });
  }

  void _tapUp(TapUpDetails d, double width) {
    _setPressed(false);
    if (!_enabled) return;
    final f = _fractionAt(d.localPosition.dx, width);
    _commit(widget.min + f * _range);
  }

  void _hover(PointerHoverEvent e, double width) {
    if (!_enabled || !CoilInputModality.canHover(e.kind)) return;
    final f = _fractionAt(e.localPosition.dx, width);
    final snapped = _snap(widget.min + f * _range);
    final at = _norm(snapped);
    if (snapped != _hoverValue) setState(() => _hoverValue = snapped);
    if (at == _previewTarget) return;
    final first = _previewTarget < 0 || _previewOpacityTarget == 0;
    _previewTarget = at;
    if (first) {
      _controller.set([_preview.value(at)]);
    } else {
      _controller.animate([
        _preview([.to(at, motion: _motionFor(_preview, _motion.quick))]),
      ]);
    }
  }

  void _key(_StepIntent intent) {
    if (!_enabled) return;
    final delta = intent.page ? math.max(_range / 10, _step) : _step;
    _commit(widget.value + intent.steps * delta);
  }

  void _end(_EndIntent intent) {
    if (!_enabled) return;
    _commit(intent.max ? widget.max : widget.min);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    _metrics = CoilTheme.metricsOf(context, size: widget.size);
    _style = CoilSliderStyle.fallback(
      theme,
      _metrics,
    ).merge(CoilTheme.styleOf<CoilSliderStyle>(context)).merge(widget.style);
    final style = _style;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final value = widget.value.clamp(widget.min, widget.max);
    final compact = _compact;

    final label = widget.label;

    final shortcuts = <ShortcutActivator, Intent>{
      SingleActivator(
        rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight,
      ): const _StepIntent(
        1,
      ),
      SingleActivator(
        rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft,
      ): const _StepIntent(
        -1,
      ),
      const SingleActivator(LogicalKeyboardKey.arrowUp): const _StepIntent(1),
      const SingleActivator(LogicalKeyboardKey.arrowDown): const _StepIntent(
        -1,
      ),
      SingleActivator(
        rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight,
        shift: true,
      ): const _StepIntent(
        1,
        page: true,
      ),
      SingleActivator(
        rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft,
        shift: true,
      ): const _StepIntent(
        -1,
        page: true,
      ),
      const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
          const _StepIntent(1, page: true),
      const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
          const _StepIntent(-1, page: true),
      const SingleActivator(LogicalKeyboardKey.pageUp): const _StepIntent(
        1,
        page: true,
      ),
      const SingleActivator(LogicalKeyboardKey.pageDown): const _StepIntent(
        -1,
        page: true,
      ),
      const SingleActivator(LogicalKeyboardKey.home): const _EndIntent(
        max: false,
      ),
      const SingleActivator(LogicalKeyboardKey.end): const _EndIntent(
        max: true,
      ),
    };

    return MotorInspectionScope(
      group: 'CoilSlider',
      child: Semantics(
        container: true,
        slider: true,
        enabled: _enabled,
        label: widget.semanticLabel,
        value: _format(value),
        increasedValue: _format(_snap(value + _step)),
        decreasedValue: _format(_snap(value - _step)),
        onIncrease: _enabled ? () => _key(const _StepIntent(1)) : null,
        onDecrease: _enabled ? () => _key(const _StepIntent(-1)) : null,
        child: FocusableActionDetector(
          enabled: _enabled,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          shortcuts: shortcuts,
          actions: {
            _StepIntent: CallbackAction<_StepIntent>(onInvoke: _key),
            _EndIntent: CallbackAction<_EndIntent>(onInvoke: _end),
          },
          child: CoilInteractionDetector(
            states: _states,
            enabled: _enabled,
            focusNode: _focusNode,
            trackPress: false,
            cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
            child: Opacity(
              opacity: _enabled ? 1 : 0.5,
              child: ListenableBuilder(
                listenable: _states,
                builder: (context, _) => compact
                    ? _buildCompact(theme, style, value, label)
                    : _buildRegular(theme, style, value, label),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Wraps [track] with the gesture and hover handling.
  Widget _gestures(Widget track) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Listener(
          onPointerDown: (e) {
            _lastKind = e.kind;
            _syncOverlays();
          },
          onPointerHover: (e) => _hover(e, width),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onHorizontalDragDown: _enabled
                ? (_) {
                    _setPressed(true);
                    _syncOverlays();
                  }
                : null,
            onHorizontalDragStart: _enabled
                ? (d) => _dragStart(d, width)
                : null,
            onHorizontalDragUpdate: _enabled
                ? (d) => _dragTo(d.localPosition.dx, width)
                : null,
            onHorizontalDragEnd: _enabled ? (_) => _dragEnd() : null,
            onHorizontalDragCancel: _enabled
                ? () {
                    if (_dragging) {
                      _dragEnd();
                    } else {
                      _setPressed(false);
                      _syncOverlays();
                    }
                  }
                : null,
            onTapUp: _enabled ? (d) => _tapUp(d, width) : null,
            child: track,
          ),
        );
      },
    );
  }

  /// The value bubble: tooltip-styled, 8 px above the track's top edge plus
  /// its own height.
  Widget _bubbleWidget(CoilSliderStyle style, double fallbackValue) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final opacity = _controller.value(_bubble).clamp(0.0, 1.0);
              if (opacity <= 0) return const SizedBox.shrink();
              final showThumb = _pressed;
              final at = showThumb
                  ? _controller.value(_thumb)
                  : _controller.value(_preview);
              final shown = showThumb ? fallbackValue : _hoverValue;
              final tier = CoilTheme.tierOf(context);
              final radius = CoilTheme.of(context).shape.radii(tier).item;
              return Opacity(
                opacity: opacity,
                child: CustomSingleChildLayout(
                  delegate: _BubbleLayout(
                    fraction: rtl ? 1 - at.clamp(0, 1) : at.clamp(0, 1),
                    reach: _reach,
                  ),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: style.bubble,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(radius),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        _format(shown),
                        maxLines: 1,
                        softWrap: false,
                        style: style.bubbleTextStyle!.copyWith(
                          color: style.bubbleText,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRegular(
    CoilThemeData theme,
    CoilSliderStyle style,
    double value,
    Widget? label,
  ) {
    final sizes = _metrics;
    final motion = _motion;
    final states = _states.value;
    final radius = BorderRadius.circular(style.radius!);
    final pips = widget.variant == CoilSliderVariant.pips;
    final active =
        states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused) ||
        states.contains(WidgetState.pressed);
    final handleColor = style.handle!.resolve(states)!;
    final labelColor = style.label!.resolve(states)!;
    final valueColor = style.value!.resolve(states)!;
    final textStyle = style.textStyle!.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final pad = sizes.controlPaddingX;
    final ghosts = {
      _format(widget.min),
      _format(widget.max),
      _format(value),
    };
    final textRow = Padding(
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: Row(
        children: [
          if (label != null)
            _StateText(
              color: labelColor,
              bold: active,
              style: textStyle,
              motion: motion,
              ghosts: null,
              child: label,
            ),
          const Spacer(),
          _StateText(
            color: valueColor,
            bold: active,
            style: textStyle,
            motion: motion,
            ghosts: ghosts,
            text: _format(value),
          ),
        ],
      ),
    );

    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: sizes.controlHeight),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: radius,
            side: BorderSide(color: style.border!),
          ),
        ),
        child: ClipRSuperellipse(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              if (pips)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PipsPainter(
                      controller: _controller,
                      thumb: _thumb,
                      divisions: widget.divisions!,
                      pad: pad,
                      size: style.pipSize!,
                      pip: style.pip!.resolve({})!,
                      active: style.pip!.resolve({WidgetState.selected})!,
                      rtl: Directionality.of(context) == TextDirection.rtl,
                    ),
                  ),
                ),
              if (pips)
                // Occludes the dots behind the text, like the web's
                // background-colored copies of the label and value.
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(color: Color(0x00000000)),
                      child: IgnorePointer(
                        child: _backdrop(
                          theme,
                          textStyle,
                          label,
                          ghosts,
                          pad,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: SingleMotionBuilder(
                  value: active ? 1 : 0,
                  motion: motion.quick,
                  debugLabel: 'Handle emphasis',
                  builder: (context, emphasis, _) => MotionBuilder<Color>(
                    value: handleColor,
                    motion: motion.fade,
                    converter: .colorRgb,
                    debugLabel: 'Handle color',
                    builder: (context, color, _) => CustomPaint(
                      painter: _FillPainter(
                        controller: _controller,
                        thumb: _thumb,
                        preview: _preview,
                        previewOpacity: _previewOpacity,
                        fill: style.fill!,
                        previewColor: style.preview!,
                        handle: color,
                        emphasis: emphasis.clamp(0, 1),
                        pad: pips ? pad : 0,
                        rtl: Directionality.of(context) == TextDirection.rtl,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: IgnorePointer(child: textRow)),
              // Sizes the row to the text, behind everything.
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: textRow,
              ),
            ],
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CoilFocusRing(
          visible: states.contains(WidgetState.focused),
          borderRadius: radius,
          offset: 2,
          child: _gestures(row),
        ),
        _bubbleWidget(style, value),
      ],
    );
  }

  Widget _backdrop(
    CoilThemeData theme,
    TextStyle textStyle,
    Widget? label,
    Set<String> ghosts,
    double pad,
  ) {
    Widget block(Widget child) => ColoredBox(
      color: theme.colors.background,
      child: Opacity(opacity: 0, child: child),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pad - 8),
      child: Row(
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: block(
                DefaultTextStyle(
                  style: textStyle.copyWith(
                    fontVariations: CoilWeight.semibold.variations,
                  ),
                  child: label,
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: block(
              Stack(
                alignment: AlignmentDirectional.centerEnd,
                children: [
                  for (final g in ghosts)
                    Text(
                      g,
                      style: textStyle.copyWith(
                        fontVariations: CoilWeight.semibold.variations,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(
    CoilThemeData theme,
    CoilSliderStyle style,
    double value,
    Widget? label,
  ) {
    final sizes = _metrics;
    final motion = _motion;
    final states = _states.value;
    final active =
        states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused) ||
        states.contains(WidgetState.pressed);
    final labelColor = style.label!.resolve(states)!;
    final valueColor = style.value!.resolve(states)!;
    final textStyle = style.textStyle!.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final box = style.knobBox!;
    final knob = style.knobSize!;
    final trackHeight = style.compactTrackHeight!;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final pill = BorderRadius.circular(trackHeight / 2);
    final ghosts = {_format(widget.min), _format(widget.max), _format(value)};

    final track = SizedBox(
      height: box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _CompactPainter(
                controller: _controller,
                thumb: _thumb,
                preview: _preview,
                previewOpacity: _previewOpacity,
                fill: style.compactFill!,
                border: style.border!,
                previewColor: style.preview!,
                trackHeight: trackHeight,
                box: box,
                rtl: rtl,
              ),
            ),
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final at = _controller.value(_thumb).clamp(0.0, 1.0);
              return Align(
                alignment: AlignmentDirectional(at * 2 - 1, 0),
                child: SizedBox(
                  width: box,
                  height: box,
                  child: Center(
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: style.knob,
                        shadows: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            offset: Offset(0, 1),
                            blurRadius: 3,
                          ),
                          BoxShadow(
                            color: Color(0x1A000000),
                            offset: Offset(0, 1),
                            blurRadius: 2,
                            spreadRadius: -1,
                          ),
                        ],
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(knob / 2),
                        ),
                      ),
                      child: SizedBox.square(dimension: knob),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );

    final ringed = CoilFocusRing(
      visible: states.contains(WidgetState.focused),
      borderRadius: pill,
      offset: 2,
      child: _gestures(track),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          spacing: sizes.gap,
          children: [
            if (label != null)
              _StateText(
                color: labelColor,
                bold: active,
                style: textStyle,
                motion: motion,
                ghosts: null,
                child: label,
              ),
            Expanded(child: ringed),
            _StateText(
              color: valueColor,
              bold: active,
              style: textStyle,
              motion: motion,
              ghosts: ghosts,
              text: _format(value),
            ),
          ],
        ),
        _bubbleWidget(style, value),
      ],
    );
  }
}

/// A label or value that turns foreground and semibold; a hidden semibold
/// copy reserves the width, so nothing shifts.
class _StateText extends StatelessWidget {
  const _StateText({
    required this.color,
    required this.bold,
    required this.style,
    required this.motion,
    required this.ghosts,
    this.text,
    this.child,
  });

  final Color color;
  final bool bold;
  final TextStyle style;
  final CoilMotion motion;

  /// Strings whose semibold widths the slot must fit; null reserves the
  /// semibold width of [child] itself.
  final Set<String>? ghosts;
  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final semibold = style.copyWith(
      fontVariations: CoilWeight.semibold.variations,
    );
    Widget content(TextStyle s) => child == null
        ? Text(text!, style: s, maxLines: 1, softWrap: false)
        : DefaultTextStyle(
            style: s,
            maxLines: 1,
            softWrap: false,
            child: child!,
          );
    return MotionBuilder<Color>(
      value: color,
      motion: motion.fade,
      converter: .colorRgb,
      debugLabel: 'Slider text color',
      builder: (context, color, _) => SingleMotionBuilder(
        value: bold ? CoilWeight.semibold.wght : 400,
        motion: motion.fade,
        debugLabel: 'Slider text weight',
        builder: (context, wght, _) => Stack(
          alignment: AlignmentDirectional.centerEnd,
          children: [
            if (ghosts != null)
              for (final g in ghosts!)
                ExcludeSemantics(
                  child: Opacity(
                    opacity: 0,
                    child: Text(g, style: semibold, maxLines: 1),
                  ),
                )
            else
              ExcludeSemantics(
                child: Opacity(opacity: 0, child: content(semibold)),
              ),
            content(
              style.copyWith(
                color: color,
                fontVariations: [
                  FontVariation('wght', wght),
                  FontVariation('opsz', 14 + (wght - 400) / 150 * 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Positions the value bubble centered over the thumb, 8 px above the top.
class _BubbleLayout extends SingleChildLayoutDelegate {
  _BubbleLayout({required this.fraction, required this.reach});

  /// 0..1 from the leading edge, already mirrored for RTL.
  final double fraction;
  final (double, double) Function(double width) reach;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      const BoxConstraints();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final (start, end) = reach(size.width);
    final x = start + fraction * (end - start);
    return Offset(x - childSize.width / 2, -(8 + childSize.height));
  }

  @override
  bool shouldRelayout(_BubbleLayout old) => old.fraction != fraction;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// The comfortable row's fill, hover preview and handle line.
class _FillPainter extends CustomPainter {
  _FillPainter({
    required this.controller,
    required this.thumb,
    required this.preview,
    required this.previewOpacity,
    required this.fill,
    required this.previewColor,
    required this.handle,
    required this.emphasis,
    required this.pad,
    required this.rtl,
  }) : super(repaint: controller);

  final TrackController controller;
  final CoilSliderTrack<double> thumb;
  final CoilSliderTrack<double> preview;
  final CoilSliderTrack<double> previewOpacity;
  final Color fill;
  final Color previewColor;
  final Color handle;
  final double emphasis;
  final double pad;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    double mirror(double x) => rtl ? w - x : x;
    double xAt(double f) => pad > 0 ? _lerp(pad, w - pad, f) : _lerp(0, w, f);
    final at = controller.value(thumb).clamp(0.0, 1.0);
    final edge = xAt(at) + (pad > 0 ? 1 : 0);

    Rect span(double a, double b) {
      final l = mirror(a);
      final r = mirror(b);
      return Rect.fromLTRB(math.min(l, r), 0, math.max(l, r), size.height);
    }

    canvas.drawRect(span(0, edge), Paint()..color = fill);

    final shown = controller.value(previewOpacity).clamp(0.0, 1.0);
    if (shown > 0) {
      final p = xAt(controller.value(preview).clamp(0.0, 1.0));
      final a = math.min(edge, p);
      final b = math.max(edge, p);
      canvas.drawRect(
        span(a, b),
        Paint()
          ..color = previewColor.withValues(
            alpha: previewColor.a * shown,
          ),
      );
    }

    final lineX = mirror(
      pad > 0 ? xAt(at) : edge.clamp(_handleInset, w - _handleInset),
    );
    final inset = 8 - emphasis;
    final line = RSuperellipse.fromLTRBR(
      lineX - 1,
      inset,
      lineX + 1,
      size.height - inset,
      const Radius.circular(1),
    );
    canvas.drawRSuperellipse(line, Paint()..color = handle);
  }

  @override
  bool shouldRepaint(_FillPainter old) =>
      old.fill != fill ||
      old.previewColor != previewColor ||
      old.handle != handle ||
      old.emphasis != emphasis ||
      old.pad != pad ||
      old.rtl != rtl;
}

/// The dots of the pips variant, the active one in foreground.
class _PipsPainter extends CustomPainter {
  _PipsPainter({
    required this.controller,
    required this.thumb,
    required this.divisions,
    required this.pad,
    required this.size,
    required this.pip,
    required this.active,
    required this.rtl,
  }) : super(repaint: controller);

  final TrackController controller;
  final CoilSliderTrack<double> thumb;
  final int divisions;
  final double pad;
  final double size;
  final Color pip;
  final Color active;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size box) {
    final at = controller.value(thumb).clamp(0.0, 1.0);
    for (var i = 0; i <= divisions; i++) {
      final f = i / divisions;
      final near = (1 - (at - f).abs() * divisions).clamp(0.0, 1.0);
      var x = _lerp(pad, box.width - pad, f);
      if (rtl) x = box.width - x;
      final d = size * (1 + 0.4 * near);
      canvas.drawRSuperellipse(
        RSuperellipse.fromLTRBR(
          x - d / 2,
          box.height / 2 - d / 2,
          x + d / 2,
          box.height / 2 + d / 2,
          Radius.circular(d / 2),
        ),
        Paint()..color = Color.lerp(pip, active, near)!,
      );
    }
  }

  @override
  bool shouldRepaint(_PipsPainter old) =>
      old.pip != pip ||
      old.active != active ||
      old.pad != pad ||
      old.size != size ||
      old.divisions != divisions ||
      old.rtl != rtl;
}

/// The compact pill track: outline, fill up to the knob and the preview.
class _CompactPainter extends CustomPainter {
  _CompactPainter({
    required this.controller,
    required this.thumb,
    required this.preview,
    required this.previewOpacity,
    required this.fill,
    required this.border,
    required this.previewColor,
    required this.trackHeight,
    required this.box,
    required this.rtl,
  }) : super(repaint: controller);

  final TrackController controller;
  final CoilSliderTrack<double> thumb;
  final CoilSliderTrack<double> preview;
  final CoilSliderTrack<double> previewOpacity;
  final Color fill;
  final Color border;
  final Color previewColor;
  final double trackHeight;
  final double box;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final top = (size.height - trackHeight) / 2;
    final shape = RSuperellipse.fromLTRBR(
      0,
      top,
      w,
      top + trackHeight,
      Radius.circular(trackHeight / 2),
    );
    double mirror(double x) => rtl ? w - x : x;
    double xAt(double f) => _lerp(box / 2, math.max(box / 2, w - box / 2), f);
    Rect span(double a, double b) {
      final l = mirror(a);
      final r = mirror(b);
      return Rect.fromLTRB(
        math.min(l, r),
        top,
        math.max(l, r),
        top + trackHeight,
      );
    }

    final edge = xAt(controller.value(thumb).clamp(0.0, 1.0));
    canvas
      ..save()
      ..clipRSuperellipse(shape)
      ..drawRect(span(0, edge), Paint()..color = fill);
    final shown = controller.value(previewOpacity).clamp(0.0, 1.0);
    if (shown > 0) {
      final p = xAt(controller.value(preview).clamp(0.0, 1.0));
      canvas.drawRect(
        span(math.min(edge, p), math.max(edge, p)),
        Paint()..color = previewColor.withValues(alpha: previewColor.a * shown),
      );
    }
    canvas
      ..restore()
      ..drawRSuperellipse(
        shape.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = border,
      );
  }

  @override
  bool shouldRepaint(_CompactPainter old) =>
      old.fill != fill ||
      old.border != border ||
      old.previewColor != previewColor ||
      old.trackHeight != trackHeight ||
      old.box != box ||
      old.rtl != rtl;
}
