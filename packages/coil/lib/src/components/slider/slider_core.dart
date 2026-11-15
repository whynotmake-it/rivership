// Internal to CoilSlider and CoilRangeSlider; not exported.
// ignore_for_file: public_member_api_docs

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/slider/slider.dart';
import 'package:coil/src/components/slider/slider_painters.dart';
import 'package:coil/src/components/slider/slider_scale.dart';
import 'package:coil/src/components/slider/slider_shortcuts.dart';
import 'package:coil/src/components/slider/slider_style.dart';
import 'package:coil/src/components/slider/slider_text.dart';
import 'package:coil/src/components/slider/slider_visuals.dart';
import 'package:coil/tooltip.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The slider both public widgets build: one thumb, or two that can't cross.
///
/// Values travel as lists, one entry per thumb, in thumb order. One thumb is
/// a single slider node around everything. Two thumbs are a group with a
/// slider node and a focus stop per thumb, each riding on its thumb.
class SliderCore extends StatefulWidget {
  const SliderCore({
    required this.values,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
    required this.scale,
    required this.label,
    required this.valueBuilder,
    required this.semanticFormatter,
    required this.editFormatter,
    required this.editParser,
    required this.variant,
    required this.valueDisplay,
    required this.size,
    required this.focusNode,
    required this.autofocus,
    required this.statesController,
    required this.motion,
    required this.motions,
    required this.style,
    required this.semanticLabel,
    required this.thumbLabels,
    super.key,
  }) : assert(values.length == 1 || values.length == 2, 'one or two thumbs');

  final List<double> values;
  final ValueChanged<List<double>>? onChanged;
  final ValueChanged<List<double>>? onChangeStart;
  final ValueChanged<List<double>>? onChangeEnd;
  final SliderScale scale;
  final Widget? label;
  final Widget Function(BuildContext context, double value)? valueBuilder;
  final String Function(double value)? semanticFormatter;
  final String Function(double value)? editFormatter;
  final double? Function(String text)? editParser;
  final CoilSliderVariant variant;
  final CoilSliderValueDisplay valueDisplay;
  final CoilSize? size;

  /// The single thumb's focus node; a range owns its thumbs' nodes.
  final FocusNode? focusNode;
  final bool autofocus;
  final WidgetStatesController? statesController;
  final CoilMotion? motion;
  final Map<CoilSliderTrack<Object>, Motion>? motions;
  final CoilSliderStyle? style;

  /// The single slider's label, or the range's group label.
  final String? semanticLabel;

  /// Each thumb's own label in a range.
  final List<String> thumbLabels;

  @override
  State<SliderCore> createState() => _SliderCoreState();
}

class _SliderCoreState extends State<SliderCore> with TickerProviderStateMixin {
  int get _count => widget.values.length;
  bool get _range => _count == 2;

  /// One controller per thumb, each moving its own [CoilSliderTrack.thumb]:
  /// dragging sets it, everything else springs it.
  late final List<TrackController> _thumbs = [
    for (var i = 0; i < _count; i++)
      TrackController(vsync: this, debugLabel: 'CoilSlider.thumb$i'),
  ];
  late final Listenable _thumbMoves = Listenable.merge(_thumbs);

  double _at(int i) => _thumbs[i].value(CoilSliderTrack.thumb);

  /// The thumbs' fractions, read by the paint while painting.
  List<double> _fractions() => [for (var i = 0; i < _count; i++) _at(i)];

  /// The snapped fraction under a hover-capable pointer, null when there is
  /// none. It follows the pointer during a drag too, so it is current the
  /// moment the drag ends.
  final _hover = ValueNotifier<double?>(null);

  /// Where the hover last was; the bubble stays there while it fades out.
  double _lastHover = 0;

  /// The hover preview bar's end. It springs from the nearest thumb toward
  /// the hover, set by pointer events rather than by builds.
  late final _preview = TrackController(
    vsync: this,
    debugLabel: 'CoilSlider.preview',
  );
  double get _previewAt => _preview.value(CoilSliderTrack.preview);

  /// Whether the hover bubble has met the preview. A bubble appears on the
  /// hover at once; until the springing preview reaches it, the bubble
  /// follows the hover directly. Once they meet, it rides the preview.
  bool _joined = false;

  /// Which side of the hover the preview was on, to see them cross.
  double? _side;

  /// The value bubbles' presence, 0 hidden to 1 shown, on
  /// [CoilSliderTrack.bubble]. Pointer, press and focus events drive it.
  late final _bubble = TrackController(
    vsync: this,
    debugLabel: 'CoilSlider.bubble',
  )..set([CoilSliderTrack.bubble.value(0)]);
  late final Animation<double> _bubblePresence = _bubble.animationOf(
    CoilSliderTrack.bubble,
  );
  bool _bubbleShown = false;

  /// Repaints the track: a thumb or the preview moved.
  late final Listenable _paintMoves = Listenable.merge([..._thumbs, _preview]);

  WidgetStatesController? _ownStates;
  WidgetStatesController get _states =>
      widget.statesController ?? (_ownStates ??= WidgetStatesController());

  late final List<FocusNode> _ownFocus = [
    for (var i = 0; i < _count; i++) FocusNode(debugLabel: 'CoilSlider.$i'),
  ];
  FocusNode _focusOf(int i) =>
      (i == 0 ? widget.focusNode : null) ?? _ownFocus[i];

  /// The thumb with focus, if any.
  int? _focused;

  bool _dragging = false;
  PointerDeviceKind _kind = PointerDeviceKind.mouse;

  /// The thumb a press or drag moves.
  int _active = 0;

  /// The press is on two stacked thumbs; the drag's direction picks one.
  bool _tied = false;
  double _downFraction = 0;

  /// Whether a press on the track is changing the value. It opens at the
  /// first change (a tap-down or a drag start) and closes at whichever
  /// comes first: the tap, the drag's end, or the drag's cancel (a scroll
  /// won, or the pointer lifted). So a press that becomes a drag is one
  /// change. A quick tap's drag cancel comes before its tap-down, which is
  /// why the tap closes it too.
  bool _pressing = false;

  /// The values this press last asked for, which its end reports.
  List<double> _asked = const [];

  /// The value under the pointer while the track is pressed: the snapped
  /// press or drag position, kept from crossing the other thumb. The value
  /// bubble belongs to the pointer, so it sits here while the thumb springs
  /// to meet it, and it doesn't move when the parent refuses the change.
  double _pressValue = 0;

  /// The thumb whose value is being typed, if any.
  int? _editing;
  final _editText = TextEditingController();
  final _editFocus = FocusNode(debugLabel: 'CoilSlider.field');
  late final List<WidgetStatesController> _valueStates = [
    for (var i = 0; i < _count; i++) WidgetStatesController(),
  ];

  bool get _enabled => widget.onChanged != null;
  bool get _compactTrack =>
      widget.variant == CoilSliderVariant.pill ||
      widget.variant == CoilSliderVariant.pillPips;
  bool get _tooltip => widget.valueDisplay == CoilSliderValueDisplay.tooltip;
  bool get _editable =>
      _enabled && widget.valueDisplay == CoilSliderValueDisplay.editable;
  bool get _rtl => Directionality.of(context) == TextDirection.rtl;
  SliderScale get _scale => widget.scale;

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
      _ when track == CoilSliderTrack.dots => (
        tokens.standard,
        tokens.standardExit,
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

  /// The value as screen readers hear it.
  String _semantic(double v) => widget.semanticFormatter?.call(v) ?? _plain(v);

  /// The value as the text, the bubbles and the width reserve show it.
  Widget _shown(double v) =>
      widget.valueBuilder?.call(context, v) ?? Text(_plain(v));

  /// Up to two decimals without trailing zeros, with a `.` decimal mark.
  static String _plain(double v) {
    final fixed = v.toStringAsFixed(2);
    return fixed.contains('.')
        ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
        : fixed;
  }

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _count; i++) {
      _thumbs[i].set([
        CoilSliderTrack.thumb.value(_scale.norm(widget.values[i])),
      ]);
      _focusOf(i).addListener(_onFocus);
    }
    _preview
      ..set([CoilSliderTrack.preview.value(_scale.norm(widget.values[0]))])
      ..addListener(_meet);
    _states
      ..addListener(_forgetHover)
      ..addListener(_syncBubble);
    _hover.addListener(_syncBubble);
    for (final s in _valueStates) {
      s.addListener(_syncBubble);
    }
    _editFocus.addListener(_onEditFocus);
    CoilInputModality.instance.addListener(_syncFocused);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBubble();
  }

  /// Whether a value bubble shows. Tooltip mode keeps the values over the
  /// thumbs while the slider is hovered, pressed or keyboard-focused.
  /// Otherwise one bubble shows the hovered value, or the pressed thumb's
  /// value under a finger.
  bool get _wantsBubble {
    if (!_enabled) return false;
    final states = _states.value;
    final hovered = states.contains(WidgetState.hovered);
    if (_tooltip) {
      return hovered ||
          states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.focused) ||
          _dragging;
    }
    final onValue = _valueStates.any(
      (s) => s.value.contains(WidgetState.hovered),
    );
    final pointed = _hover.value != null && !onValue;
    return (hovered && pointed) ||
        ((_pressing || _dragging) && _kind != PointerDeviceKind.mouse);
  }

  /// Springs the bubbles in or out when [_wantsBubble] changes.
  void _syncBubble() {
    final show = _wantsBubble;
    if (show == _bubbleShown) return;
    _bubbleShown = show;
    final motion = _motionFor(CoilSliderTrack.bubble, _tokens);
    _bubble.animate([
      CoilSliderTrack.bubble([
        .to(show ? 1 : 0, motion: show ? motion.enter : motion.exit),
      ]),
    ]);
  }

  /// Joins the bubble to the preview once the preview reaches the hover or
  /// crosses it.
  void _meet() {
    final hover = _hover.value;
    if (_joined || hover == null) return;
    final side = (_previewAt - hover).sign;
    if (side == 0 || (_side != null && side != _side)) {
      _joined = true;
    } else {
      _side = side;
    }
  }

  void _forgetHover() {
    if (!_states.value.contains(WidgetState.hovered)) _hover.value = null;
  }

  void _onFocus() {
    int? focused;
    for (var i = 0; i < _count; i++) {
      if (_focusOf(i).hasFocus) focused = i;
    }
    if (focused != _focused) setState(() => _focused = focused);
    _syncFocused();
  }

  /// The slider is focused while either thumb has the primary focus from
  /// the keyboard, the detector's rule. The slider writes it, not the
  /// detector: one detector covers both thumbs, and the thumb with focus
  /// changes on a focus event, not while building.
  void _syncFocused() {
    var thumb = false;
    for (var i = 0; i < _count; i++) {
      if (_focusOf(i).hasPrimaryFocus) thumb = true;
    }
    _states.update(
      WidgetState.focused,
      thumb && CoilInputModality.instance.value == CoilModality.keyboard,
    );
  }

  /// Leaving the field commits it, as Done does.
  void _onEditFocus() {
    if (!_editFocus.hasFocus && _editing != null) _commitEdit(refocus: false);
  }

  @override
  void didUpdateWidget(SliderCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statesController != widget.statesController) {
      (oldWidget.statesController ?? _ownStates)
        ?..removeListener(_forgetHover)
        ..removeListener(_syncBubble);
      _states
        ..addListener(_forgetHover)
        ..addListener(_syncBubble);
    }
    _syncBubble();
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus.first).removeListener(_onFocus);
      _focusOf(0).addListener(_onFocus);
    }
    for (var i = 0; i < _count; i++) {
      final to = _scale.norm(widget.values[i]);
      if (_at(i) == to) continue;
      if (_dragging && i == _active && _scale.continuous) {
        // A continuous drag: the thumb follows the pointer directly. A
        // stepped value jumps from step to step, so it springs below and
        // retargets as the pointer crosses steps.
        _thumbs[i].set([CoilSliderTrack.thumb.value(to)]);
      } else {
        _thumbs[i].animate([
          CoilSliderTrack.thumb([
            .to(to, motion: _motionFor(CoilSliderTrack.thumb, _tokens).enter),
          ]),
        ]);
      }
    }
  }

  @override
  void dispose() {
    CoilInputModality.instance.removeListener(_syncFocused);
    _states
      ..removeListener(_forgetHover)
      ..removeListener(_syncBubble);
    for (var i = 0; i < _count; i++) {
      _focusOf(i).removeListener(_onFocus);
      _ownFocus[i].dispose();
      _valueStates[i].dispose();
      _thumbs[i].dispose();
    }
    _ownStates?.dispose();
    _editFocus.dispose();
    _editText.dispose();
    _hover.dispose();
    _preview.dispose();
    _bubble.dispose();
    super.dispose();
  }

  // ---- changes ---------------------------------------------------------

  /// The values with thumb [i] at [v].
  List<double> _with(int i, double v) => [...widget.values]..[i] = v;

  /// [v] for thumb [i], kept from crossing the other thumb.
  double _limit(int i, double v) {
    if (!_range) return v;
    final other = widget.values[1 - i];
    return i == 0 ? (v < other ? v : other) : (v > other ? v : other);
  }

  /// A whole change that isn't a drag: tap, key, typed value or screen
  /// reader action.
  void _change(int i, double to) {
    final next = _limit(i, _scale.snap(to));
    widget.onChangeStart?.call(widget.values);
    final values = _with(i, next);
    if (next != widget.values[i]) widget.onChanged?.call(values);
    widget.onChangeEnd?.call(values);
  }

  /// The thumb a press at [f] moves: the nearest one. Between two stacked
  /// thumbs, the side of the press decides, and on them the drag does.
  int _pick(double f) {
    _tied = false;
    if (!_range) return 0;
    final start = _scale.norm(widget.values[0]);
    final end = _scale.norm(widget.values[1]);
    final toStart = (f - start).abs();
    final toEnd = (f - end).abs();
    if (toStart != toEnd) return toStart < toEnd ? 0 : 1;
    if (f > end) return 1;
    if (f < start) return 0;
    _tied = true;
    return 0;
  }

  void _beginPress() {
    if (_pressing) return;
    setState(() => _pressing = true);
    _syncBubble();
    _asked = widget.values;
    widget.onChangeStart?.call(widget.values);
  }

  /// A press on the track jumps the nearest thumb there on the way down,
  /// as native sliders do, so the thumb is under the pointer while pressed.
  ///
  /// A press beside the track, on the pill's label or value, changes
  /// nothing.
  void _pressDown(TapDownDetails d) {
    final track = _trackKey.currentContext?.findRenderObject();
    if (track is! RenderBox) return;
    final local = track.globalToLocal(d.globalPosition);
    if (!(Offset.zero & track.size).contains(local)) return;
    _beginPress();
    _dragTo(local.dx, track.size.width, _reach(_style(_metrics)));
  }

  /// The track box, for mapping a press to it.
  final _trackKey = GlobalKey(debugLabel: 'CoilSlider.track');

  CoilMetrics get _metrics => CoilTheme.metricsOf(context, size: widget.size);

  CoilSliderStyle _style(CoilMetrics metrics) => CoilSliderStyle.fallback(
    CoilTheme.of(context),
    metrics,
  ).merge(CoilTheme.styleOf<CoilSliderStyle>(context)).merge(widget.style);

  /// The row's range spans its full width; the pill's stops half a knob
  /// short of each end, so the knob stays inside the track.
  SliderReach _reach(CoilSliderStyle style) =>
      SliderReach(_compactTrack ? style.knobBox! / 2 : 0);

  void _dragStart(DragStartDetails d, double width, SliderReach reach) {
    _dragging = true;
    setState(() {});
    _beginPress();
    _dragTo(d.localPosition.dx, width, reach);
  }

  void _dragTo(double dx, double width, SliderReach reach) {
    final f = reach.fractionAt(dx, width, rtl: _rtl);
    if (_tied && f != _downFraction) {
      _tied = false;
      _active = f > _downFraction ? 1 : 0;
    }
    final value = _limit(_active, _scale.valueAt(f));
    if (value != _pressValue) setState(() => _pressValue = value);
    if (value != widget.values[_active]) {
      _asked = _with(_active, value);
      widget.onChanged?.call(_asked);
    }
  }

  void _endPress() {
    if (_dragging) setState(() => _dragging = false);
    if (!_pressing) return _syncBubble();
    setState(() => _pressing = false);
    _syncBubble();
    widget.onChangeEnd?.call(_asked);
  }

  void _step(int i, SliderStepIntent intent) {
    if (!_enabled) return;
    _change(i, _scale.move(widget.values[i], intent.steps, page: intent.page));
  }

  void _end(int i, SliderEndIntent intent) {
    if (!_enabled) return;
    _change(i, intent.max ? _scale.max : _scale.min);
  }

  // ---- click-to-edit ---------------------------------------------------

  void _startEdit(int i) {
    if (!_editable || _editing != null) return;
    final text = (widget.editFormatter ?? _plain)(widget.values[i]);
    _editText.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    setState(() => _editing = i);
    // The thumb has focus, so the field's autofocus wouldn't take it.
    _editFocus.requestFocus();
  }

  /// Applies the typed value, clamped and snapped. Text that isn't a number
  /// changes nothing.
  void _commitEdit({bool refocus = true}) {
    final i = _editing;
    if (i == null) return;
    final text = _editText.text.trim();
    final typed = widget.editParser?.call(text) ?? double.tryParse(text);
    _endEdit(i, refocus: refocus);
    if (typed != null && typed.isFinite) _change(i, typed);
  }

  void _cancelEdit() {
    if (_editing case final i?) _endEdit(i, refocus: true);
  }

  /// Closes the field. Done and Esc hand focus back to the thumb, so the
  /// keyboard carries on from where it was.
  void _endEdit(int i, {required bool refocus}) {
    setState(() => _editing = null);
    if (refocus) _focusOf(i).requestFocus();
  }

  // ---- build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    // The detector writes the states the visuals listen to, so it sits
    // above them; the track alone is where a press changes the value.
    final content = CoilInteractionDetector(
      states: _states,
      enabled: _enabled,
      excludeFromSemantics: true,
      // The press shows and the value jumps in the same callback.
      onPressDown: _pressDown,
      onTap: _endPress,
      child: Opacity(
        opacity: _enabled ? 1 : metrics.disabledOpacity,
        child: ListenableBuilder(
          listenable: Listenable.merge([_states, ..._valueStates]),
          builder: (context, _) => _buildVisuals(metrics),
        ),
      ),
    );
    if (!_range) {
      return _thumbNode(0, label: widget.semanticLabel, child: content);
    }
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: content,
    );
  }

  /// Thumb [i]'s slider node, keys and focus stop around [child].
  Widget _thumbNode(int i, {required String? label, required Widget child}) {
    final value = widget.values[i];
    final up = _limit(i, _scale.move(value, 1));
    final down = _limit(i, _scale.move(value, -1));
    return Semantics(
      container: true,
      slider: true,
      enabled: _enabled,
      label: label,
      value: _semantic(value),
      increasedValue: _semantic(up),
      decreasedValue: _semantic(down),
      onIncrease: _enabled ? () => _step(i, const SliderStepIntent(1)) : null,
      onDecrease: _enabled ? () => _step(i, const SliderStepIntent(-1)) : null,
      child: Shortcuts(
        // While a value is typed, the keys belong to the field.
        shortcuts: !_enabled || _editing != null
            ? const {}
            : sliderShortcuts(rtl: _rtl, edit: _editable),
        child: Actions(
          actions: {
            SliderStepIntent: CallbackAction<SliderStepIntent>(
              onInvoke: (intent) => _step(i, intent),
            ),
            SliderEndIntent: CallbackAction<SliderEndIntent>(
              onInvoke: (intent) => _end(i, intent),
            ),
            SliderEditIntent: CallbackAction<SliderEditIntent>(
              onInvoke: (_) => _startEdit(i),
            ),
          },
          child: Focus(
            focusNode: _focusOf(i),
            autofocus: widget.autofocus && i == 0,
            canRequestFocus: _enabled,
            skipTraversal: !_enabled,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildVisuals(CoilMetrics metrics) {
    final theme = CoilTheme.of(context);
    final style = _style(metrics);
    final states = CoilInteractionDetector.statesFor(
      _states.value,
      enabled: _enabled,
    );
    final tokens = _tokens;
    final reach = _reach(style);
    final pressed = states.contains(WidgetState.pressed) || _dragging;
    // A press on the track itself: the thumb is under the pointer. A press
    // on the pill's label or value shows as pressed but moves nothing.
    final onTrack = _pressing || _dragging;
    final hovered = states.contains(WidgetState.hovered);
    final focused = states.contains(WidgetState.focused);
    final active = hovered || pressed || focused;
    // A focus forced through the states controller rings the first thumb.
    final ring = focused ? _focused ?? 0 : null;
    // A pointer on an editable value is about to type, not to jump there.
    final onValue = _valueStates.any(
      (s) => s.value.contains(WidgetState.hovered),
    );

    final previewOpacity = _motionFor(CoilSliderTrack.previewOpacity, tokens);
    final handle = _motionFor(CoilSliderTrack.handle, tokens);
    final emphasis = _motionFor(CoilSliderTrack.emphasis, tokens);
    final dots = _motionFor(CoilSliderTrack.dots, tokens);
    // Retarget only what changed; a fade out uses the exit spring.
    Motion pick(({Motion enter, Motion exit}) m, {required bool entering}) =>
        entering ? m.enter : m.exit;

    // Each thumb's handle line: the focused one goes full foreground.
    final handleTargets = [
      for (var i = 0; i < _count; i++)
        style.handle!.resolve({
          if (hovered) WidgetState.hovered,
          if (pressed) WidgetState.pressed,
          if (focused && ring == i) WidgetState.focused,
        })!,
    ];

    return ValueListenableBuilder<double?>(
      valueListenable: _hover,
      builder: (context, hovering, _) {
        final pointed = hovering != null && !onValue;
        final showPreview = _enabled && hovered && pointed && !onTrack;
        return TrackBuilder(
          animations: [
            CoilSliderTrack.previewOpacity([
              .to(
                showPreview ? 1 : 0,
                motion: pick(previewOpacity, entering: showPreview),
              ),
            ]),
            CoilSliderTrack.dots([
              .to(hovered ? 1 : 0, motion: pick(dots, entering: hovered)),
            ]),
            CoilSliderTrack.emphasis([
              .to(active ? 1 : 0, motion: pick(emphasis, entering: active)),
            ]),
          ],
          builder: (context, v, _) => _SliderHandles(
            targets: handleTargets,
            motion: handle.enter,
            builder: (context, handles) => _buildTrack(
              theme: theme,
              metrics: metrics,
              style: style,
              reach: reach,
              v: v,
              handles: handles,
              hovering: hovering,
              onTrack: onTrack,
              ring: ring,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrack({
    required CoilThemeData theme,
    required CoilMetrics metrics,
    required CoilSliderStyle style,
    required SliderReach reach,
    required TrackValueReader v,
    required List<Color> handles,
    required double? hovering,
    required bool onTrack,
    required int? ring,
  }) {
    final rtl = _rtl;
    final scale = _scale;
    final e = v(CoilSliderTrack.emphasis).clamp(0.0, 1.0);
    final paint = SliderPaintState(
      reach: reach,
      rtl: rtl,
      previewOpacity: v(CoilSliderTrack.previewOpacity).clamp(0.0, 1.0),
      previewColor: style.preview!,
    );
    Color lerp(WidgetStateProperty<Color?> p) =>
        Color.lerp(p.resolve({}), p.resolve({WidgetState.hovered}), e)!;
    final labelColor = lerp(style.label!);
    final valueColor = lerp(style.value!);
    final text = style.textStyle!.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final value = _tooltip
        ? null
        : _valueText(theme, metrics, style, text, valueColor, e);

    final pill = _compactTrack;
    final radius = pill
        ? BorderRadius.circular(style.pillHeight! / 2)
        : BorderRadius.circular(style.radius!);

    // Bubbles map a fraction to an x, so they live in the track's own box:
    // the whole row, or only the pill. A range's thumb nodes ride there too.
    Widget withOverlays(Widget track) => Stack(
      clipBehavior: Clip.none,
      children: [
        track,
        if (_range)
          for (var i = 0; i < _count; i++)
            Positioned.fill(
              child: ListenableBuilder(
                listenable: _thumbs[i],
                builder: (context, child) => CustomSingleChildLayout(
                  delegate: SliderThumbLayout(
                    fraction: _at(i),
                    reach: reach,
                    rtl: rtl,
                    width: style.knobBox!,
                  ),
                  child: child,
                ),
                child: _thumbNode(
                  i,
                  label: widget.thumbLabels[i],
                  child: const SizedBox.expand(),
                ),
              ),
            ),
        // Each bubble's anchor is a thumb-sized box at its fraction, as
        // tall as the track, so the bubble clears the track. The anchor
        // follows the thumb in layout; the bubble lives in the overlay.
        if (_tooltip)
          for (var i = 0; i < _count; i++)
            _bubbleAnchor(
              moves: _thumbs[i],
              fraction: () => _at(i),
              reach: reach,
              width: style.knobBox!,
              value: widget.values[i],
            )
        else
          _bubbleAnchor(
            moves: _paintMoves,
            fraction: () => onTrack
                ? scale.norm(_pressValue)
                : _joined
                ? _previewAt
                : _lastHover,
            reach: reach,
            width: style.knobBox!,
            value: onTrack ? _pressValue : scale.valueAt(_lastHover),
          ),
      ],
    );

    if (pill) {
      return SliderPill(
        painter: SliderPillPaint(
          moves: _paintMoves,
          fractions: _fractions,
          preview: () => _previewAt,
          state: paint,
          fill: style.pillFill!,
          border: style.border!,
          height: style.pillHeight!,
          stops: widget.variant == CoilSliderVariant.pillPips
              ? scale.stops
              : null,
          dotSize: style.dotSize!,
          dotGrowth: style.dotGrowth!,
          dotColor: style.pip!,
          dots: v(CoilSliderTrack.dots).clamp(0.0, 1.0),
        ),
        style: style,
        metrics: metrics,
        label: widget.label,
        value: value,
        labelColor: labelColor,
        emphasis: e,
        thumbs: _thumbMoves,
        fractions: _fractions,
        ring: ring,
        track: (track) => withOverlays(_gestures(track, reach)),
      );
    }
    return withOverlays(
      CoilFocusRing(
        visible: ring != null,
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
              painter: SliderRowPaint(
                moves: _paintMoves,
                fractions: _fractions,
                preview: () => _previewAt,
                state: paint,
                fill: style.fill!,
                handles: handles,
                emphasis: e,
                handleWidth: style.handleWidth!,
                handleInset: style.handleInset!,
                stops: widget.variant == CoilSliderVariant.pips
                    ? scale.stops
                    : null,
                pipSize: style.pipSize!,
                pipGrowth: style.pipGrowth!,
                pip: style.pip!,
                activePip: style.activePip!,
              ),
              style: style,
              metrics: metrics,
              label: widget.label,
              value: value,
              labelColor: labelColor,
              emphasis: e,
            ),
          ),
          reach,
        ),
      ),
    );
  }

  /// A value bubble over a [width]-wide box at [fraction] of the track.
  Widget _bubbleAnchor({
    required Listenable moves,
    required ValueGetter<double> fraction,
    required SliderReach reach,
    required double width,
    required double value,
  }) => Positioned.fill(
    child: ListenableBuilder(
      listenable: moves,
      builder: (context, child) => CustomSingleChildLayout(
        delegate: SliderThumbLayout(
          fraction: fraction().clamp(0.0, 1.0),
          reach: reach,
          rtl: _rtl,
          width: width,
        ),
        child: child,
      ),
      child: CoilTooltipAnchor.controlled(
        presence: _bubblePresence,
        content: DefaultTextStyle.merge(
          style: const TextStyle(
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          child: _shown(value),
        ),
        // The slider's bubble only fades, on `fade` / `fadeExit`.
        bubble: (context, presence, content) => FadeTransition(
          key: sliderBubbleKey,
          opacity: presence,
          child: CoilTooltipBubble(motion: widget.motion, child: content),
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );

  /// The value text: one value, or two around a dash. When editable, a tap
  /// on a value turns it into a field.
  Widget _valueText(
    CoilThemeData theme,
    CoilMetrics metrics,
    CoilSliderStyle style,
    TextStyle text,
    Color color,
    double emphasis,
  ) {
    const dash = ExcludeSemantics(child: Text(' – '));
    final scale = _scale;
    List<Widget> reserveOf(int i) => [
      _shown(scale.min),
      _shown(scale.max),
      _shown(widget.values[i]),
    ];

    Widget part(int i) {
      if (_editing == i) {
        return SliderValueField(
          controller: _editText,
          focusNode: _editFocus,
          reserve: reserveOf(i),
          reserveStyle: text,
          style: theme.typography
              .style(metrics.field)
              .copyWith(
                color: theme.colors.foreground,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
          underline: style.border!,
          signed: scale.min < 0,
          onSubmit: _commitEdit,
          onCancel: _cancelEdit,
        );
      }
      final shown = ExcludeSemantics(child: _shown(widget.values[i]));
      if (!_editable) return shown;
      return CoilInteractionDetector(
        states: _valueStates[i],
        excludeFromSemantics: true,
        cursor: SystemMouseCursors.text,
        onTap: () => _startEdit(i),
        child: shown,
      );
    }

    return SliderValueText(
      parts: [
        part(0),
        if (_range) ...[dash, part(1)],
      ],
      reserve: _range
          ? [
              for (final v in [scale.min, scale.max])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [_shown(v), dash, _shown(v)],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _shown(widget.values[0]),
                  dash,
                  _shown(widget.values[1]),
                ],
              ),
            ]
          : reserveOf(0),
      style: text,
      color: color,
      emphasis: emphasis,
    );
  }

  /// Puts the hover where a hover-capable pointer is, at the snapped value.
  ///
  /// A new hover starts the preview at the nearest thumb and puts the bubble
  /// on the hover, unjoined. Every hover springs the preview toward it.
  void _point(PointerEvent e, double width, SliderReach reach) {
    if (!_enabled || !CoilInputModality.canHover(e.kind)) return;
    final to = _scale.norm(
      _scale.valueAt(reach.fractionAt(e.localPosition.dx, width, rtl: _rtl)),
    );
    if (to == _hover.value) return;
    if (_hover.value == null) {
      final thumbs = _fractions();
      _preview.set([
        CoilSliderTrack.preview.value(
          thumbs.reduce((a, b) => (a - to).abs() <= (b - to).abs() ? a : b),
        ),
      ]);
      _joined = false;
      _side = null;
    }
    _lastHover = to;
    _hover.value = to;
    _preview.animate([
      CoilSliderTrack.preview([
        .to(to, motion: _motionFor(CoilSliderTrack.preview, _tokens).enter),
      ]),
    ]);
    _meet();
  }

  /// Maps pointer events on [track] to values.
  Widget _gestures(Widget track, SliderReach reach) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gestures = Listener(
          key: _trackKey,
          onPointerDown: (e) {
            _kind = e.kind;
            if (_pressing) return;
            _downFraction = reach.fractionAt(
              e.localPosition.dx,
              width,
              rtl: _rtl,
            );
            _active = _pick(_downFraction);
          },
          // Moves with a button down are pointer moves, not hovers; both
          // place the hover, so it never lags behind a drag.
          onPointerHover: (e) => _point(e, width, reach),
          onPointerMove: (e) => _point(e, width, reach),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onHorizontalDragStart: _enabled
                ? (d) => _dragStart(d, width, reach)
                : null,
            onHorizontalDragUpdate: _enabled
                ? (d) => _dragTo(d.localPosition.dx, width, reach)
                : null,
            onHorizontalDragEnd: _enabled ? (_) => _endPress() : null,
            onHorizontalDragCancel: _enabled ? _endPress : null,
            child: track,
          ),
        );
        return gestures;
      },
    );
  }
}

/// Springs each thumb's handle line to its color on [motion], and builds
/// with the current colors.
class _SliderHandles extends StatelessWidget {
  const _SliderHandles({
    required this.targets,
    required this.motion,
    required this.builder,
  });

  final List<Color> targets;
  final Motion motion;
  final Widget Function(BuildContext context, List<Color> handles) builder;

  @override
  Widget build(BuildContext context) => _build(context, 0, const []);

  Widget _build(BuildContext context, int i, List<Color> done) {
    if (i == targets.length) return builder(context, done);
    return TrackBuilder(
      animations: [
        CoilSliderTrack.handle([.to(targets[i], motion: motion)]),
      ],
      builder: (context, v, _) =>
          _build(context, i + 1, [...done, v(CoilSliderTrack.handle)]),
    );
  }
}
