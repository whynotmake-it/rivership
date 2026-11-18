import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  required CoilPopoverController controller,
  required FocusNode opener,
  required FocusNode inside,
  ValueListenable<bool>? showOpener,
  bool takeFocus = true,
}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => CoilTheme(
    data: CoilThemeData.light,
    child: Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => ValueListenableBuilder(
            valueListenable: showOpener ?? ValueNotifier(true),
            builder: (context, showOpener, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showOpener)
                  Focus(
                    focusNode: opener,
                    child: const SizedBox(width: 40, height: 20),
                  ),
                CoilPopover(
                  controller: controller,
                  takeFocus: takeFocus,
                  onClose: (_) => controller.hide(),
                  popover: (context) => Focus(
                    focusNode: inside,
                    child: const SizedBox(width: 80, height: 40),
                  ),
                  child: const SizedBox(width: 40, height: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);

void main() {
  late FocusNode opener;
  late FocusNode inside;
  setUp(() {
    opener = FocusNode(debugLabel: 'opener');
    inside = FocusNode(debugLabel: 'inside');
  });
  tearDown(() {
    opener.dispose();
    inside.dispose();
  });

  testWidgets('closing hands focus back to the opener', (tester) async {
    final controller = CoilPopoverController();
    await tester.pumpWidget(
      _app(controller: controller, opener: opener, inside: inside),
    );
    opener.requestFocus();
    await tester.pump();
    controller.show();
    await tester.pumpAndSettle();
    inside.requestFocus();
    await tester.pump();
    controller.hide();
    await tester.pump();
    expect(opener.hasPrimaryFocus, isTrue);
  });

  testWidgets('an opener that left the tree does not take focus back later', (
    tester,
  ) async {
    final controller = CoilPopoverController();
    final showOpener = ValueNotifier(true);
    addTearDown(showOpener.dispose);
    await tester.pumpWidget(
      _app(
        controller: controller,
        opener: opener,
        inside: inside,
        showOpener: showOpener,
      ),
    );
    opener.requestFocus();
    await tester.pump();
    controller.show();
    await tester.pumpAndSettle();
    inside.requestFocus();
    await tester.pump();
    showOpener.value = false;
    await tester.pump();
    controller.hide();
    await tester.pump();
    expect(opener.hasFocus, isFalse, reason: 'it is not in the tree');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Back in the tree, the old opener must not grab focus on its own.
    showOpener.value = true;
    await tester.pump();
    expect(opener.hasFocus, isFalse);
  });

  testWidgets('Tab never lands in a popover springing out', (tester) async {
    final controller = CoilPopoverController();
    await tester.pumpWidget(
      _app(
        controller: controller,
        opener: opener,
        inside: inside,
        takeFocus: false,
      ),
    );
    opener.requestFocus();
    controller.show();
    await tester.pumpAndSettle();
    controller.hide();
    await tester.pump();
    // Still on screen, fading out.
    expect(inside.context, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(inside.hasFocus, isFalse);
  });
}
