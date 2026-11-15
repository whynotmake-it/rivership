import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:merging_dots/src/model/dot_state.dart';

/// A grid of dots, each with a size and an optional offset from its cell.
///
/// A dot's *value* scales its radius: `0` hides it, `1` is the full size the
/// style allows. Values above `1` (up to `1.275`) are rendered too, so
/// bouncy springs can overshoot.
///
/// The quickest way to draw one is [DotGrid.parse]:
///
/// ```dart
/// final heart = DotGrid.parse('''
///   .##.##.
///   #######
///   #######
///   .#####.
///   ..###..
///   ...#...
/// ''');
/// ```
///
/// A grid is immutable. Methods like [withValue] return a modified copy.
@immutable
class DotGrid implements DotState {
  /// Creates a grid of [columns] by [rows] dots.
  ///
  /// [values] holds one value per dot, row by row, and defaults to all
  /// zeros. [offsets] holds two values per dot, an x and a y offset from
  /// `-1` to `1`, measured in the style's `offsetRange`; it defaults to no
  /// offsets. Both lists are copied.
  DotGrid(
    this.columns,
    this.rows, {
    List<double>? values,
    List<double>? offsets,
  }) : assert(columns > 0 && rows > 0, 'A grid needs at least one dot.'),
       assert(
         values == null || values.length == columns * rows,
         'values needs one entry per dot.',
       ),
       assert(
         offsets == null || offsets.length == columns * rows * 2,
         'offsets needs two entries per dot.',
       ),
       _values = values == null
           ? Float32List(columns * rows)
           : Float32List.fromList(values),
       _offsets = offsets == null || offsets.every((o) => o == 0)
           ? null
           : Float32List.fromList(offsets);

  const DotGrid._raw(this.columns, this.rows, this._values, this._offsets);

  /// Creates a grid where every dot has [value].
  factory DotGrid.filled(int columns, int rows, [double value = 1]) {
    final values = Float32List(columns * rows)
      ..fillRange(0, columns * rows, value);
    return DotGrid._raw(columns, rows, values, null);
  }

  /// Creates a grid whose dot values come from [value].
  factory DotGrid.generate(
    int columns,
    int rows,
    double Function(int column, int row) value,
  ) {
    final values = Float32List(columns * rows);
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        values[row * columns + column] = value(column, row);
      }
    }
    return DotGrid._raw(columns, rows, values, null);
  }

  /// Parses a grid from a text pattern, one line per row.
  ///
  /// Whitespace around lines is ignored and empty lines are skipped, so the
  /// pattern can be indented in a multi-line string. Every other character
  /// is one dot:
  ///
  /// * `.`, `0`, `-` and `_` are empty.
  /// * `1` to `9` are sizes from `1/9` to full.
  /// * Any other character, like `#`, is full size.
  ///
  /// Shorter rows are padded with empty dots.
  factory DotGrid.parse(String pattern) {
    final lines = [
      for (final line in pattern.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    assert(lines.isNotEmpty, 'The pattern has no rows.');
    final columns = lines.fold(
      0,
      (longest, line) => math.max(longest, line.length),
    );
    final rows = lines.length;
    final values = Float32List(columns * rows);
    for (var row = 0; row < rows; row++) {
      final line = lines[row];
      for (var column = 0; column < line.length; column++) {
        values[row * columns + column] = _parseCell(line.codeUnitAt(column));
      }
    }
    return DotGrid._raw(columns, rows, values, null);
  }

  /// Reads a grid written by [toJson].
  factory DotGrid.fromJson(Map<String, Object?> json) {
    final columns = json['columns']! as int;
    final rows = json['rows']! as int;
    final pattern = json['pattern'] as String?;
    final values = pattern != null
        ? DotGrid.parse(pattern)._values
        : Float32List.fromList([
            for (final v in json['values']! as List) (v as num).toDouble(),
          ]);
    final offsets = json['offsets'] as List?;
    return DotGrid(
      columns,
      rows,
      values: values,
      offsets: offsets == null
          ? null
          : [for (final o in offsets) (o as num).toDouble()],
    );
  }

  /// The number of dots per row.
  final int columns;

  /// The number of rows.
  final int rows;

  final Float32List _values;
  final Float32List? _offsets;

  /// The value of every dot, row by row. Don't modify it.
  Float32List get values => _values;

  /// Whether any dot is moved from its cell.
  bool get hasOffsets => _offsets != null;

  @override
  int get dotCount => columns * rows;

  /// The value of the dot at [column] and [row].
  double valueAt(int column, int row) => _values[_index(column, row)];

  /// The offset of the dot at [column] and [row], from `-1` to `1` per axis.
  Offset offsetAt(int column, int row) {
    final offsets = _offsets;
    if (offsets == null) return Offset.zero;
    final i = _index(column, row) * 2;
    return Offset(offsets[i], offsets[i + 1]);
  }

  /// A copy with the dot at [column] and [row] set to [value].
  DotGrid withValue(int column, int row, double value) {
    final values = Float32List.fromList(_values);
    values[_index(column, row)] = value;
    return DotGrid._raw(columns, rows, values, _offsets);
  }

  /// A copy with the dot at [column] and [row] moved by [offset].
  DotGrid withOffset(int column, int row, Offset offset) {
    final offsets = Float32List.fromList(_offsets ?? Float32List(dotCount * 2));
    final i = _index(column, row) * 2;
    offsets[i] = offset.dx.clamp(-1, 1);
    offsets[i + 1] = offset.dy.clamp(-1, 1);
    return DotGrid._raw(
      columns,
      rows,
      _values,
      offsets.every((o) => o == 0) ? null : offsets,
    );
  }

  /// A copy whose dot values are mapped by [transform].
  DotGrid map(double Function(int column, int row, double value) transform) {
    return DotGrid.generate(
      columns,
      rows,
      (column, row) => transform(column, row, valueAt(column, row)),
    )._withOffsets(_offsets);
  }

  /// A copy of [columns] by [rows], keeping the dots that still fit at their
  /// position.
  ///
  /// When [center] is true, the content stays centered instead of anchored
  /// to the top left.
  DotGrid resized(int columns, int rows, {bool center = true}) {
    final dx = center ? (columns - this.columns) ~/ 2 : 0;
    final dy = center ? (rows - this.rows) ~/ 2 : 0;
    final offsets = _offsets == null ? null : Float32List(columns * rows * 2);
    final values = Float32List(columns * rows);
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final sourceColumn = column - dx;
        final sourceRow = row - dy;
        if (sourceColumn < 0 ||
            sourceRow < 0 ||
            sourceColumn >= this.columns ||
            sourceRow >= this.rows) {
          continue;
        }
        final to = row * columns + column;
        final from = _index(sourceColumn, sourceRow);
        values[to] = _values[from];
        if (offsets != null) {
          offsets[to * 2] = _offsets![from * 2];
          offsets[to * 2 + 1] = _offsets[from * 2 + 1];
        }
      }
    }
    return DotGrid._raw(columns, rows, values, offsets);
  }

  /// This grid as a pattern that [DotGrid.parse] reads back.
  ///
  /// Values are rounded to ninths and offsets are dropped, so use [toJson]
  /// for a lossless copy.
  String toPattern() {
    final buffer = StringBuffer();
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final level = (valueAt(column, row) * 9).round().clamp(0, 9);
        buffer.write(switch (level) {
          0 => '.',
          9 => '#',
          _ => '$level',
        });
      }
      if (row < rows - 1) buffer.writeln();
    }
    return buffer.toString();
  }

  /// Whether every value is a multiple of a ninth and nothing is offset, so
  /// [toPattern] is lossless.
  bool get isPatternExact =>
      _offsets == null &&
      _values.every(
        (v) => v >= 0 && v <= 1 && ((v * 9) - (v * 9).round()).abs() < 1e-3,
      );

  /// A JSON representation, read by [DotGrid.fromJson].
  ///
  /// Uses the compact pattern format when it is lossless.
  Map<String, Object?> toJson() => {
    'columns': columns,
    'rows': rows,
    if (isPatternExact)
      'pattern': toPattern()
    else
      'values': [for (final v in _values) _round(v)],
    if (_offsets != null) 'offsets': [for (final o in _offsets) _round(o)],
  };

  @override
  void writeChannels(Float32List out) {
    final offsets = _offsets;
    for (var i = 0; i < dotCount; i++) {
      final o = i * DotState.stride;
      out[o] = _values[i];
      out[o + 1] = offsets == null ? 0 : offsets[i * 2];
      out[o + 2] = offsets == null ? 0 : offsets[i * 2 + 1];
    }
  }

  @override
  Offset normalizedPosition(int index) {
    final column = index % columns;
    final row = index ~/ columns;
    return Offset(
      columns == 1 ? 0.5 : column / (columns - 1),
      rows == 1 ? 0.5 : row / (rows - 1),
    );
  }

  @override
  bool canAnimateTo(DotState other) =>
      other is DotGrid && other.columns == columns && other.rows == rows;

  int _index(int column, int row) {
    assert(
      column >= 0 && column < columns && row >= 0 && row < rows,
      '($column, $row) is outside the $columns x $rows grid.',
    );
    return row * columns + column;
  }

  DotGrid _withOffsets(Float32List? offsets) =>
      DotGrid._raw(columns, rows, _values, offsets);

  static double _parseCell(int codeUnit) {
    const zero = 0x30;
    const nine = 0x39;
    return switch (codeUnit) {
      0x2E || 0x2D || 0x5F || 0x20 || zero => 0, // . - _ space 0
      >= zero + 1 && <= nine => (codeUnit - zero) / 9,
      _ => 1,
    };
  }

  static num _round(double v) {
    final rounded = (v * 1000).round() / 1000;
    return rounded == rounded.roundToDouble() ? rounded.round() : rounded;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DotGrid &&
          other.columns == columns &&
          other.rows == rows &&
          listEquals(other._values, _values) &&
          listEquals(other._offsets, _offsets);

  @override
  int get hashCode => Object.hash(
    columns,
    rows,
    Object.hashAll(_values),
    _offsets == null ? null : Object.hashAll(_offsets),
  );

  @override
  String toString() => 'DotGrid($columns x $rows)';
}
