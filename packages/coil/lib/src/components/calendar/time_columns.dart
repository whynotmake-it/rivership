import 'package:coil/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A time of day, picked in two columns that snap: hours and minutes.
///
/// Drag or scroll a column, or focus it and use the arrow keys. The
/// columns wrap around. Screen readers adjust each column up and down.
/// Minutes step by [minuteInterval]; a [value] between steps shows the
/// step below it.
class CoilTimeColumns extends StatelessWidget {
  /// Creates the time columns.
  const CoilTimeColumns({
    required this.value,
    required this.onChanged,
    super.key,
    this.minuteInterval = 5,
    this.hourLabel = 'Hour',
    this.minuteLabel = 'Minute',
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

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final extent = metrics.controlHeight;
    final radius = BorderRadius.circular(theme.shape.radii(metrics.tier).item);
    final minuteSteps = 60 ~/ minuteInterval;
    final onChanged = this.onChanged;
    return SizedBox(
      height: extent * 5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The band the picked values sit in.
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
                text: (i) => i.toString().padLeft(2, '0'),
                onChanged: onChanged == null
                    ? null
                    : (i) => onChanged((hour: i, minute: value.minute)),
              ),
              ExcludeSemantics(
                child: Text(
                  ':',
                  style: theme.typography.style(
                    metrics.body,
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ),
              _Column(
                label: minuteLabel,
                count: minuteSteps,
                index: value.minute ~/ minuteInterval,
                extent: extent,
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
    required this.text,
    required this.onChanged,
  });

  final String label;
  final int count;
  final int index;
  final double extent;
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
    final value = widget.text(widget.index);
    return Semantics(
      label: widget.label,
      value: value,
      increasedValue: widget.text((widget.index + 1) % widget.count),
      decreasedValue: widget.text((widget.index - 1) % widget.count),
      onIncrease: widget.onChanged == null ? null : () => _step(1),
      onDecrease: widget.onChanged == null ? null : () => _step(-1),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _step(-1),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _step(1),
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
                          color: colors.focusRing,
                          width: theme.focusRingWidth,
                        )
                      : BorderSide.none,
                ),
              ),
              child: child,
            ),
            child: SizedBox(
              width: widget.extent * 1.5,
              child: ExcludeSemantics(
                child: ListWheelScrollView.useDelegate(
                  controller: _scroll,
                  itemExtent: widget.extent,
                  physics: const FixedExtentScrollPhysics(),
                  diameterRatio: 1.6,
                  onSelectedItemChanged: (i) {
                    final index = i % widget.count;
                    if (index != widget.index) widget.onChanged?.call(index);
                  },
                  childDelegate: ListWheelChildLoopingListDelegate(
                    children: [
                      for (var i = 0; i < widget.count; i++)
                        Center(
                          child: Text(
                            widget.text(i),
                            style: theme.typography.style(
                              metrics.body,
                              weight: i == widget.index
                                  ? CoilWeight.semibold
                                  : CoilWeight.normal,
                              color: i == widget.index
                                  ? colors.foreground
                                  : colors.mutedForeground,
                            ),
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
    );
  }
}
