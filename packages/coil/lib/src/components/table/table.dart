// MotorInspectionScope is @experimental; the motor example uses it too.
// ignore_for_file: experimental_member_use
import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/scroll_area.dart';
import 'package:coil/src/components/table/table_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// The order a sorted column shows.
enum CoilSortDirection {
  /// Smallest first.
  ascending,

  /// Largest first.
  descending,
}

/// One column of a [CoilTable]: its header and how to build its cells.
///
/// Columns are flexible by default and share the table's width by [flex],
/// never narrower than [minWidth]. A [width] makes the column fixed. When
/// the columns can't fit, the table scrolls sideways.
@immutable
class CoilTableColumn<T> {
  /// Creates a column.
  const CoilTableColumn({
    required this.label,
    required this.cellBuilder,
    this.child,
    this.width,
    this.flex = 1,
    this.minWidth = 96,
    this.alignment = AlignmentDirectional.centerStart,
    this.sort,
    this.onSort,
  });

  /// The header text, also the column's name for assistive technology.
  final String label;

  /// Replaces the default `Text(label)` in the header.
  final Widget? child;

  /// Builds this column's cell for a row.
  final Widget Function(BuildContext context, T row) cellBuilder;

  /// A fixed width, padding included. Null makes the column flexible.
  final double? width;

  /// The column's share of the free width, when flexible.
  final int flex;

  /// The narrowest a flexible column gets, padding included.
  final double minWidth;

  /// Where the header and the cells sit in the column. Use
  /// [AlignmentDirectional.centerEnd] for numbers.
  final AlignmentGeometry alignment;

  /// The order the column is sorted in, or null when it isn't the sort key.
  final CoilSortDirection? sort;

  /// Makes the header pressable, to sort by this column. The table doesn't
  /// sort: sort [CoilTable.rows] and set [sort].
  final VoidCallback? onSort;
}

/// A table of [rows] in [columns], with a header row and hairline rules.
///
/// On the pointer tier rows rest muted and turn foreground when lit or
/// selected; touch rows rest at foreground. A hovering pointer's highlight
/// glides between rows, and a finger pressing a row fills it until it
/// lifts. Selected rows ([values]) merge into one block.
///
/// The table is one tab stop. The arrow keys move the active row, Space
/// selects it and Enter activates it; Left and Right scroll a wide table.
/// A tap activates the row when there's [onRowActivated], and otherwise
/// toggles its selection.
///
/// When the columns don't fit, the table scrolls sideways and its edges
/// fade where there's more.
class CoilTable<T> extends StatefulWidget {
  /// Creates a table.
  const CoilTable({
    required this.columns,
    required this.rows,
    super.key,
    this.values = const {},
    this.onChanged,
    this.onRowActivated,
    this.empty,
    this.emptyRows = 3,
    this.semanticLabel,
    this.size,
    this.focusNode,
    this.autofocus = false,
    this.controller,
    this.motion,
    this.style,
  });

  /// The columns, in reading order.
  final List<CoilTableColumn<T>> columns;

  /// The rows' data, in order.
  final List<T> rows;

  /// The selected rows.
  final Set<T> values;

  /// Called with the new selection. Null makes rows unselectable.
  final ValueChanged<Set<T>>? onChanged;

  /// Called when a row is opened with Enter (or a tap).
  final ValueChanged<T>? onRowActivated;

  /// Shown when [rows] is empty, centered in [emptyRows] rows of height.
  final Widget? empty;

  /// How many rows of height the [empty] state holds, so the layout doesn't
  /// jump while data loads.
  final int emptyRows;

  /// A name for the table.
  final String? semanticLabel;

  /// Pins the table to one size step.
  final CoilSize? size;

  /// The table's focus node.
  final FocusNode? focusNode;

  /// Whether the table takes focus when first built.
  final bool autofocus;

  /// The horizontal scroll controller; one is created if null.
  final ScrollController? controller;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Overrides for this table's look, on top of the theme's
  /// [CoilTableStyle] and the defaults.
  final CoilTableStyle? style;

  @override
  State<CoilTable<T>> createState() => _CoilTableState<T>();
}

class _CoilTableState<T> extends State<CoilTable<T>>
    with TickerProviderStateMixin {
  final _states = WidgetStatesController();
  final _active = CoilActiveItemController();
  late final _selection = CoilSelectionPainter(vsync: this);
  late final _ring = CoilHighlightPainter(
    vsync: this,
    debugLabel: 'CoilTable ring',
  );
  late final _spring = CoilScrollSpring(
    vsync: this,
    debugLabel: 'CoilTable scroll',
  );

  FocusNode? _ownFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'CoilTable'));

  ScrollController? _ownController;
  ScrollController get _scroll =>
      widget.controller ?? (_ownController ??= ScrollController());

  @override
  void didUpdateWidget(CoilTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = _active.index;
    if (index != null && index >= widget.rows.length) _active.clear();
  }

  @override
  void dispose() {
    _states.dispose();
    _active.dispose();
    _selection.dispose();
    _ring.dispose();
    _spring.dispose();
    _ownFocusNode?.dispose();
    _ownController?.dispose();
    super.dispose();
  }

  void _onFocusChange(bool focused) {
    if (focused) {
      // Keyboard focus lands on a row, so the arrows have a start.
      if (_active.index == null &&
          widget.rows.isNotEmpty &&
          CoilInputModality.instance.value == CoilModality.keyboard) {
        _active.first(count: widget.rows.length);
      }
    } else if (_active.via == CoilModality.keyboard) {
      _active.clear();
    }
  }

  void _toggle(T row) {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    final next = {...widget.values};
    if (!next.remove(row)) next.add(row);
    onChanged(next);
  }

  void _tap(T row) {
    if (widget.onRowActivated case final activate?) {
      activate(row);
    } else {
      _toggle(row);
    }
  }

  void _scrollBy(double delta) {
    if (!_scroll.hasClients) return;
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    _spring.scrollTo(
      _scroll,
      _spring.targetOf(_scroll) + delta,
      motion.standard,
    );
  }

  /// One Left/Right step, as in `CoilScrollArea`.
  static const _line = 60.0;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Only the table's own node: inner header buttons handle their keys.
    if (FocusManager.instance.primaryFocus != node) {
      return KeyEventResult.ignored;
    }
    final count = widget.rows.length;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final key = event.logicalKey;
    switch (key) {
      case LogicalKeyboardKey.arrowDown when count > 0:
        _active.move(1, count: count);
      case LogicalKeyboardKey.arrowUp when count > 0:
        _active.move(-1, count: count);
      case LogicalKeyboardKey.home when count > 0:
        _active.first(count: count);
      case LogicalKeyboardKey.end when count > 0:
        _active.last(count: count);
      case LogicalKeyboardKey.arrowRight:
        _scrollBy(rtl ? -_line : _line);
      case LogicalKeyboardKey.arrowLeft:
        _scrollBy(rtl ? _line : -_line);
      case LogicalKeyboardKey.space when _active.index != null:
        _active.activate(_active.index, via: CoilModality.keyboard);
        _toggle(widget.rows[_active.index!]);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter
          when _active.index != null && widget.onRowActivated != null:
        widget.onRowActivated!(widget.rows[_active.index!]);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final style = CoilTableStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilTableStyle>(context)).merge(widget.style);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final scrollStyle = CoilScrollAreaStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilScrollAreaStyle>(context));
    final emphasis =
        metrics.tier == CoilTier.touch || MediaQuery.highContrastOf(context);
    final rows = widget.rows;

    _selection.update(
      selected: {
        for (final (i, row) in rows.indexed)
          if (widget.values.contains(row)) i,
      },
      color: style.selection!,
      radius: style.radius!,
      motion: motion,
    );

    Widget table(double maxWidth) {
      final widths = _columnWidths(widget.columns, maxWidth, metrics);
      final width = widths.fold<double>(0, (a, b) => a + b);
      final body = rows.isEmpty
          ? _EmptyRow(
              height: metrics.controlHeight * widget.emptyRows,
              style: style,
              child: widget.empty,
            )
          : ListenableBuilder(
              listenable: Listenable.merge([
                _active,
                _focusNode,
                CoilInputModality.instance,
              ]),
              builder: (context, child) {
                // The ring sits on the active row while the keyboard drives
                // it, inset because the table clips.
                _ring.update(
                  target:
                      _focusNode.hasPrimaryFocus &&
                          _active.keyboardDriven &&
                          CoilInputModality.instance.value ==
                              CoilModality.keyboard
                      ? _active.index
                      : null,
                  fadeIn: false,
                  motion: motion.quick,
                  exitMotion: motion.fadeExit,
                  exitTravelMotion: motion.quick,
                  fade: motion.fade,
                  inflate: -1,
                  decoration: ShapeDecoration(
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(style.radius! - 1),
                      side: BorderSide(
                        color: theme.colors.focusRing,
                        width: theme.focusRingWidth,
                      ),
                    ),
                  ),
                );
                return child!;
              },
              child: CoilHoverRegion(
                activeItem: _active,
                followFocus: false,
                highlightColor: style.highlight,
                highlightRadius: style.radius,
                background: [_selection],
                foreground: [_ring],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, row) in rows.indexed)
                      CoilHoverItem(
                        index: i,
                        child: _BodyRow<T>(
                          index: i,
                          row: row,
                          columns: widget.columns,
                          widths: widths,
                          selected: widget.values.contains(row),
                          nextSelected:
                              i + 1 < rows.length &&
                              widget.values.contains(rows[i + 1]),
                          last: i == rows.length - 1,
                          emphasis: emphasis,
                          metrics: metrics,
                          style: style,
                          motion: motion,
                          onPressed:
                              widget.onRowActivated == null &&
                                  widget.onChanged == null
                              ? null
                              : () => _tap(row),
                        ),
                      ),
                  ],
                ),
              ),
            );
      return SizedBox(
        width: width,
        child: Semantics(
          container: true,
          role: SemanticsRole.table,
          label: widget.semanticLabel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderRow<T>(
                columns: widget.columns,
                widths: widths,
                metrics: metrics,
                style: style,
                motion: motion,
              ),
              body,
            ],
          ),
        ),
      );
    }

    return MotorInspectionScope(
      group: 'CoilTable',
      child: CoilInteractionDetector(
        states: _states,
        focusNode: _focusNode,
        trackPress: false,
        child: Focus(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onKeyEvent: _onKey,
          onFocusChange: _onFocusChange,
          child: ScrollConfiguration(
            behavior: CoilScrollBehavior(
              tier: metrics.tier,
              look: CoilScrollbarLook(
                color: scrollStyle.thumb!,
                hoverColor: scrollStyle.thumbHovered!,
                dragColor: scrollStyle.thumbDragged!,
                thickness: scrollStyle.thickness!,
                hoverThickness: scrollStyle.hoverThickness!,
              ),
            ),
            child: CoilEdgeFade(
              axis: Axis.horizontal,
              extent: style.fadeExtent!,
              child: NotificationListener<ScrollStartNotification>(
                // A drag takes over from a keyboard scroll.
                onNotification: (n) {
                  if (n.dragDetails != null) _spring.stop();
                  return false;
                },
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    child: table(constraints.maxWidth),
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

/// Resolves [columns] to widths for [available] width: fixed columns take
/// their width, flexible ones share the rest by flex without going under
/// their minimum. When even the minimums don't fit, they get the minimum
/// and the table scrolls.
List<double> _columnWidths<T>(
  List<CoilTableColumn<T>> columns,
  double available,
  CoilMetrics metrics,
) {
  final pad = metrics.controlPaddingX * 2;
  final widths = [
    for (final c in columns) c.width ?? math.max(c.minWidth, pad),
  ];
  final flexible = {
    for (final (i, c) in columns.indexed)
      if (c.width == null) i,
  };
  if (!available.isFinite) return widths;
  // Columns pinned at their minimum leave the share; repeat until the
  // others' shares all clear their minimums.
  while (flexible.isNotEmpty) {
    final fixed = [
      for (final (i, w) in widths.indexed)
        if (!flexible.contains(i)) w,
    ].fold<double>(0, (a, b) => a + b);
    final free = available - fixed;
    final flex = flexible.fold(0, (a, i) => a + columns[i].flex);
    final pinned = <int>{};
    for (final i in flexible) {
      final share = flex == 0 ? 0.0 : free * columns[i].flex / flex;
      final minimum = math.max(columns[i].minWidth, pad);
      if (share < minimum) {
        widths[i] = minimum;
        pinned.add(i);
      } else {
        widths[i] = share;
      }
    }
    if (pinned.isEmpty) break;
    flexible.removeAll(pinned);
  }
  return widths;
}

/// The header row: semibold captions, a rule below, sortable cells
/// pressable.
class _HeaderRow<T> extends StatelessWidget {
  const _HeaderRow({
    required this.columns,
    required this.widths,
    required this.metrics,
    required this.style,
    required this.motion,
  });

  final List<CoilTableColumn<T>> columns;
  final List<double> widths;
  final CoilMetrics metrics;
  final CoilTableStyle style;
  final CoilMotion motion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      role: SemanticsRole.row,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: style.rule!)),
        ),
        // One row: measuring it lets every header fill reach full height.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, column) in columns.indexed)
                SizedBox(
                  width: widths[i],
                  child: _HeaderCell(
                    column: column,
                    metrics: metrics,
                    style: style,
                    motion: motion,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.column,
    required this.metrics,
    required this.style,
    required this.motion,
  });

  final CoilTableColumn<Object?> column;
  final CoilMetrics metrics;
  final CoilTableStyle style;
  final CoilMotion motion;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(style.radius!);
    final theme = CoilTheme.of(context);
    Widget content(Set<WidgetState> states) {
      final color = style.headerLabel!.resolve(states)!;
      final sort = column.sort;
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: metrics.controlHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.controlPaddingX,
            vertical: metrics.controlPaddingY(metrics.caption),
          ),
          child: Align(
            alignment: column.alignment,
            widthFactor: 1,
            heightFactor: 1,
            child: MotionBuilder<Color>(
              value: color,
              converter: MotionConverter.colorRgb,
              motion: motion.fade,
              debugLabel: 'CoilTable header label',
              builder: (context, color, _) => IconTheme(
                data: IconThemeData(
                  size: metrics.iconSize,
                  applyTextScaling: true,
                  color: color,
                ),
                child: DefaultTextStyle(
                  style: style.headerStyle!.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Flexible(child: column.child ?? Text(column.label)),
                      if (sort != null) _SortGlyph(sort),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final onSort = column.onSort;
    return Semantics(
      container: true,
      role: SemanticsRole.columnHeader,
      button: onSort != null,
      enabled: onSort == null ? null : true,
      label: column.child == null ? null : column.label,
      value: switch (column.sort) {
        CoilSortDirection.ascending => 'Sorted ascending',
        CoilSortDirection.descending => 'Sorted descending',
        null => null,
      },
      child: onSort == null
          ? content(const {})
          : CoilInteraction(
              onPressed: onSort,
              builder: (context, states, _) => CoilFocusRing(
                visible: states.contains(WidgetState.focused),
                borderRadius: radius,
                // Inset, inside the table's clip.
                offset: -(1 + theme.focusRingWidth),
                child: MotionBuilder<Color>(
                  value: style.headerFill!.resolve(states)!,
                  converter: MotionConverter.colorRgb,
                  motion: motion.fade,
                  debugLabel: 'CoilTable header fill',
                  builder: (context, fill, child) => DecoratedBox(
                    decoration: ShapeDecoration(
                      color: fill,
                      shape: RoundedSuperellipseBorder(borderRadius: radius),
                    ),
                    child: child,
                  ),
                  child: content(states),
                ),
              ),
            ),
    );
  }
}

/// One body row. It draws only its label colors, its rule and its own
/// press fill on touch; the table's layer paints the highlight and the
/// selection underneath.
class _BodyRow<T> extends StatefulWidget {
  const _BodyRow({
    required this.index,
    required this.row,
    required this.columns,
    required this.widths,
    required this.selected,
    required this.nextSelected,
    required this.last,
    required this.emphasis,
    required this.metrics,
    required this.style,
    required this.motion,
    required this.onPressed,
  });

  final int index;
  final T row;
  final List<CoilTableColumn<T>> columns;
  final List<double> widths;
  final bool selected;
  final bool nextSelected;
  final bool last;

  /// Rest at foreground (touch, high contrast).
  final bool emphasis;
  final CoilMetrics metrics;
  final CoilTableStyle style;
  final CoilMotion motion;
  final VoidCallback? onPressed;

  @override
  State<_BodyRow<T>> createState() => _BodyRowState<T>();
}

class _BodyRowState<T> extends State<_BodyRow<T>> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _BodyRow(:index, :metrics, :style, :motion) = widget;
    final lit = CoilHoverRegion.maybeOf(context)?.activeIndex;
    final color = style.cellLabel!.resolve({
      if (lit == index) WidgetState.hovered,
      if (widget.selected) WidgetState.selected,
      if (widget.emphasis) WidgetState.focused,
    })!;
    // The rule hides where a fill touches it, so fills read as one shape.
    final ruleHidden =
        widget.last ||
        lit == index ||
        lit == index + 1 ||
        widget.selected ||
        widget.nextSelected;
    final radius = BorderRadius.circular(style.radius!);

    return Semantics(
      container: true,
      role: SemanticsRole.row,
      selected: widget.onPressed == null ? null : widget.selected,
      onTap: widget.onPressed,
      child: CoilInteractionDetector(
        states: _states,
        enabled: widget.onPressed != null,
        onTap: widget.onPressed,
        cursor: widget.onPressed != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        excludeFromSemantics: true,
        child: ListenableBuilder(
          listenable: _states,
          builder: (context, child) {
            final states = _states.value;
            final pressed = states.contains(WidgetState.pressed);
            return MotionBuilder<Color>(
              // A finger pressing a row gets a fill that ends with the
              // press; hovering pointers already show the highlight.
              value: pressed && !states.contains(WidgetState.hovered)
                  ? style.pressedFill!
                  : style.pressedFill!.withValues(alpha: 0),
              converter: MotionConverter.colorRgb,
              motion: pressed ? motion.fade : motion.fadeExit,
              debugLabel: 'CoilTable row press',
              builder: (context, fill, child) => DecoratedBox(
                decoration: ShapeDecoration(
                  color: fill,
                  shape: RoundedSuperellipseBorder(borderRadius: radius),
                ),
                child: child,
              ),
              child: child,
            );
          },
          child: MotionBuilder<Color>(
            value: ruleHidden ? style.rule!.withValues(alpha: 0) : style.rule!,
            converter: MotionConverter.colorRgb,
            motion: ruleHidden ? motion.fadeExit : motion.fade,
            debugLabel: 'CoilTable rule',
            builder: (context, rule, child) => DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: rule)),
              ),
              child: child,
            ),
            child: MotionBuilder<Color>(
              value: color,
              converter: MotionConverter.colorRgb,
              motion: motion.fade,
              debugLabel: 'CoilTable row label',
              builder: (context, color, _) => IconTheme(
                data: IconThemeData(
                  size: metrics.iconSize,
                  applyTextScaling: true,
                  color: color,
                ),
                child: DefaultTextStyle(
                  style: style.cellStyle!.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: Row(
                    children: [
                      for (final (i, column) in widget.columns.indexed)
                        SizedBox(
                          width: widget.widths[i],
                          child: Semantics(
                            container: true,
                            role: SemanticsRole.cell,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: metrics.controlHeight,
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: metrics.controlPaddingX,
                                  vertical: metrics.controlPaddingY(
                                    metrics.body,
                                  ),
                                ),
                                child: Align(
                                  alignment: column.alignment,
                                  heightFactor: 1,
                                  child: column.cellBuilder(
                                    context,
                                    widget.row,
                                  ),
                                ),
                              ),
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

/// The empty state: [child] centered in a fixed number of rows' height, as
/// one row with one cell for assistive technology.
class _EmptyRow extends StatelessWidget {
  const _EmptyRow({
    required this.height,
    required this.style,
    required this.child,
  });

  final double height;
  final CoilTableStyle style;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      role: SemanticsRole.row,
      child: Semantics(
        container: true,
        role: SemanticsRole.cell,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Center(
            child: DefaultTextStyle(
              style: style.cellStyle!.copyWith(
                color: CoilTheme.of(context).colors.mutedForeground,
              ),
              textAlign: TextAlign.center,
              child: child ?? const SizedBox(),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sort direction glyph: a chevron, drawn like coil's other glyphs.
class _SortGlyph extends StatelessWidget {
  const _SortGlyph(this.direction);

  final CoilSortDirection direction;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(CoilIconSize.of(context) * 0.875),
    painter: _ChevronPainter(
      IconTheme.of(context).color ?? const Color(0xFF000000),
      up: direction == CoilSortDirection.ascending,
    ),
  );
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.color, {required this.up});

  final Color color;
  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final (tip, base) = up ? (9.0, 15.0) : (15.0, 9.0);
    canvas.drawPath(
      Path()
        ..moveTo(6 * s, base * s)
        ..lineTo(12 * s, tip * s)
        ..lineTo(18 * s, base * s),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color || old.up != up;
}
