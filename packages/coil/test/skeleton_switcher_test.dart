// CoilSkeletonSwitcher: the hand-over between skeletons and loaded content.
import 'package:coil/coil.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: CoilTheme(
      data: CoilThemeData.light,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

const _content = SizedBox(width: 120, height: 40, child: Text('Ada'));

Widget _switcher({
  required bool loading,
  Map<CoilSkeletonTrack<Object>, Motion>? motions,
}) => CoilSkeletonSwitcher(
  loading: loading,
  motions: motions,
  skeleton: const CoilSkeleton(width: 120, height: 40),
  child: _content,
);

/// How opaque [finder]'s widget is on screen: the product of every opacity
/// above it.
double _onScreen(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) return 0;
  var opacity = 1.0;
  RenderObject? node = tester.renderObject(finder);
  while (node != null) {
    opacity *= switch (node) {
      RenderOpacity(:final opacity) => opacity,
      RenderAnimatedOpacity(:final opacity) => opacity.value.clamp(0.0, 1.0),
      _ => 1.0,
    };
    node = node.parent;
  }
  return opacity;
}

double _skeleton(WidgetTester tester) => _onScreen(
  tester,
  find.descendant(
    of: find.byType(CoilSkeleton),
    matching: find.byType(DecoratedBox),
  ),
);

double _text(WidgetTester tester) => _onScreen(tester, find.text('Ada'));

void main() {
  testWidgets('a first skeleton still waits out the grace period', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_switcher(loading: true)));
    await tester.pump(CoilSkeleton.grace ~/ 2);
    expect(_skeleton(tester), 0);
    await tester.pump(CoilSkeleton.grace + const Duration(milliseconds: 300));
    expect(_skeleton(tester), greaterThan(0.4));
  });

  testWidgets('content that lands in the grace period never shows a '
      'skeleton', (tester) async {
    await tester.pumpWidget(_app(_switcher(loading: true)));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(_app(_switcher(loading: false)));
    var most = 0.0;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final now = _skeleton(tester);
      if (now > most) most = now;
    }
    expect(most, lessThan(0.05));
    expect(_text(tester), 1);
  });

  testWidgets('going back to loading leaves no empty frame', (tester) async {
    await tester.pumpWidget(_app(_switcher(loading: false)));
    expect(_text(tester), 1);

    await tester.pumpWidget(_app(_switcher(loading: true)));
    // Every frame of the hand-over shows the content, the skeleton, or both
    // (a cross-fade dips a little where they meet). The pulse starts after.
    for (var i = 0; i < 15; i++) {
      final shown = _text(tester) + _skeleton(tester);
      expect(shown, greaterThan(0.8), reason: 'frame $i');
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Ada'), findsNothing, reason: 'the content has left');
    expect(_skeleton(tester), greaterThan(0.4));
  });

  testWidgets('an instant swap shows the skeleton on the first frame', (
    tester,
  ) async {
    final instant = {CoilSkeletonTrack.swap: const Motion.instant()};
    await tester.pumpWidget(_app(_switcher(loading: false, motions: instant)));
    await tester.pumpWidget(_app(_switcher(loading: true, motions: instant)));
    await tester.pump();
    expect(_skeleton(tester), 1);
    expect(_text(tester), 0);
  });

  testWidgets('loaded content cross-fades in over the skeleton', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_switcher(loading: true)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(_app(_switcher(loading: false)));
    await tester.pump(const Duration(milliseconds: 32));
    expect(_text(tester), allOf(greaterThan(0), lessThan(1)));
    expect(_skeleton(tester), greaterThan(0), reason: 'still fading out');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(CoilSkeleton), findsNothing);
    expect(_text(tester), 1);
  });

  testWidgets('reduced motion keeps the cross-fade and leaves no empty '
      'frame', (tester) async {
    for (final loading in [false, true]) {
      await tester.pumpWidget(
        _app(_switcher(loading: loading), reduceMotion: true),
      );
    }
    for (var i = 0; i < 15; i++) {
      expect(_text(tester) + _skeleton(tester), greaterThan(0.8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(_skeleton(tester), 1, reason: 'no pulse under reduced motion');
  });

  testWidgets('the leaving content is out of semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_switcher(loading: false)));
    expect(find.bySemanticsLabel('Ada'), findsOneWidget);
    await tester.pumpWidget(_app(_switcher(loading: true)));
    await tester.pump();
    expect(find.bySemanticsLabel('Ada'), findsNothing);
    semantics.dispose();
  });
}
