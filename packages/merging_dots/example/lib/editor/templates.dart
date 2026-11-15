import 'package:flutter/painting.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/project.dart';

/// Projects to start from.
final List<Project> templates = [
  _project(
    'Dots',
    grid: DotSequence(
      [
        for (final letter in _letters)
          DotKeyframe(letter, hold: const Duration(milliseconds: 700)),
      ],
      motion: const CupertinoMotion(
        duration: Duration(milliseconds: 380),
        bounce: 0.2,
      ),
      stagger: const DotStagger.directional(
        duration: Duration(milliseconds: 260),
        angle: 0.6,
      ),
    ),
    gridStyle: const DotGridStyle.tiles(),
  ),
  _project(
    'Icon morph',
    grid: DotSequence(
      [
        for (final icon in [_heart, _bolt, _smiley, _plus, _spark])
          DotKeyframe(icon, hold: const Duration(milliseconds: 900)),
      ],
      motion: const CupertinoMotion(
        duration: Duration(milliseconds: 420),
        bounce: 0.25,
      ),
      stagger: const DotStagger.radial(duration: Duration(milliseconds: 360)),
    ),
    gridStyle: const DotGridStyle.tiles(),
  ),
  _project('Heart', grid: DotSequence.single(_heart), gridStyle: _tiles),
  _project('Bolt', grid: DotSequence.single(_bolt), gridStyle: _tiles),
  _project('Arrow', grid: DotSequence.single(_arrow), gridStyle: _tiles),
  _project('Smiley', grid: DotSequence.single(_smiley), gridStyle: _tiles),
  _project(
    'Heart beat',
    grid: DotSequence(
      [
        DotKeyframe(_heartBeat, hold: const Duration(milliseconds: 260)),
        DotKeyframe(
          _heartBeat.map((_, _, v) => v * 5 / 9),
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

const _tiles = DotGridStyle.tiles();

final _heartBeat = DotGrid.parse('''
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

final _heart = DotGrid.parse('''
  .##.##.
  #######
  #######
  #######
  .#####.
  ..###..
  ...#...
''');

final _bolt = DotGrid.parse('''
  ...###.
  ..###..
  .###...
  #######
  ...###.
  ..###..
  .###...
''');

final _arrow = DotGrid.parse('''
  ...#...
  ....#..
  .....#.
  #######
  .....#.
  ....#..
  ...#...
''');

final _smiley = DotGrid.parse('''
  .#####.
  #######
  ##.#.##
  #######
  #.###.#
  ##...##
  .#####.
''');

final _plus = DotGrid.parse('''
  ..###..
  ..###..
  #######
  #######
  #######
  ..###..
  ..###..
''');

final _spark = DotGrid.parse('''
  ...#...
  ...#...
  ..###..
  #######
  ..###..
  ...#...
  ...#...
''');

final _letters = [
  for (final letter in [
    '''
      ####.
      #...#
      #...#
      #...#
      ####.
    ''',
    '''
      .###.
      #...#
      #...#
      #...#
      .###.
    ''',
    '''
      #####
      ..#..
      ..#..
      ..#..
      ..#..
    ''',
    '''
      .####
      #....
      .###.
      ....#
      ####.
    ''',
  ])
    DotGrid.parse(letter),
];

Project _project(
  String name, {
  DotSequence<DotGrid>? grid,
  DotSequence<DotCloud>? cloud,
  DotGridStyle gridStyle = const DotGridStyle(),
  DotCloudStyle cloudStyle = const DotCloudStyle(),
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
