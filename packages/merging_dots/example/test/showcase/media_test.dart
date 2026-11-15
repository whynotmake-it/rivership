@Tags(['showcase'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/project.dart';
import 'package:merging_dots_example/editor/templates.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snaptest/snaptest.dart';

/// Where the README's media go: `packages/merging_dots/doc`, relative to
/// this file.
const _doc = '../../../doc';

const _paper = Color(0xFFF3F1EC);
const _ink = Color(0xFF1D1C1A);

const _image = SnaptestSettings(
  blockText: false,
  renderShadows: true,
  pathPrefix: _doc,
);

const _video = SnapVideoSettings(
  timing: VideoTiming.smooth,
  frameRate: 30,
  encoding: VideoEncoding.h264(crf: 18),
  pathPrefix: _doc,
  finalHold: Duration(milliseconds: 200),
);

void _setSize(WidgetTester tester, Size size, {double pixelRatio = 2}) {
  tester.view
    ..physicalSize = size * pixelRatio
    ..devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
}

Project _template(String name) => templates.firstWhere((t) => t.name == name);

/// A stage of paper with ink for dots.
Widget _stage(Widget child, {Color background = _paper}) => Directionality(
  textDirection: TextDirection.ltr,
  child: ColoredBox(
    color: background,
    child: IconTheme(
      data: const IconThemeData(color: _ink),
      child: child,
    ),
  ),
);

void main() {
  setUpAll(DotShaders.precache);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('morph', (tester) async {
    _setSize(tester, const Size(480, 480));
    final morph = _template('Icon morph').grid;
    final recording = await snap.recordVideo(name: 'morph', settings: _video);
    await tester.pumpWidget(
      _stage(
        Padding(
          padding: const EdgeInsets.all(72),
          child: DotGridView.sequence(
            sequence: morph,
            style: const DotGridStyle.tiles(),
          ),
        ),
      ),
    );
    // Five frames of 420 ms moves and 900 ms holds, once around.
    await tester.pump(const Duration(milliseconds: 7000));
    await recording.stop();
  });

  testWidgets('loaders', (tester) async {
    _setSize(tester, const Size(960, 200));
    final recording = await snap.recordVideo(name: 'loaders', settings: _video);
    Widget cell(Widget child) => Expanded(
      child: Center(child: SizedBox.square(dimension: 120, child: child)),
    );
    await tester.pumpWidget(
      _stage(
        Row(
          children: [
            cell(
              DotGridView.sequence(
                sequence: DotPresets.wave(),
                style: const DotGridStyle(blend: 1.1),
              ),
            ),
            cell(
              DotGridView.sequence(
                sequence: DotPresets.pulse(),
                style: const DotGridStyle(blend: 1.1),
              ),
            ),
            cell(
              DotGridView.sequence(
                sequence: DotPresets.snake(),
                style: const DotGridStyle.tiles(),
              ),
            ),
            cell(
              DotCloudView.sequence(
                sequence: DotPresets.gooeyBounce(),
                style: const DotCloudStyle(blend: 18),
              ),
            ),
            cell(
              DotCloudView.sequence(
                sequence: DotPresets.orbit(),
                style: const DotCloudStyle(blend: 20),
              ),
            ),
            cell(
              DotCloudView.sequence(
                sequence: DotPresets.binary(),
                style: const DotCloudStyle(blend: 22),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 4000));
    await recording.stop();
  });

  testWidgets('shapes', (tester) async {
    _setSize(tester, const Size(960, 360));
    final glyph = DotGrid.parse('''
      .#####.
      #######
      ##.#.##
      #######
      #.###.#
      ##...##
      .#####.
    ''');
    Widget labeled(String label, DotGridStyle style) => Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 200,
            child: DotGridView(grid: glyph, style: style),
          ),
          const SizedBox(height: 20),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              package: 'coil',
              fontSize: 15,
              color: _ink,
            ),
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      _stage(
        Row(
          children: [
            labeled('goo, blend 0', const DotGridStyle(blend: 0, dotSize: 0.9)),
            labeled(
              'goo, blend 0.8',
              const DotGridStyle(blend: 0.8, dotSize: 0.9),
            ),
            labeled('tiles', const DotGridStyle.tiles()),
            labeled(
              'tiles, square inner corners',
              const DotGridStyle.tiles(innerRadius: 0, cornerRadius: 0.6),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await snap(name: 'shapes', settings: _image);
  });
}
