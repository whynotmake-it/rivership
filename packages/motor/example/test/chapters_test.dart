import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/main.dart' as example;

Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  for (var t = Duration.zero; t < duration; t += frame) {
    await tester.pump(frame);
  }
}

const frame = Duration(milliseconds: 16);

Future<void> _open(WidgetTester tester, String title) async {
  tester.view
    ..physicalSize = const Size(430, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(CupertinoApp(home: chapterNamed(title).page()));
  await tester.pump();
}

int _faceUpCards(WidgetTester tester) => find
    .byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_CardFront',
    )
    .evaluate()
    .length;

void main() {
  test('every chapter has a route', () {
    expect(
      example.motorRoutes.map((route) => route.name),
      containsAll(chapters.map((chapter) => chapter.title)),
    );
    expect(example.motorRoutes, hasLength(chapters.length + 1));
  });

  for (final chapter in chapters) {
    testWidgets('${chapter.title} builds and plays', (tester) async {
      await _open(tester, chapter.title);
      await _pumpFor(tester, const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Retarget follows a change of mind', (tester) async {
    await _open(tester, 'Retarget');
    await tester.tap(find.text('Year'));
    await _pumpFor(tester, const Duration(milliseconds: 120));
    await tester.tap(find.text('Week'));
    await _pumpFor(tester, const Duration(milliseconds: 120));
    await tester.tap(find.text('Curve'));
    await tester.tap(find.text('Month'));
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    final month = tester.getCenter(find.text('248k'));
    expect(month.dx, closeTo(tester.getCenter(find.text('Month')).dx, 400));
    expect(find.text('steps this month'), findsOneWidget);
  });

  testWidgets('Throw lands the window in a corner', (tester) async {
    await _open(tester, 'Throw');
    final window = find.byIcon(CupertinoIcons.play_fill);
    await tester.fling(window, const Offset(300, 300), 2000);
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    final stage = tester.getRect(find.text('Throw it anywhere'));
    // Bottom right of the stage, below and right of its center.
    expect(tester.getCenter(window).dx, greaterThan(stage.center.dx));
    expect(tester.getCenter(window).dy, greaterThan(stage.center.dy));
  });

  testWidgets('Tracks opens, reverses mid-morph and closes', (tester) async {
    await _open(tester, 'Tracks');
    await tester.tap(find.byIcon(CupertinoIcons.add));
    await _pumpFor(tester, const Duration(milliseconds: 150));
    await tester.tap(find.byIcon(CupertinoIcons.add));
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    final opacity = tester.widget<Opacity>(
      find
          .ancestor(of: find.text('Note'), matching: find.byType(Opacity))
          .first,
    );
    expect(opacity.opacity, 0);
  });

  testWidgets('Steps pings and collapses again', (tester) async {
    await _open(tester, 'Steps');
    await tester.tap(find.text('Ping'));
    await _pumpFor(tester, const Duration(milliseconds: 800));
    expect(
      tester.getSize(find.text('motor 2.0 is here')).width,
      greaterThan(0),
    );
    await tester.tap(find.text('Ping'));
    await _pumpFor(tester, const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Steps fades out before collapsing and lands back compact', (
    tester,
  ) async {
    await _open(tester, 'Steps');
    dynamic island() => tester.widget(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Island'),
    );
    await tester.tap(find.text('Ping'));
    for (var t = Duration.zero; t < const Duration(seconds: 3); t += frame) {
      await tester.pump(frame);
      final Size size = island().size;
      if (t > const Duration(milliseconds: 1500) && size.width < 330) {
        expect(island().content, closeTo(0, 1e-9), reason: 'shown at $t');
      }
      if (t == const Duration(milliseconds: 384)) {
        expect(island().bell, closeTo(.45, .03));
      }
    }
    final Size size = island().size;
    expect(size.width, closeTo(120, .01));
    expect(size.height, closeTo(34, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sync holds every card until the last one lands', (tester) async {
    await _open(tester, 'Sync');
    // The middle card lands first, well before the left one.
    await _pumpFor(tester, const Duration(milliseconds: 800));
    expect(_faceUpCards(tester), 0);
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(_faceUpCards(tester), 3);

    await tester.tap(find.text('On landing'));
    await _pumpFor(tester, const Duration(milliseconds: 800));
    expect(_faceUpCards(tester), greaterThan(0));
    expect(_faceUpCards(tester), lessThan(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phases jumps between phases and autoplays', (tester) async {
    await _open(tester, 'Phases');
    await tester.tap(find.text('Full'));
    await _pumpFor(tester, const Duration(milliseconds: 200));
    await tester.tap(find.text('Card'));
    await _pumpFor(tester, const Duration(seconds: 2));
    await tester.tap(find.text('Autoplay'));
    await _pumpFor(tester, const Duration(seconds: 6));
    await tester.tap(find.text('Stop'));
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Scrub pauses, scrubs and resumes to the end', (tester) async {
    await _open(tester, 'Scrub');
    await tester.tap(find.text('Send'));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    final scrubber = tester.getRect(
      find
          .ancestor(
            of: find.byType(Stack),
            matching: find.byWidgetPredicate(
              (widget) => widget.runtimeType.toString() == '_Scrubber',
            ),
          )
          .first,
    );
    final gesture = await tester.startGesture(scrubber.centerLeft);
    await tester.pump();
    await gesture.moveTo(scrubber.center);
    await tester.pump();
    await gesture.moveTo(scrubber.centerRight);
    await tester.pump();
    await gesture.moveTo(scrubber.center);
    await tester.pump();
    await gesture.up();
    await _pumpFor(tester, const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    final caption = tester.widget<Opacity>(
      find
          .ancestor(of: find.text(r'$42 sent'), matching: find.byType(Opacity))
          .first,
    );
    expect(caption.opacity, closeTo(1, 1e-3));
  });
}
