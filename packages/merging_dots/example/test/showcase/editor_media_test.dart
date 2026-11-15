@Tags(['showcase'])
library;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/canvas.dart';
import 'package:merging_dots_example/editor/editor_controller.dart';
import 'package:merging_dots_example/editor/editor_page.dart';
import 'package:merging_dots_example/editor/project.dart';
import 'package:merging_dots_example/editor/templates.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snaptest/snaptest.dart';

/// Where the README's media go: `packages/merging_dots/doc`, relative to
/// this file.
const _doc = '../../../doc';

const _ink = Color(0xFF1D1C1A);

const _image = SnaptestSettings(
  blockText: false,
  renderShadows: true,
  pathPrefix: _doc,
);

void _setSize(WidgetTester tester, Size size, {double pixelRatio = 2}) {
  tester.view
    ..physicalSize = size * pixelRatio
    ..devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
}

Project _template(String name) => templates.firstWhere((t) => t.name == name);

/// A bare app around [child].
Widget _app(Widget child) => WidgetsApp(
  color: _ink,
  debugShowCheckedModeBanner: false,
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, _, _) => builder(context),
  ),
  home: child,
);

void main() {
  setUpAll(DotShaders.precache);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final dark in [false, true]) {
    testWidgets('editor ${dark ? 'dark' : 'light'}', (tester) async {
      _setSize(tester, const Size(1440, 900), pixelRatio: 1.5);
      final controller = EditorController()
        ..open(_template('Icon morph'))
        ..setPlaying(playing: false)
        ..setOnionSkin(enabled: false)
        ..selectFrame(2);
      addTearDown(controller.dispose);
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(_app(MergingDotsEditor(controller: controller)));
      await tester.pump(const Duration(seconds: 1));
      await snap(name: dark ? 'editor_dark' : 'editor', settings: _image);
    });
  }

  testWidgets('editor demo', (tester) async {
    _setSize(tester, const Size(1440, 900), pixelRatio: 1.5);
    final controller = EditorController();
    addTearDown(controller.dispose);
    final recording = await snap.recordVideo(
      name: 'editor',
      settings: const SnapVideoSettings(
        timing: VideoTiming.smooth,
        frameRate: 30,
        encoding: VideoEncoding.h264(crf: 20),
        pathPrefix: _doc,
        showPointers: true,
        minimumPointerDuration: Duration(milliseconds: 120),
        finalHold: Duration(milliseconds: 300),
      ),
    );
    await tester.pumpWidget(_app(MergingDotsEditor(controller: controller)));
    await tester.pump(const Duration(milliseconds: 600));

    final grid = tester.renderObject<RenderDotGrid>(
      find
          .descendant(
            of: find.byType(EditorCanvas),
            matching: find.byType(DotGridView),
          )
          .last,
    );
    Offset cell(int column, int row) {
      final spacing = grid.size.shortestSide / 7;
      final topLeft = Offset(
        (grid.size.width - spacing * 7) / 2,
        (grid.size.height - spacing * 7) / 2,
      );
      return grid.localToGlobal(
        topLeft + Offset((column + 0.5) * spacing, (row + 0.5) * spacing),
      );
    }

    Future<void> stroke(List<(int, int)> cells) async {
      var at = cell(cells.first.$1, cells.first.$2);
      final gesture = await tester.startGesture(at);
      await tester.pump(const Duration(milliseconds: 60));
      for (final (column, row) in cells.skip(1)) {
        final target = cell(column, row);
        // Glide there in a few steps, so the pointer moves smoothly.
        for (var i = 1; i <= 4; i++) {
          await gesture.moveTo(Offset.lerp(at, target, i / 4)!);
          await tester.pump(const Duration(milliseconds: 16));
        }
        at = target;
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 250));
    }

    Finder button(String label) => find.byWidgetPredicate(
      (widget) => widget is CoilButton && widget.semanticLabel == label,
    );

    // A heart, stroke by stroke.
    await stroke([(1, 1), (2, 1)]);
    await stroke([(4, 1), (5, 1)]);
    await stroke([(0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2)]);
    await stroke([(6, 3), (5, 3), (4, 3), (3, 3), (2, 3), (1, 3), (0, 3)]);
    await stroke([(1, 4), (2, 4), (3, 4), (4, 4), (5, 4)]);
    await stroke([(2, 5), (3, 5), (4, 5), (3, 6)]);
    await tester.pump(const Duration(milliseconds: 600));

    // A second frame, smaller, then play them.
    await tester.tap(button('Duplicate this frame'));
    await tester.pump(const Duration(milliseconds: 400));
    controller.setGridTool(GridTool.erase);
    await tester.pump(const Duration(milliseconds: 300));
    await stroke([(0, 2), (0, 3)]);
    await stroke([(6, 2), (6, 3)]);
    await stroke([(1, 1), (2, 1)]);
    await stroke([(4, 1), (5, 1)]);
    await tester.pump(const Duration(milliseconds: 400));
    controller
      ..setMotion(
        const CupertinoMotion(
          duration: Duration(milliseconds: 380),
          bounce: 0.35,
        ),
      )
      ..setStagger(
        const DotStagger.radial(duration: Duration(milliseconds: 160)),
      );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(button('Play'));
    await tester.pump(const Duration(milliseconds: 3200));
    await recording.stop();
  });
}
