import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/code_export.dart';
import 'package:merging_dots_example/editor/editor_controller.dart';
import 'package:merging_dots_example/editor/editor_page.dart';
import 'package:merging_dots_example/editor/project.dart';
import 'package:merging_dots_example/editor/templates.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the editor paints cells and plays frames', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = EditorController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MergingDotsEditor(controller: controller),
      ),
    );
    expect(find.byType(DotGridView), findsWidgets);

    final grid = tester.renderObject<RenderDotGrid>(
      find.byType(DotGridView).first,
    );
    final center = grid.localToGlobal(grid.size.center(Offset.zero));
    await tester.tapAt(center);
    await tester.pump();
    expect(controller.currentGrid.valueAt(4, 4), 1);
    expect(controller.canUndo, isTrue);

    controller.duplicateFrame();
    controller.paintCell(0, 0, 1);
    expect(controller.project.frameCount, 2);
    controller.setPlaying(playing: true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    controller.setPlaying(playing: false);
    await tester.pumpAndSettle();

    controller.undo();
    expect(controller.currentGrid.valueAt(0, 0), 0);

    controller.setMode(DotMode.cloud);
    await tester.pumpAndSettle();
    expect(find.byType(DotCloudView), findsWidgets);
    controller.addDot(const Offset(20, 20));
    expect(controller.currentCloud.dots, hasLength(2));
    await tester.pumpAndSettle();
  });

  test('every template survives a JSON export and import', () {
    for (final template in templates) {
      final controller = EditorController(project: template);
      final error = controller.importJson(CodeExport.json(template));
      expect(error, isNull, reason: template.name);
      // Positions are rounded on export, so compare the exports.
      expect(
        CodeExport.json(controller.project),
        CodeExport.json(template),
        reason: template.name,
      );
      controller.dispose();
    }
  });

  test('Dart export builds the sequence and the style', () {
    final code = CodeExport.dart(templates.first);
    expect(code, contains('final heartBeat = DotSequence<DotGrid>('));
    expect(code, contains("DotGrid.parse('''"));
    expect(code, contains('Motion.cupertino('));
    expect(code, contains('DotStagger.radial('));
    expect(code, contains('const heartBeatStyle = DotGridStyle('));
  });
}
