import 'dart:math' as math;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The continuous weeks a calendar's days scroll through, in chunks of
/// whole week rows, one per month.
///
/// Every row belongs to exactly one month, the month whose 1st it holds. A
/// month's chunk is the rows from the one holding its 1st up to, not
/// including, the one holding the next month's 1st: 4 or 5 rows. So a day
/// is in the chunk of the row it's on, which is the next month's when it's
/// the end of a month that stops mid-week, and no week is shown twice or
/// left blank. A chunk starts at the first of [firstDayOfWeek] on or before
/// its month's 1st; its cell `index` counts days from there, seven to a row.
///
/// The list starts at [firstMonth]'s chunk and, when there is a [lastMonth],
/// ends with enough rows of the month after it (a chunk of its own, half
/// shown) to fill the six rows in view when the last month is at the top, as
/// every month's grid always has six rows. Without one it goes on.
///
/// All offsets are counted in weeks (rows), so they hold for any row
/// extent. The arithmetic is on days, not months, so none of it walks the
/// list: a calendar can start at the year 1.
@immutable
class CalendarWeeks {
  /// Creates the weeks from [firstMonth] to [lastMonth] (or without end),
  /// in rows starting on [firstDayOfWeek] ([DateTime.monday] to
  /// [DateTime.sunday]).
  const CalendarWeeks({
    required this.firstMonth,
    required this.firstDayOfWeek,
    this.lastMonth,
  });

  /// The rows in view: every calendar shows six.
  static const visibleRows = 6;

  /// The first month, whose chunk is first.
  final DateTime firstMonth;

  /// The last month, or null to go on.
  final DateTime? lastMonth;

  /// The weekday rows start on.
  final int firstDayOfWeek;

  /// How many months there are, or null without a last.
  int? get monthCount => switch (lastMonth) {
    final last? => indexOfMonth(last) + 1,
    null => null,
  };

  /// The rows of the half-shown chunk after the last month's, or 0.
  int get tailRows => switch (monthCount) {
    final count? => math.max(
      0,
      visibleRows - (weeksBefore(count) - weeksBefore(count - 1)),
    ),
    null => 0,
  };

  /// How many chunks there are, or null without a last month.
  int? get itemCount => switch (monthCount) {
    final count? => count + (tailRows > 0 ? 1 : 0),
    null => null,
  };

  /// The month of chunk [index].
  DateTime monthAt(int index) =>
      DateTime(firstMonth.year, firstMonth.month + index);

  /// The chunk of [month].
  int indexOfMonth(DateTime month) =>
      (month.year - firstMonth.year) * 12 + month.month - firstMonth.month;

  static int _days(DateTime utc) =>
      utc.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  /// The day number of the first cell of chunk [index].
  int _startDay(int index) {
    final month = monthAt(index);
    final first = DateTime.utc(month.year, month.month);
    return _days(first) - (first.weekday - firstDayOfWeek) % 7;
  }

  /// How many week rows come before chunk [index]: a chunk begins this many
  /// rows from the top of the list. For an index past the last month this
  /// goes on by the calendar, not by the tail.
  int weeksBefore(int index) => (_startDay(index) - _startDay(0)) ~/ 7;

  /// The row count at the end of chunk [index] counted as it's laid out:
  /// where its rows end, the tail's too.
  int _layoutWeeks(int index) => switch (monthCount) {
    final count? when index > count => weeksBefore(count) + tailRows,
    _ => weeksBefore(index),
  };

  /// The rows in the whole list, or null when it goes on.
  int? get totalWeeks => switch (monthCount) {
    final count? => _layoutWeeks(count + 1),
    null => null,
  };

  /// The rows in chunk [index].
  int rowsOf(int index) => _layoutWeeks(index + 1) - _layoutWeeks(index);

  /// How many rows into the list chunk [index] begins, as laid out.
  int layoutWeeksBefore(int index) => _layoutWeeks(index);

  /// The chunk that holds week row [week], counting from the top of the list.
  int itemAtWeek(int week) {
    if (week <= 0) return 0;
    // A chunk is 4 or 5 rows, so the answer is in this range.
    var low = math.max(0, week ~/ 5 - 1);
    var high = week ~/ 4 + 1;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (weeksBefore(middle) <= week) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return switch (itemCount) {
      final count? => math.min(low, count - 1),
      null => low,
    };
  }

  /// The day in cell [index] of chunk [item].
  DateTime day(int item, int index) {
    final month = monthAt(item);
    final first = DateTime.utc(month.year, month.month);
    final lead = (first.weekday - firstDayOfWeek) % 7;
    return DateTime(month.year, month.month, 1 - lead + index);
  }

  /// The chunk and cell index of [day], or null when it's not in the list.
  ({int item, int index})? locate(DateTime day) {
    final number = _days(DateTime.utc(day.year, day.month, day.day));
    if (number < _startDay(0)) return null;
    final item = itemAtWeek((number - _startDay(0)) ~/ 7);
    final index = number - _startDay(item);
    if (index >= rowsOf(item) * 7) return null;
    return (item: item, index: index);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarWeeks &&
      other.firstMonth == firstMonth &&
      other.lastMonth == lastMonth &&
      other.firstDayOfWeek == firstDayOfWeek;

  @override
  int get hashCode => Object.hash(firstMonth, lastMonth, firstDayOfWeek);
}

/// A sliver of a calendar's month chunks: each child is as tall as its rows
/// of [rowExtent], and its place comes from [weeks] by arithmetic, so a
/// list that starts at the year 1 lays out as fast as one that starts
/// today.
class CalendarChunkList extends SliverMultiBoxAdaptorWidget {
  /// Lays out the chunks of [weeks] from [delegate], rows [rowExtent] tall.
  const CalendarChunkList({
    required this.weeks,
    required this.rowExtent,
    required super.delegate,
    super.key,
  });

  /// The chunks.
  final CalendarWeeks weeks;

  /// The height of a row.
  final double rowExtent;

  @override
  RenderCalendarChunkList createRenderObject(BuildContext context) =>
      RenderCalendarChunkList(
        childManager: context as SliverMultiBoxAdaptorElement,
        weeks: weeks,
        rowExtent: rowExtent,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCalendarChunkList renderObject,
  ) => renderObject
    ..weeks = weeks
    ..rowExtent = rowExtent;
}

/// The render object of a [CalendarChunkList].
class RenderCalendarChunkList extends RenderSliverFixedExtentBoxAdaptor {
  /// Creates the sliver for [weeks] of rows [rowExtent] tall.
  RenderCalendarChunkList({
    required super.childManager,
    required this._weeks,
    required this._rowExtent,
  });

  /// The chunks.
  CalendarWeeks get weeks => _weeks;
  CalendarWeeks _weeks;
  set weeks(CalendarWeeks value) {
    if (value == _weeks) return;
    _weeks = value;
    markNeedsLayout();
  }

  /// The height of a row.
  double get rowExtent => _rowExtent;
  double _rowExtent;
  set rowExtent(double value) {
    if (value == _rowExtent) return;
    _rowExtent = value;
    markNeedsLayout();
  }

  @override
  double? get itemExtent => null;

  @override
  ItemExtentBuilder get itemExtentBuilder =>
      (index, dimensions) => weeks.rowsOf(index) * rowExtent;

  @override
  double indexToLayoutOffset(double itemExtent, int index) =>
      weeks.layoutWeeksBefore(index) * rowExtent;

  /// The row [offset] is in, a hair of rounding (what the framework's own
  /// extents allow) either side of a row's top counting as on it.
  int _firstRowAt(double offset) {
    final rows = offset / rowExtent;
    final nearest = rows.round();
    return (rows * rowExtent - nearest * rowExtent).abs() <
            precisionErrorTolerance
        ? nearest
        : rows.floor();
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset, double itemExtent) =>
      rowExtent > 0 ? weeks.itemAtWeek(_firstRowAt(scrollOffset)) : 0;

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    if (rowExtent <= 0) return 0;
    // The last chunk that begins before the offset: the row before the one
    // at the offset, when the offset is on a row's top.
    final rows = scrollOffset / rowExtent;
    final nearest = rows.round();
    final onTop =
        (rows * rowExtent - nearest * rowExtent).abs() <
        precisionErrorTolerance;
    return weeks.itemAtWeek(onTop ? nearest - 1 : rows.floor());
  }

  @override
  double estimateMaxScrollOffset(
    SliverConstraints constraints, {
    int? firstIndex,
    int? lastIndex,
    double? leadingScrollOffset,
    double? trailingScrollOffset,
  }) => switch (weeks.totalWeeks) {
    final total? => total * rowExtent,
    null => double.infinity,
  };

  @override
  double computeMaxScrollOffset(
    SliverConstraints constraints,
    double itemExtent,
  ) => (weeks.totalWeeks ?? 0) * rowExtent;
}
