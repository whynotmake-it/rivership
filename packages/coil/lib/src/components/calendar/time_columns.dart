import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/calendar/calendar_layout.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A time of day, picked in two columns that snap: hours and minutes.
///
/// Drag or scroll a column, or focus it and use the arrow keys. A flick
/// keeps its momentum and lands on a row; the columns wrap around. Each
/// row that passes the band ticks a haptic. Screen readers adjust each
/// column up and down. Minutes step by [minuteInterval]; a [value] between
/// steps shows the step below it.
///
/// The columns show [visibleRows] rows, each a line of body text (tabular
/// figures) and the tier's gap, grown with the text scale: 28 tall on
/// pointer, 34 on touch. The picked row sits in an `active` band with the
/// day cells' radius; the rows fade out toward the top and bottom edges.
class CoilTimeColumns extends StatelessWidget {
  /// Creates the time columns.
  const CoilTimeColumns({
    required this.value,
    required this.onChanged,
    super.key,
    this.minuteInterval = 5,
    this.hourLabel = 'Hour',
    this.minuteLabel = 'Minute',
    this.motion,
  }) : assert(
         minuteInterval > 0 && 60 % minuteInterval == 0,
         'minuteInterval must divide 60.',
       );

  /// The time shown, in 24-hour form.
  final ({int hour, int minute}) value;

  /// Called as a column settles on a new value.
  final ValueChanged<({int hour, int minute})>? onChanged;

  /// The minute step.
  final int minuteInterval;

  /// The hour column's name for screen readers.
  final String hourLabel;

  /// The minute column's name for screen readers.
  final String minuteLabel;

  /// Overrides the theme's motion tokens; a column settles on `standard`.
  final CoilMotion? motion;

  /// How many rows the columns show: the picked one and two on each side.
  static const visibleRows = 5;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final text = CoilTheme.textOf(context);
    final extent = calendarTimeRowExtent(context, metrics, text.body);
    // As wide as a calendar day and a half: the two digits, with room to
    // grab either column.
    final width = calendarWidths(context).cell * 1.5;
    final radius = BorderRadius.circular(theme.shape.radii(metrics.tier).item);
    final minuteSteps = 60 ~/ minuteInterval;
    final onChanged = this.onChanged;
    return SizedBox(
      height: extent * visibleRows,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The band the picked values sit in: the selected fill, with the
          // day cells' corners.
          Positioned.fill(
            child: Center(
              child: SizedBox(
                height: extent,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: theme.colors.active,
                    shape: RoundedSuperellipseBorder(borderRadius: radius),
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Column(
                label: hourLabel,
                count: 24,
                index: value.hour,
                extent: extent,
                width: width,
                motion: motion,
                text: (i) => i.toString().padLeft(2, '0'),
                onChanged: onChanged == null
                    ? null
                    : (i) => onChanged((hour: i, minute: value.minute)),
              ),
              ExcludeSemantics(
                child: Text(
                  ':',
                  style: text.body.tabular.copyWith(fontWeight: text.emphasis),
                ),
              ),
              _Column(
                label: minuteLabel,
                count: minuteSteps,
                index: value.minute ~/ minuteInterval,
                extent: extent,
                width: width,
                motion: motion,
                text: (i) => (i * minuteInterval).toString().padLeft(2, '0'),
                onChanged: onChanged == null
                    ? null
                    : (i) => onChanged((
                        hour: value.hour,
                        minute: i * minuteInterval,
                      )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One wrapping, snapping column of [count] values.
class _Column extends StatefulWidget {
  const _Column({
    required this.label,
    required this.count,
    required this.index,
    required this.extent,
    required this.width,
    required this.text,
    required this.onChanged,
    required this.motion,
  });

  final CoilMotion? motion;
  final String label;
  final int count;
  final int index;
  final double extent;
  final double width;
  final String Function(int index) text;
  final ValueChanged<int>? onChanged;

  @override
  State<_Column> createState() => _ColumnState();
}

class _ColumnState extends State<_Column> {
  late final _scroll = FixedExtentScrollController(
    initialItem: widget.index,
  );
  final _focus = FocusNode(debugLabel: 'CoilTimeColumns');

  @override
  void didUpdateWidget(_Column oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follows a value changed from outside, the short way round.
    final shown = _scroll.hasClients
        ? _scroll.selectedItem % widget.count
        : widget.index;
    if (shown != widget.index && _scroll.hasClients) {
      var delta = widget.index - shown;
      if (delta > widget.count / 2) delta -= widget.count;
      if (delta < -widget.count / 2) delta += widget.count;
      _scroll.jumpToItem(_scroll.selectedItem + delta);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _step(int by) {
    if (widget.onChanged == null) return;
    widget.onChanged!((widget.index + by) % widget.count);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final colors = theme.colors;
    final text = CoilTheme.textOf(context);
    final value = widget.text(widget.index);
    return Semantics(
      label: widget.label,
      value: value,
      increasedValue: widget.text((widget.index + 1) % widget.count),
      decreasedValue: widget.text((widget.index - 1) % widget.count),
      onIncrease: widget.onChanged == null ? null : () => _step(1),
      onDecrease: widget.onChanged == null ? null : () => _step(-1),
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowUp): _StepIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowDown): _StepIntent(1),
        },
        child: Actions(
          actions: {
            _StepIntent: CallbackAction<_StepIntent>(
              onInvoke: (intent) => _step(intent.by),
            ),
          },
          child: Focus(
            focusNode: _focus,
            canRequestFocus: widget.onChanged != null,
            child: ListenableBuilder(
              listenable: _focus,
              builder: (context, child) => DecoratedBox(
                decoration: ShapeDecoration(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(
                      theme.shape.radii(metrics.tier).focusRing,
                    ),
                    side:
                        _focus.hasFocus &&
                            CoilInputModality.instance.value ==
                                CoilModality.keyboard
                        ? BorderSide(
                            color: theme.focusRing.colorOf(colors),
                            width: theme.focusRing.width,
                          )
                        : BorderSide.none,
                  ),
                ),
                child: child,
              ),
              child: SizedBox(
                width: widget.width,
                child: ExcludeSemantics(
                  // The rows fade out over two rows toward each edge.
                  child: CoilScrollEdgeFade(
                    extent: widget.extent * 2,
                    child: ListWheelScrollView.useDelegate(
                      controller: _scroll,
                      itemExtent: widget.extent,
                      physics: CalendarWheelPhysics(
                        motion: CoilTheme.motionOf(
                          context,
                          override: widget.motion,
                        ).standard,
                      ),
                      // Nearly flat rows, as the design asks: no 3D drum.
                      diameterRatio: 8,
                      onSelectedItemChanged: (i) {
                        final index = i % widget.count;
                        if (index == widget.index) return;
                        unawaited(
                          CoilHaptics.play(context, CoilHapticEvent.toggle),
                        );
                        widget.onChanged?.call(index);
                      },
                      childDelegate: ListWheelChildLoopingListDelegate(
                        children: [
                          for (var i = 0; i < widget.count; i++)
                            Center(
                              child: Text(
                                widget.text(i),
                                maxLines: 1,
                                softWrap: false,
                                style: i == widget.index
                                    ? text.body.tabular.copyWith(
                                        fontWeight: text.emphasis,
                                      )
                                    : text.muted.body.tabular,
                              ),
                            ),
                        ],
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

/// Steps a column [by] rows: Up and Down.
class _StepIntent extends Intent {
  const _StepIntent(this.by);

  final int by;
}
