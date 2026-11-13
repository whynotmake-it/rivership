import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final _anchor = find.byKey(const ValueKey('anchor'));
final _content = find.byKey(const ValueKey('content'));
final _controller = CoilPopupController();

/// An app with an anchor at [anchorTop]; opening it shows a popover of
/// [contentHeight].
Widget _app({
  required double anchorTop,
  double contentHeight = 200,
  bool reduceMotion = false,
}) => MediaQuery(
  data: MediaQueryData(
    size: const Size(400, 600),
    disableAnimations: reduceMotion,
  ),
  child: WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, navigator) =>
        CoilTheme(data: CoilThemeData.light, child: navigator!),
    onGenerateRoute: (_) => PageRouteBuilder<void>(
      pageBuilder: (context, _, _) => Stack(
        children: [
          Positioned(
            left: 40,
            top: anchorTop,
            child: CoilAdaptivePopup(
              controller: _controller,
              presentation: CoilPresentation.popover,
              traits: const CoilOverlayTraits(
                kind: CoilOverlayKind.actionMenu,
                itemCount: 1,
              ),
              content: (context, popup) => SizedBox(
                key: const ValueKey('content'),
                width: 160,
                height: contentHeight,
              ),
              popover: (context, content) => content,
              sheet: (context, content) => content,
              child: GestureDetector(
                key: const ValueKey('anchor'),
                behavior: HitTestBehavior.opaque,
                onTap: _controller.open,
                child: const SizedBox(width: 120, height: 36),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(_anchor);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens below the anchor when the content fits there', (
    tester,
  ) async {
    await tester.pumpWidget(_app(anchorTop: 40));
    await _open(tester);
    expect(
      tester.getRect(_content).top,
      tester.getRect(_anchor).bottom + 6,
    );
  });

  testWidgets('opens above when the laid-out content needs more room', (
    tester,
  ) async {
    // 200 below the anchor's bottom is not enough for 300 of content; above
    // there is more room.
    await tester.pumpWidget(_app(anchorTop: 380, contentHeight: 300));
    await _open(tester);
    expect(
      tester.getRect(_content).bottom,
      tester.getRect(_anchor).top - 6,
    );
  });

  testWidgets('follows the anchor in the same frame when it moves', (
    tester,
  ) async {
    await tester.pumpWidget(_app(anchorTop: 40));
    await _open(tester);
    await tester.pumpWidget(_app(anchorTop: 100));
    expect(
      tester.getRect(_content).top,
      tester.getRect(_anchor).bottom + 6,
    );
  });

  testWidgets('under reduced motion it fades without growing', (
    tester,
  ) async {
    await tester.pumpWidget(_app(anchorTop: 40, reduceMotion: true));
    await tester.tap(_anchor);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.getSize(_content), const Size(160, 200));
    expect(
      tester.getRect(_content).top,
      tester.getRect(_anchor).bottom + 6,
      reason: 'no slide while it fades in',
    );
    await tester.pumpAndSettle();
  });
}
