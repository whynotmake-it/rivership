import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merging_dots_example/editor/editor_controller.dart';
import 'package:merging_dots_example/editor/editor_page.dart';
import 'package:merging_dots_example/editor/project.dart';
import 'package:merging_dots_example/editor/templates.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget child) => WidgetsApp(
  color: const Color(0xFF000000),
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, _, _) => builder(context),
  ),
  home: child,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final name in ['blank', 'Orbit', 'Gooey bounce', 'Binary']) {
    testWidgets('switching cloud frames: $name', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = EditorController();
      addTearDown(controller.dispose);
      if (name == 'blank') {
        controller
          ..setMode(DotMode.cloud)
          ..addDot(const Offset(20, 20))
          ..duplicateFrame()
          ..moveDot(0, const Offset(60, 60));
      } else {
        controller.open(templates.firstWhere((t) => t.name == name));
      }
      await tester.pumpWidget(app(MergingDotsEditor(controller: controller)));
      await tester.pump(const Duration(milliseconds: 500));
      for (final frame in [1, 0, 2, 0]) {
        if (frame >= controller.project.frameCount) continue;
        controller.selectFrame(frame);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
    });
  }
}
