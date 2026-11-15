// MotorInspectionScope is @experimental; the motor example uses it too.
// ignore_for_file: experimental_member_use
import 'dart:ui' show SemanticsRole;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/scroll_area.dart';
import 'package:coil/src/components/table/table_body.dart';
import 'package:coil/src/components/table/table_column.dart';
import 'package:coil/src/components/table/table_header.dart';
import 'package:coil/src/components/table/table_row.dart';
import 'package:coil/src/components/table/table_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// A table of [rows] in [columns]. Rows can be selected ([values]) or
/// opened ([onRowActivated]).
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
    this.labels = const CoilTableLabels(),
    this.motion,
    this.motions,
    this.style,
  });

  /// The columns, in reading order.
  final List<CoilTableColumn<T>> columns;

  /// The rows' data, in order. Each row must be distinct (`==`): the table
  /// follows rows by value, so the active row and the selection stay on
  /// their data when the rows are sorted.
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

  /// The texts the table announces.
  final CoilTableLabels labels;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions for this table, keyed by [CoilTableTrack]s. They win
  /// over the theme's [CoilThemeData.trackMotions] and the tokens.
  final Map<CoilTableTrack<Object>, Motion>? motions;

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
    if (index == null) return;
    // A keyboard user's active row follows its data through a reorder. A
    // pointer's stays where the pointer is.
    if (_active.via == CoilModality.keyboard && index < oldWidget.rows.length) {
      final moved = widget.rows.indexOf(oldWidget.rows[index]);
      if (moved == -1) {
        _active.clear();
      } else if (moved != index) {
        _active.activate(moved, via: CoilModality.keyboard);
      }
    } else if (index >= widget.rows.length) {
      _active.clear();
    }
  }

  @override
  void dispose() {
    _states.dispose();
    _active.dispose();
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

  Motion _track(
    CoilTableTrack<Object> track,
    Motion token, {
    bool spatial = true,
  }) => CoilTheme.trackMotionOf(
    context,
    track,
    instance: widget.motions,
    token: token,
    spatial: spatial,
  );

  /// Scrolls one line step toward the end ([steps] 1) or the start (-1).
  void _scrollLine(int steps) {
    if (!_scroll.hasClients) return;
    final line = _scrollStyle(context).lineStep!;
    CoilScrollSpring.scrollTo(
      _scroll,
      CoilScrollSpring.targetOf(_scroll) + steps * line,
      CoilTheme.motionOf(context, override: widget.motion).standard,
    );
  }

  CoilScrollAreaStyle _scrollStyle(BuildContext context) =>
      CoilScrollAreaStyle.fallback(
        CoilTheme.of(context),
        CoilTheme.metricsOf(context, size: widget.size),
      ).merge(CoilTheme.styleOf<CoilScrollAreaStyle>(context));

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
        _scrollLine(rtl ? -1 : 1);
      case LogicalKeyboardKey.arrowLeft:
        _scrollLine(rtl ? 1 : -1);
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
      highContrast: MediaQuery.maybeHighContrastOf(context) ?? false,
    ).merge(CoilTheme.styleOf<CoilTableStyle>(context)).merge(widget.style);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final rowMotions = (
      press: _track(CoilTableTrack.rowPress, motion.fade, spatial: false),
      pressExit: _track(
        CoilTableTrack.rowPress,
        motion.fadeExit,
        spatial: false,
      ),
      rule: _track(CoilTableTrack.rule, motion.fade, spatial: false),
      ruleExit: _track(CoilTableTrack.rule, motion.fadeExit, spatial: false),
      label: _track(CoilTableTrack.rowLabel, motion.fade, spatial: false),
    );
    final rows = widget.rows;

    final selection = CoilSelectionBlocks(
      selected: {
        for (final (i, row) in rows.indexed)
          if (widget.values.contains(row)) i,
      },
      color: style.selection!,
      radius: style.radius!,
      motion: motion.copyWith(
        standard: _track(CoilTableTrack.selection, motion.standard),
      ),
    );

    Widget table(double maxWidth) {
      final widths = tableColumnWidths(widget.columns, maxWidth, metrics);
      final width = widths.fold<double>(0, (a, b) => a + b);
      final body = rows.isEmpty
          ? TableEmptyRow(
              rows: widget.emptyRows,
              metrics: metrics,
              style: style,
              child: widget.empty,
            )
          : TableBody<T>(
              rows: rows,
              values: widget.values,
              columns: widget.columns,
              widths: widths,
              metrics: metrics,
              style: style,
              active: _active,
              focusNode: _focusNode,
              selection: selection,
              motion: motion,
              highlightMotion: _track(CoilTableTrack.highlight, motion.quick),
              ringMotion: _track(CoilTableTrack.ring, motion.quick),
              rowMotions: rowMotions,
              onTap: widget.onRowActivated == null && widget.onChanged == null
                  ? null
                  : _tap,
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
              TableHeaderRow<T>(
                columns: widget.columns,
                widths: widths,
                metrics: metrics,
                style: style,
                labels: widget.labels,
                fillMotion: _track(
                  CoilTableTrack.headerFill,
                  motion.fade,
                  spatial: false,
                ),
                labelMotion: _track(
                  CoilTableTrack.headerLabel,
                  motion.fade,
                  spatial: false,
                ),
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
          // The table is the tab stop and scrolls with Left and Right.
          child: CoilScrollArea.scrollable(
            controller: _scroll,
            axis: Axis.horizontal,
            keyboard: false,
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
    );
  }
}
