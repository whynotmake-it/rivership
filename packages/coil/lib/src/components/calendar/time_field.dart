import 'dart:async';
import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/input.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/calendar/time_entry.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A time of day typed into segments, like macOS's date field: "14:30"
/// on a 24-hour clock, "2:30 PM" on a 12-hour one (the locale's, as
/// `MediaQuery.alwaysUse24HourFormatOf` says).
///
/// It looks like a `CoilInput`: a hairline field of the control height that
/// darkens its border on focus and shows a faint fill under a hovering
/// pointer. The figures are tabular. It is for a pointer and a hardware
/// keyboard; a phone picks with `CoilTimeColumns`, which also types on the
/// number pad.
///
/// The field is one tab stop. Click a segment, or Tab in (at the hour), and
/// the focused segment shows the `active` fill:
///
/// * Left and Right, or ":", move between segments (mirrored in
///   right-to-left text); Tab leaves the field.
/// * Up and Down step the segment, wrapping without carrying into the next
///   one; Page Up and Page Down step 6 hours or 15 minutes; Home and End go
///   to its first and last value. A scroll wheel or trackpad over the
///   focused segment steps it too.
/// * Digits type into it. An hour that can still take a second digit waits
///   for it ("1" then "4" is 14), and moves on when it can't ("3" to "9" on
///   a 24-hour clock, "2" to "9" on a 12-hour one, or the second digit);
///   minutes move on after two digits, on a 12-hour clock to AM and PM.
///   Backspace forgets the digits typed so far, so the next one starts the
///   segment again, as does a pause of a second.
/// * "a" and "p" set AM and PM.
/// * Pasting "1430", "14:30", "2:30 pm" or "2:30PM" sets the time. Text
///   that isn't a time is ignored.
///
/// The arrows and Page keys step minutes by `minuteInterval`, a minute
/// between steps going to the next step in its direction. A typed or
/// pasted minute is kept as it is, whether or not it is on a step.
///
/// Screen readers meet a group named by [semanticLabel] with an adjustable
/// node for each segment, named by [hourLabel], [minuteLabel] and
/// [periodLabel], that they increase and decrease.
class CoilTimeField extends StatefulWidget {
  /// Creates a time field.
  const CoilTimeField({
    required this.value,
    required this.onChanged,
    super.key,
    this.minuteInterval = 1,
    this.hourLabel = 'Hour',
    this.minuteLabel = 'Minute',
    this.periodLabel = 'AM/PM',
    this.semanticLabel = 'Time',
    this.focusNode,
    this.autofocus = false,
    this.size,
    this.style,
    this.motion,
  }) : assert(
         minuteInterval > 0 && 60 % minuteInterval == 0,
         'minuteInterval must divide 60.',
       );

  /// The time shown, in 24-hour form.
  final ({int hour, int minute}) value;

  /// Called with the new time, in 24-hour form, as a segment changes. Null
  /// disables the field.
  final ValueChanged<({int hour, int minute})>? onChanged;

  /// The step of the arrow keys and the Page keys on the minute. It
  /// doesn't limit typed minutes.
  final int minuteInterval;

  /// The hour segment's name for screen readers.
  final String hourLabel;

  /// The minute segment's name for screen readers.
  final String minuteLabel;

  /// The AM and PM segment's name for screen readers.
  final String periodLabel;

  /// The field's name for screen readers.
  final String semanticLabel;

  /// The focus node; one is created if null.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// The field's size. Defaults to the ambient one.
  final CoilSize? size;

  /// Overrides how the field looks; it is a [CoilInputStyle], as the
  /// field's chrome is the input's.
  final CoilInputStyle? style;

  /// Overrides the theme's motion tokens for this field.
  final CoilMotion? motion;

  @override
  State<CoilTimeField> createState() => _CoilTimeFieldState();
}

class _CoilTimeFieldState extends State<CoilTimeField> {
  /// How long a pause lasts before typed digits start a segment again.
  static const _typeTimeout = Duration(seconds: 1);

  /// How far a wheel or trackpad scrolls to step a segment once.
  static const _scrollStep = 24.0;

  /// How far a segment's fill bleeds past its figures.
  static const _segmentPadding = 2.0;

  FocusNode? _ownFocusNode;
  final _states = WidgetStatesController();
  var _segment = TimeSegment.hour;
  var _buffer = '';
  Timer? _bufferTimer;
  var _scrolled = 0.0;

  FocusNode get _focus =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'CoilTimeField'));

  bool get _use24 => MediaQuery.alwaysUse24HourFormatOf(context);

  bool get _enabled => widget.onChanged != null;

  List<TimeSegment> get _segments => [
    TimeSegment.hour,
    TimeSegment.minute,
    if (!_use24) TimeSegment.period,
  ];

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(CoilTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _bufferTimer?.cancel();
    _focus.removeListener(_onFocus);
    _ownFocusNode?.dispose();
    _states.dispose();
    super.dispose();
  }

  void _onFocus() {
    _states.update(WidgetState.focused, _focus.hasFocus);
    // Tab comes in at the hour; a click picks its segment after this.
    if (!_focus.hasFocus) {
      _buffer = '';
      _segment = TimeSegment.hour;
    }
    setState(() {});
  }

  void _select(TimeSegment segment) {
    if (!_enabled) return;
    setState(() {
      _segment = segment;
      _buffer = '';
    });
    _focus.requestFocus();
  }

  void _commit(({int hour, int minute}) time) {
    if (time != widget.value) widget.onChanged?.call(time);
  }

  /// [segment] moved [steps] steps, wrapping.
  ({int hour, int minute}) _stepped(TimeSegment segment, int steps) {
    final value = widget.value;
    switch (segment) {
      case TimeSegment.hour:
        if (_use24) {
          return (hour: (value.hour + steps) % 24, minute: value.minute);
        }
        final hour = (hourOn12HourClock(value.hour) - 1 + steps) % 12 + 1;
        return (
          hour: hourFrom12HourClock(hour, pm: value.hour >= 12),
          minute: value.minute,
        );
      case TimeSegment.minute:
        return (
          hour: value.hour,
          minute: stepMinute(
            value.minute,
            steps,
            interval: widget.minuteInterval,
          ),
        );
      case TimeSegment.period:
        return (hour: (value.hour + 12) % 24, minute: value.minute);
    }
  }

  /// How far Page Up and Page Down step [segment].
  int _page(TimeSegment segment) => switch (segment) {
    TimeSegment.hour => 6,
    TimeSegment.minute => math.max(1, 15 ~/ widget.minuteInterval),
    TimeSegment.period => 1,
  };

  void _step(TimeSegment segment, int steps) {
    if (!_enabled) return;
    _buffer = '';
    _commit(_stepped(segment, steps));
  }

  void _goToEdge({required bool last}) {
    final value = widget.value;
    _buffer = '';
    switch (_segment) {
      case TimeSegment.hour:
        final hour = last ? (_use24 ? 23 : 12) : (_use24 ? 0 : 1);
        _commit((
          hour: _use24 ? hour : hourFrom12HourClock(hour, pm: value.hour >= 12),
          minute: value.minute,
        ));
      case TimeSegment.minute:
        _commit((
          hour: value.hour,
          minute: last ? 60 - widget.minuteInterval : 0,
        ));
      case TimeSegment.period:
        _setPeriod(pm: last);
    }
  }

  void _setPeriod({required bool pm}) {
    final value = widget.value;
    _commit((hour: value.hour % 12 + (pm ? 12 : 0), minute: value.minute));
  }

  void _move(int by) {
    final segments = _segments;
    final next = segments.indexOf(_segment) + by;
    if (next < 0 || next >= segments.length) return;
    setState(() {
      _segment = segments[next];
      _buffer = '';
    });
  }

  void _typeDigit(int digit) {
    if (!_enabled || _segment == TimeSegment.period) return;
    final value = widget.value;
    final entry = typeDigit(
      _buffer,
      digit,
      segment: _segment,
      use24HourFormat: _use24,
    );
    _buffer = entry.buffer;
    _bufferTimer?.cancel();
    _bufferTimer = Timer(_typeTimeout, () => _buffer = '');
    if (entry.value case final typed?) {
      _commit(
        _segment == TimeSegment.hour
            ? (
                hour: _use24
                    ? typed
                    : hourFrom12HourClock(typed, pm: value.hour >= 12),
                minute: value.minute,
              )
            : (hour: value.hour, minute: typed),
      );
    }
    if (entry.done) _move(1);
  }

  Future<void> _paste() async {
    if (!_enabled) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || !mounted) return;
    final time = parseTime(
      text,
      use24HourFormat: _use24,
      pm: widget.value.hour >= 12,
    );
    if (time != null) _commit(time);
  }

  void _onScroll(PointerSignalEvent event, TimeSegment segment) {
    if (event is! PointerScrollEvent ||
        !_enabled ||
        !_focus.hasFocus ||
        segment != _segment) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      _scrolled -= (event as PointerScrollEvent).scrollDelta.dy;
      final steps = (_scrolled / _scrollStep).truncate();
      if (steps == 0) return;
      _scrolled -= steps * _scrollStep;
      _step(segment, steps);
    });
  }

  String _text(TimeSegment segment, ({int hour, int minute}) time) =>
      switch (segment) {
        TimeSegment.hour => hourText(time.hour, use24HourFormat: _use24),
        TimeSegment.minute => minuteText(time.minute),
        TimeSegment.period => periodNames[time.hour >= 12 ? 1 : 0],
      };

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: widget.size);
    final look = CoilInputStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilInputStyle>(context)).merge(widget.style);
    final fade = CoilTheme.motionOf(context, override: widget.motion).fade;
    Motion colorMotion(CoilInputTrack<Object> track) => CoilTheme.trackMotionOf(
      context,
      track,
      styled: look.motions,
      instance: null,
      token: fade,
      spatial: false,
    );
    final corner = look.radius!;
    final textStyle = look.textStyle!.tabular;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final apple = switch (CoilTheme.platformOf(context)) {
      TargetPlatform.macOS || TargetPlatform.iOS => true,
      _ => false,
    };
    final value = widget.value;
    final focused = _focus.hasFocus;

    // The `active` fill is as tall as the line and a little more, and its
    // corners are concentric with the field's.
    final line =
        MediaQuery.textScalerOf(context).scale(textStyle.fontSize ?? 14) *
        (textStyle.height ?? 1);
    final segmentHeight = line + 4;
    final inset = math.max(0, (look.minHeight! - segmentHeight) / 2);
    final segmentRadius = BorderRadius.circular(
      math.max(2, corner - inset),
    );

    Widget segment(TimeSegment part) {
      final active = focused && _segment == part;
      final text = _text(part, value);
      final next = _text(part, _stepped(part, 1));
      final previous = _text(part, _stepped(part, -1));
      return Semantics(
        label: switch (part) {
          TimeSegment.hour => widget.hourLabel,
          TimeSegment.minute => widget.minuteLabel,
          TimeSegment.period => widget.periodLabel,
        },
        value: text,
        increasedValue: next,
        decreasedValue: previous,
        focusable: _enabled,
        focused: active,
        onIncrease: _enabled ? () => _step(part, 1) : null,
        onDecrease: _enabled ? () => _step(part, -1) : null,
        onTap: _enabled ? () => _select(part) : null,
        excludeSemantics: true,
        child: Listener(
          onPointerSignal: (event) => _onScroll(event, part),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _select(part),
            // The fill bleeds past the figures, so it never moves them.
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -_segmentPadding,
                  right: -_segmentPadding,
                  top: -2,
                  bottom: -2,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: active ? theme.colors.active : null,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: segmentRadius,
                      ),
                    ),
                  ),
                ),
                Text(text, style: textStyle),
              ],
            ),
          ),
        ),
      );
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        segment(TimeSegment.hour),
        ExcludeSemantics(
          child: Text(':', style: textStyle.copyWith(color: look.placeholder)),
        ),
        segment(TimeSegment.minute),
        if (!_use24) ...[
          ExcludeSemantics(child: Text(' ', style: textStyle)),
          segment(TimeSegment.period),
        ],
      ],
    );
    // The widest time holds the width, and the text starts at the left, as
    // an input's does.
    final sizer = Visibility.maintain(
      visible: false,
      child: Text(_use24 ? '23:59' : '12:59 PM', style: textStyle),
    );
    final text = Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [sizer, content],
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: Shortcuts(
        shortcuts: {
          const SingleActivator(LogicalKeyboardKey.arrowUp): const _Step(1),
          const SingleActivator(LogicalKeyboardKey.arrowDown): const _Step(-1),
          const SingleActivator(LogicalKeyboardKey.pageUp): const _Step(
            1,
            page: true,
          ),
          const SingleActivator(LogicalKeyboardKey.pageDown): const _Step(
            -1,
            page: true,
          ),
          const SingleActivator(LogicalKeyboardKey.home): const _Edge(
            last: false,
          ),
          const SingleActivator(LogicalKeyboardKey.end): const _Edge(
            last: true,
          ),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): _Move(
            rtl ? 1 : -1,
          ),
          const SingleActivator(LogicalKeyboardKey.arrowRight): _Move(
            rtl ? -1 : 1,
          ),
          const CharacterActivator(':'): const _Move(1),
          const SingleActivator(LogicalKeyboardKey.backspace):
              const _ForgetDigits(),
          SingleActivator(
            LogicalKeyboardKey.keyV,
            meta: apple,
            control: !apple,
          ): const _Paste(),
          for (var digit = 0; digit < 10; digit++)
            CharacterActivator('$digit'): _Digit(digit),
          if (!_use24) ...const {
            CharacterActivator('a'): _Period(pm: false),
            CharacterActivator('A'): _Period(pm: false),
            CharacterActivator('p'): _Period(pm: true),
            CharacterActivator('P'): _Period(pm: true),
          },
        },
        child: Actions(
          actions: {
            _Step: CallbackAction<_Step>(
              onInvoke: (intent) => _step(
                _segment,
                intent.page ? intent.by * _page(_segment) : intent.by,
              ),
            ),
            _Edge: CallbackAction<_Edge>(
              onInvoke: (intent) => _goToEdge(last: intent.last),
            ),
            _Move: CallbackAction<_Move>(
              onInvoke: (intent) => _move(intent.by),
            ),
            _Digit: CallbackAction<_Digit>(
              onInvoke: (intent) => _typeDigit(intent.digit),
            ),
            _Period: CallbackAction<_Period>(
              onInvoke: (intent) => _setPeriod(pm: intent.pm),
            ),
            _ForgetDigits: CallbackAction<_ForgetDigits>(
              onInvoke: (_) {
                _buffer = '';
                return null;
              },
            ),
            _Paste: CallbackAction<_Paste>(onInvoke: (_) => _paste()),
          },
          child: Focus(
            focusNode: _focus,
            autofocus: widget.autofocus,
            canRequestFocus: _enabled,
            child: CoilInteractionDetector(
              states: _states,
              enabled: _enabled,
              trackPress: false,
              cursor: _enabled ? SystemMouseCursors.text : null,
              child: Opacity(
                opacity: _enabled ? 1 : sizes.disabledOpacity,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _focus.requestFocus(),
                  child: ListenableBuilder(
                    listenable: _states,
                    builder: (context, child) {
                      final states = _states.value;
                      final hovered =
                          _enabled && states.contains(WidgetState.hovered);
                      final resolved = {
                        if (states.contains(WidgetState.focused))
                          WidgetState.focused,
                        if (hovered) WidgetState.hovered,
                      };
                      final border = look.border!.resolve(resolved)!;
                      final fill = look.fill!.resolve(resolved)!;
                      return TrackBuilder(
                        initialValues: [
                          CoilInputTrack.border.value(border),
                          CoilInputTrack.fill.value(fill),
                        ],
                        animations: [
                          CoilInputTrack.border([
                            .to(
                              border,
                              motion: colorMotion(CoilInputTrack.border),
                            ),
                          ]),
                          CoilInputTrack.fill([
                            .to(
                              fill,
                              motion: colorMotion(CoilInputTrack.fill),
                            ),
                          ]),
                        ],
                        builder: (context, value, child) => Container(
                          constraints: BoxConstraints(
                            minHeight: look.minHeight!,
                          ),
                          decoration: CoilRelief.decorate(
                            ShapeDecoration(
                              color: value(CoilInputTrack.fill),
                              shape: RoundedSuperellipseBorder(
                                borderRadius: BorderRadius.circular(corner),
                                side: BorderSide(
                                  color: value(CoilInputTrack.border),
                                ),
                              ),
                            ),
                            CoilTheme.reliefOf(
                              context,
                              CoilReliefRole.field,
                              override: look.plasticity,
                              hover: hovered ? 1 : 0,
                              enabled: _enabled,
                            ),
                          ),
                          child: child,
                        ),
                        child: child,
                      );
                    },
                    child: Center(
                      widthFactor: 1,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: sizes.controlPaddingX - 1,
                        ),
                        child: text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Steps the focused segment: Up and Down, and a [page] of them with the
/// Page keys.
class _Step extends Intent {
  const _Step(this.by, {this.page = false});

  final int by;
  final bool page;
}

/// Goes to the focused segment's first or [last] value: Home and End.
class _Edge extends Intent {
  const _Edge({required this.last});

  final bool last;
}

/// Moves [by] segments: -1 or 1.
class _Move extends Intent {
  const _Move(this.by);

  final int by;
}

/// A [digit] typed into the focused segment.
class _Digit extends Intent {
  const _Digit(this.digit);

  final int digit;
}

/// "a" or "p": AM, or [pm].
class _Period extends Intent {
  const _Period({required this.pm});

  final bool pm;
}

/// Backspace: the digits typed so far are forgotten.
class _ForgetDigits extends Intent {
  const _ForgetDigits();
}

/// Pastes a time.
class _Paste extends Intent {
  const _Paste();
}
