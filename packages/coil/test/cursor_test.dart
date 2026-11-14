// The mouse cursor over controls: the theme's controlCursor, the arrow by
// default. Links keep the pointing hand.
import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {CoilThemeData theme = CoilThemeData.light}) =>
    WidgetsApp(
      color: const Color(0xFF000000),
      builder: (context, navigator) => CoilTheme(
        data: theme.copyWith(tier: CoilTier.pointer),
        child: navigator!,
      ),
      onGenerateRoute: (settings) => PageRouteBuilder<void>(
        pageBuilder: (context, _, _) => Center(child: child),
      ),
    );

/// The cursor a mouse shows over [target].
Future<MouseCursor?> _cursorOver(WidgetTester tester, Finder target) async {
  final mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    pointer: 1,
  );
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: tester.getCenter(target));
  await tester.pump();
  return RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1);
}

void main() {
  testWidgets('a button shows the arrow by default', (tester) async {
    await tester.pumpWidget(
      _app(CoilButton(onPressed: () {}, child: const Text('Save'))),
    );
    expect(
      await _cursorOver(tester, find.text('Save')),
      SystemMouseCursors.basic,
    );
  });

  testWidgets('the theme gives controls the pointing hand', (tester) async {
    await tester.pumpWidget(
      _app(
        CoilButton(onPressed: () {}, child: const Text('Save')),
        theme: CoilThemeData.light.copyWith(
          controlCursor: SystemMouseCursors.click,
        ),
      ),
    );
    expect(
      await _cursorOver(tester, find.text('Save')),
      SystemMouseCursors.click,
    );
  });

  testWidgets('a disabled control keeps the cursor beneath it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const CoilButton(onPressed: null, child: Text('Save')),
        theme: CoilThemeData.light.copyWith(
          controlCursor: SystemMouseCursors.click,
        ),
      ),
    );
    expect(
      await _cursorOver(tester, find.text('Save')),
      SystemMouseCursors.basic,
    );
  });

  testWidgets('a breadcrumb link keeps the pointing hand', (tester) async {
    await tester.pumpWidget(
      _app(
        CoilBreadcrumb(
          crumbs: [
            CoilCrumb(label: 'Home', onPressed: () {}),
            const CoilCrumb(label: 'Docs'),
          ],
        ),
      ),
    );
    expect(
      await _cursorOver(tester, find.text('Home')),
      SystemMouseCursors.click,
    );
  });
}
