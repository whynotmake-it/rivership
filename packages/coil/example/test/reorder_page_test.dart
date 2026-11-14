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

/// Drags [what] from its center to [to], in a few moves, and drops it.
Future<void> _drag(WidgetTester tester, Finder what, Offset to) async {
  final start = tester.getCenter(what);
  final gesture = await tester.startGesture(
    start,
    kind: PointerDeviceKind.mouse,
  );
  for (var i = 1; i <= 12; i++) {
    await gesture.moveTo(Offset.lerp(start, to, i / 12)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

/// The vertical order of [titles], top first.
List<String> _topToBottom(WidgetTester tester, List<String> titles) =>
    [...titles]..sort(
      (a, b) => tester
          .getCenter(find.text(a))
          .dy
          .compareTo(tester.getCenter(find.text(b)).dy),
    );

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
    // Only the lifted copy: its lane has closed up behind it.
    expect(find.text(title), findsOneWidget, reason: 'the lifted copy');
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

  testWidgets('a card dropped between two cards of a column goes there', (
    tester,
  ) async {
    await _pumpPage(tester);
    const title = 'Write the release notes';
    const above = 'Ship the dark theme';
    const below = 'Plan the next sprint';
    final between = Offset.lerp(
      tester.getCenter(find.text(above)),
      tester.getCenter(find.text(below)),
      0.5,
    )!;
    await _drag(tester, find.text(title), between);
    expect(_topToBottom(tester, [above, title, below]), [above, title, below]);
    expect(
      (tester.getCenter(find.text(title)).dx - between.dx).abs(),
      lessThan(130),
      reason: 'in the Doing column',
    );
    expect(_flight(tester, title), Offset.zero);
  });

  testWidgets('a card dragged within its column reorders it', (tester) async {
    await _pumpPage(tester);
    const first = 'Write the release notes';
    const second = 'Fix the login redirect';
    const third = 'Review the color tokens';
    const fourth = 'Profile the board';
    final between = Offset.lerp(
      tester.getCenter(find.text(third)),
      tester.getCenter(find.text(fourth)),
      0.5,
    )!;
    await _drag(tester, find.text(first), between);
    expect(_topToBottom(tester, [first, second, third, fourth]), [
      second,
      third,
      first,
      fourth,
    ]);
  });

  testWidgets('a tile dragged in the grid reorders it', (tester) async {
    await _pumpPage(tester);
    Finder tile(String text) => find.descendant(
      of: find.byType(MotionDropZone<int>),
      matching: find.text(text),
    );
    await tester.ensureVisible(tile('12'));
    await tester.pumpAndSettle();
    final three = tester.getRect(tile('3'));
    // The trailing side of tile 3, on tile 1's row.
    await _drag(tester, tile('1'), three.centerRight + const Offset(20, 0));
    double x(String text) => tester.getCenter(tile(text)).dx;
    expect(x('2'), lessThan(x('3')));
    expect(x('3'), lessThan(x('1')));
    expect(x('1'), lessThan(x('4')));
  });
}
