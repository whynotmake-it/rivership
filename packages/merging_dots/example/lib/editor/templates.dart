import 'package:flutter/painting.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/project.dart';

/// Projects to start from.
final List<Project> templates = [
  _project(
    'Heart beat',
    grid: DotSequence(
      [
        DotKeyframe(_heart, hold: const Duration(milliseconds: 260)),
        DotKeyframe(
          _heart.map((_, _, v) => v * 5 / 9),
          hold: const Duration(milliseconds: 80),
        ),
      ],
      motion: const CupertinoMotion(
        duration: Duration(milliseconds: 420),
        bounce: 0.45,
      ),
      stagger: const DotStagger.radial(duration: Duration(milliseconds: 90)),
    ),
    gridStyle: const DotGridStyle(color: Color(0xFFFF5C39), blend: 0.7),
  ),
  _project(
    'Play / pause',
    grid: DotSequence(
      [
        DotKeyframe(
          DotGrid.parse('''
            .#.....
            .###...
            .#####.
            .######
            .#####.
            .###...
            .#.....
          '''),
          hold: const Duration(milliseconds: 900),
        ),
        DotKeyframe(
          DotGrid.parse('''
            .##.##.
            .##.##.
            .##.##.
            .##.##.
            .##.##.
            .##.##.
            .##.##.
          '''),
          hold: const Duration(milliseconds: 900),
        ),
      ],
      motion: const CupertinoMotion.bouncy(),
      stagger: const DotStagger.directional(
        duration: Duration(milliseconds: 160),
      ),
    ),
  ),
  _project(
    'Check',
    grid: DotSequence(
      [
        DotKeyframe(DotGrid(7, 7), hold: const Duration(milliseconds: 300)),
        DotKeyframe(
          DotGrid.parse('''
            .......
            ......#
            .....#.
            #...#..
            .#.#...
            ..#....
            .......
          '''),
          hold: const Duration(milliseconds: 1200),
        ),
      ],
      motion: const CupertinoMotion(
        duration: Duration(milliseconds: 380),
        bounce: 0.35,
      ),
      stagger: const DotStagger.directional(
        duration: Duration(milliseconds: 260),
        angle: -0.5,
      ),
    ),
    gridStyle: const DotGridStyle(color: Color(0xFFB4FF39), blend: 0.9),
  ),
  _project('Wave', grid: DotPresets.wave(columns: 7)),
  _project('Pulse', grid: DotPresets.pulse()),
  _project(
    'Snake',
    grid: DotPresets.snake(),
    gridStyle: const DotGridStyle(color: Color(0xFF3DD9FF), blend: 0.8),
  ),
  _project(
    'Gooey bounce',
    cloud: DotPresets.gooeyBounce(),
    cloudStyle: const DotCloudStyle(color: Color(0xFFFFC53D), blend: 18),
  ),
  _project(
    'Orbit',
    cloud: DotPresets.orbit(),
    cloudStyle: const DotCloudStyle(color: Color(0xFF8A7CFF), blend: 20),
  ),
  _project(
    'Binary',
    cloud: DotPresets.binary(),
    cloudStyle: const DotCloudStyle(color: Color(0xFFFF6FD8), blend: 22),
  ),
];

final _heart = DotGrid.parse('''
  .........
  .##...##.
  ####.####
  #########
  #########
  .#######.
  ..#####..
  ...###...
  ....#....
''');

Project _project(
  String name, {
  DotSequence<DotGrid>? grid,
  DotSequence<DotCloud>? cloud,
  DotGridStyle gridStyle = const DotGridStyle(color: Color(0xFFF4F4F5)),
  DotCloudStyle cloudStyle = const DotCloudStyle(color: Color(0xFFF4F4F5)),
}) {
  final blank = Project.blank(name: name);
  return Project(
    name: name,
    mode: grid != null ? DotMode.grid : DotMode.cloud,
    grid: grid ?? blank.grid,
    cloud: cloud ?? blank.cloud,
    gridStyle: gridStyle,
    cloudStyle: cloudStyle,
  );
}
