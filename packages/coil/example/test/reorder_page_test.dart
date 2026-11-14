import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:coil_example/src/app.dart';
import 'package:coil_example/src/pages/components/reorder_page.dart';
import 'package:coil_example/src/pages/home_page.dart';
import 'package:coil_example/src/shell/routes.dart';
import 'package:coil_example/src/shell/settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_widgets/motor_widgets.dart';

Future<void> _pumpPage(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1280, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = CatalogSettings()..tier = CatalogTier.pointer;
  addTearDown(settings.dispose);
  await tester.pumpWidget(CoilCatalogApp(settings: settings, devTools: false));
  await tester.pumpAndSettle();
  final router = AutoRouter.of(tester.element(find.byType(HomePage)));
  unawaited(router.push(NamedRoute(catalogRouteName(reorderEntry))));
  await tester.pumpAndSettle();
}

/// The [MotionReorder] around the card titled [title].
Finder _reorderOf(String title) => find
    .ancestor(of: find.text(title), matching: find.byType(MotionReorder))
    .first;

/// How far the card titled [title] is painted from its layout position.
Offset _flight(WidgetTester tester, String title) {
  final box = tester.renderObject<RenderBox>(_reorderOf(title));
  final translation = (box.debugLayer as TransformLayer?)?.transform
      ?.getTranslation();
  return translation == null
      ? Offset.zero
      : Offset(translation.x, translation.y);
}

void main() {
  testWidgets('Shuffle flies the cards of its column and they settle', (
    tester,
  ) async {
    await _pumpPage(tester);
    await tester.tap(find.text('Shuffle').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final backlog = [
      'Write the release notes',
      'Fix the login redirect',
      'Review the color tokens',
      'Profile the board',
      'Update the onboarding copy',
      'Triage new issues',
    ].where((title) => find.text(title).evaluate().isNotEmpty).toList();
    expect(backlog, isNotEmpty);
    expect(
      backlog.any((title) => _flight(tester, title) != Offset.zero),
      isTrue,
      reason: 'some card changed place',
    );
    expect(
      _flight(tester, 'Ship the dark theme'),
      Offset.zero,
      reason: 'other columns stay put',
    );
    await tester.pumpAndSettle();
    for (final title in backlog) {
      expect(_flight(tester, title), Offset.zero, reason: title);
    }
  });

  testWidgets('a card dragged to another column lands there', (tester) async {
    await _pumpPage(tester);
    const title = 'Write the release notes';
    final start = tester.getCenter(find.text(title));
    final doing = tester.getCenter(find.text('Doing'));

    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    final by = Offset(doing.dx - start.dx, 80);
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(by / 12);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    final landed = tester.getCenter(find.text(title));
    expect((landed.dx - doing.dx).abs(), lessThan(130));
    expect(_flight(tester, title), Offset.zero);
  });

  testWidgets('a move updates both column counts and leaves one card', (
    tester,
  ) async {
    await _pumpPage(tester);
    const title = 'Write the release notes';
    final start = tester.getCenter(find.text(title));
    final doing = tester.getCenter(find.text('Doing'));
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    final by = Offset(doing.dx - start.dx, 80);
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(by / 12);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text(title), findsNWidgets(2), reason: 'the lifted copy');
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text(title), findsOneWidget, reason: 'the copy has landed');
    Finder countBeside(String column) => find.descendant(
      of: find
          .ancestor(of: find.text(column), matching: find.byType(Row))
          .first,
      matching: find.byType(CoilBadge),
    );
    expect(
      find.descendant(of: countBeside('Backlog'), matching: find.text('5')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: countBeside('Doing'), matching: find.text('4')),
      findsOneWidget,
    );
  });
}
