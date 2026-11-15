import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/project.dart';

/// Turns a project into code to paste into an app.
abstract final class CodeExport {
  /// The project's current animation as JSON, for
  /// `DotSequence.gridFromJson` or `DotSequence.cloudFromJson`.
  static String json(Project project) {
    final json = {
      ...switch (project.mode) {
        DotMode.grid => project.grid.toJson(),
        DotMode.cloud => project.cloud.toJson(),
      },
      'style': switch (project.mode) {
        DotMode.grid => project.gridStyle.toJson(),
        DotMode.cloud => project.cloudStyle.toJson(),
      },
    };
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  /// The project's current animation as Dart code.
  static String dart(Project project) {
    final name = _identifier(project.name);
    final buffer = StringBuffer()
      ..writeln("import 'package:flutter/widgets.dart';")
      ..writeln("import 'package:merging_dots/merging_dots.dart';")
      ..writeln();

    switch (project.mode) {
      case DotMode.grid:
        final sequence = project.grid;
        final single = sequence.frames.length == 1;
        buffer.writeln(
          '/// ${project.name}, made with the merging_dots editor.',
        );
        if (single) {
          buffer
            ..write('final $name = ')
            ..write(_grid(sequence.frames.single.state, 0))
            ..writeln(';');
        } else {
          buffer
            ..writeln('final $name = DotSequence<DotGrid>(')
            ..writeln('  [');
          for (final frame in sequence.frames) {
            _keyframe(buffer, _grid(frame.state, 3), frame);
          }
          buffer.writeln('  ],');
          _settings(buffer, sequence);
          buffer.writeln(');');
        }
        buffer
          ..writeln()
          ..writeln('const ${name}Style = ${_gridStyle(project.gridStyle)};')
          ..writeln()
          ..writeln('// Use it:')
          ..writeln(
            single
                ? '// DotGridView(grid: $name, style: ${name}Style)'
                : '// DotGridView.sequence(sequence: $name, style: ${name}Style)',
          );
      case DotMode.cloud:
        final sequence = project.cloud;
        final single = sequence.frames.length == 1;
        buffer.writeln(
          '/// ${project.name}, made with the merging_dots editor.',
        );
        if (single) {
          buffer
            ..write('const $name = ')
            ..write(_cloud(sequence.frames.single.state, 0))
            ..writeln(';');
        } else {
          buffer
            ..writeln('const $name = DotSequence<DotCloud>(')
            ..writeln('  [');
          for (final frame in sequence.frames) {
            _keyframe(buffer, _cloud(frame.state, 3), frame);
          }
          buffer.writeln('  ],');
          _settings(buffer, sequence);
          buffer.writeln(');');
        }
        buffer
          ..writeln()
          ..writeln('const ${name}Style = ${_cloudStyle(project.cloudStyle)};')
          ..writeln()
          ..writeln('// Use it:')
          ..writeln(
            single
                ? '// DotCloudView(cloud: $name, style: ${name}Style)'
                : '// DotCloudView.sequence(sequence: $name, style: ${name}Style)',
          );
    }
    return buffer.toString();
  }

  static void _keyframe(
    StringBuffer buffer,
    String state,
    DotKeyframe<DotState> frame,
  ) {
    final hold = frame.hold;
    if (hold == Duration.zero) {
      buffer.writeln('    DotKeyframe($state),');
      return;
    }
    buffer
      ..writeln('    DotKeyframe(')
      ..writeln('      $state,')
      ..writeln('      hold: ${_duration(hold)},')
      ..writeln('    ),');
  }

  static void _settings(StringBuffer buffer, DotSequence<DotState> sequence) {
    buffer.writeln('  motion: ${motion(sequence.motion)},');
    if (sequence.stagger is! NoDotStagger) {
      buffer.writeln('  stagger: ${stagger(sequence.stagger)},');
    }
    buffer.writeln('  loop: LoopMode.${sequence.loop.name},');
  }

  static String _grid(DotGrid grid, int indent) {
    final pad = '  ' * indent;
    if (grid.isPatternExact) {
      final lines = grid.toPattern().split('\n').map((l) => '$pad  $l');
      return "DotGrid.parse('''\n${lines.join('\n')}\n$pad''')";
    }
    final rows = [
      for (var row = 0; row < grid.rows; row++)
        '$pad    ${[for (var column = 0; column < grid.columns; column++) _number(grid.valueAt(column, row))].join(', ')},',
    ];
    return 'DotGrid(\n$pad  ${grid.columns},\n$pad  ${grid.rows},\n'
        '$pad  values: [\n${rows.join('\n')}\n$pad  ],\n$pad)';
  }

  static String _cloud(DotCloud cloud, int indent) {
    final pad = '  ' * indent;
    final buffer = StringBuffer('DotCloud(\n$pad  [\n');
    for (final dot in cloud.dots) {
      buffer.writeln(
        '$pad    Dot(${_number(dot.x)}, ${_number(dot.y)}, '
        '${_number(dot.radius)}),',
      );
    }
    final size = cloud.size;
    buffer.write(
      '$pad  ],\n'
      '$pad  size: Size(${_number(size.width)}, ${_number(size.height)}),\n'
      '$pad)',
    );
    return buffer.toString();
  }

  /// [value] as Dart code.
  static String motion(Motion value) => switch (value) {
    CupertinoMotion(:final duration, :final bounce) =>
      'Motion.cupertino(duration: ${_duration(duration)}, bounce: ${_number(bounce)})',
    LinearMotion(:final duration) => 'Motion.linear(${_duration(duration)})',
    CurvedMotion(:final duration, :final curve) =>
      'Motion.curved(${_duration(duration)}, Curves.${MotionJson.curveName(curve) ?? 'linear'})',
    _ => 'Motion.smoothSpring()',
  };

  /// [value] as Dart code.
  static String stagger(DotStagger value) {
    final duration = _duration(value.duration);
    return switch (value) {
      NoDotStagger() => 'DotStagger.none()',
      DirectionalDotStagger(:final angle) =>
        'DotStagger.directional(duration: $duration, angle: ${_number(angle)})',
      RadialDotStagger(:final center, :final inward) =>
        'DotStagger.radial(duration: $duration'
            '${center == Alignment.center ? '' : ', center: Alignment(${_number(center.x)}, ${_number(center.y)})'}'
            '${inward ? ', inward: true' : ''})',
      OrderedDotStagger(:final reverse) =>
        'DotStagger.ordered(duration: $duration${reverse ? ', reverse: true' : ''})',
      RandomDotStagger(:final seed) =>
        'DotStagger.random(duration: $duration, seed: $seed)',
    };
  }

  static String _gridStyle(DotGridStyle style) =>
      'DotGridStyle('
      '${style.color == null ? '' : 'color: ${_color(style.color!)}, '}'
      'dotSize: ${_number(style.dotSize)}, '
      'blend: ${_number(style.blend)})';

  static String _cloudStyle(DotCloudStyle style) =>
      'DotCloudStyle('
      '${style.color == null ? '' : 'color: ${_color(style.color!)}, '}'
      'blend: ${_number(style.blend)})';

  static String _color(Color color) =>
      'Color(0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()})';

  static String _duration(Duration duration) =>
      'Duration(milliseconds: ${duration.inMilliseconds})';

  static String _number(double value) {
    final rounded = (value * 1000).round() / 1000;
    if (rounded == rounded.roundToDouble()) return '${rounded.round()}';
    return '$rounded';
  }

  static String _identifier(String name) {
    final words = name
        .split(RegExp('[^A-Za-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'dots';
    final camel = [
      words.first.toLowerCase(),
      for (final word in words.skip(1))
        word[0].toUpperCase() + word.substring(1).toLowerCase(),
    ].join();
    return RegExp('^[0-9]').hasMatch(camel) ? 'dots$camel' : camel;
  }
}
