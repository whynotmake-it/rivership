import 'dart:math' as math;

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

  testWidgets('Retarget follows a change of mind', (tester) async {
    await _open(tester, 'Retarget');
    await tester.tap(find.text('YEAR'));
    await _pumpFor(tester, const Duration(milliseconds: 120));
    await tester.tap(find.text('WEEK'));
    await _pumpFor(tester, const Duration(milliseconds: 120));
    await tester.tap(find.text('CURVE'));
    await tester.tap(find.text('MONTH'));
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    // The month's page has come to rest centred on the 430 px wide page.
    final month = tester.getCenter(find.text('248k'));
    expect(month.dx, closeTo(430 / 2, 1));
    expect(find.text('steps this month'), findsOneWidget);
  });

  testWidgets('Toggle switches by tap and by a dragged release', (
    tester,
  ) async {
    await _open(tester, 'Toggle');
    final toggle = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_Switch',
    );
    double thumb() => (tester.widget(toggle) as dynamic).thumb as double;
    await tester.tap(toggle);
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(thumb(), closeTo(1, 1e-3));

    // A short, quick flick back switches off even though the thumb is
    // still past the middle when it's let go.
    final flick = await tester.startGesture(tester.getCenter(toggle));
    for (var i = 0; i < 8; i++) {
      await flick.moveBy(const Offset(-5, 0));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await flick.up();
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(thumb(), closeTo(0, 1e-3));

    await tester.tap(find.byIcon(CupertinoIcons.heart));
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(find.byIcon(CupertinoIcons.heart_fill), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  int topCard(WidgetTester tester) =>
      (tester
                      .widgetList(
                        find.byWidgetPredicate(
                          (w) => w.runtimeType.toString() == '_Card',
                        ),
                      )
                      .last
                  as dynamic)
              .index
          as int;

  testWidgets('Card stack sends a thrown card under the stack', (tester) async {
    await _open(tester, 'Card stack');
    // A gentle drag springs back and keeps the card on top.
    await tester.drag(find.text('Clear'), const Offset(30, 0));
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(topCard(tester), 0);

    await tester.fling(find.text('Clear'), const Offset(200, -40), 2500);
    await _pumpFor(tester, const Duration(milliseconds: 60));
    // Still clearing the stack, so it's drawn above the others.
    expect(topCard(tester), 0);
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(topCard(tester), 1);
    final clear = tester.getCenter(find.text('Clear'));
    final redirect = tester.getCenter(find.text('Redirect'));
    expect((clear - redirect).distance, lessThan(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Steps fades out before collapsing and pings again once compact',
    (tester) async {
      await _open(tester, 'Steps');
      dynamic island() => tester.widget(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Island'),
      );
      await tester.tap(find.text('PING'));
      for (var t = Duration.zero; t < const Duration(seconds: 3); t += frame) {
        await tester.pump(frame);
        final Size size = island().size;
        if (t > const Duration(milliseconds: 1500) && size.width < 330) {
          expect(island().content, closeTo(0, 1e-9), reason: 'shown at $t');
        }
        if (t == const Duration(milliseconds: 304)) {
          expect(island().bell, closeTo(.35, .03));
        }
      }
      final Size size = island().size;
      expect(size.width, closeTo(120, .01));
      expect(size.height, closeTo(34, .01));
      expect(tester.takeException(), isNull);

      // A second ping while the first is still showing.
      await tester.tap(find.text('PING'));
      await _pumpFor(tester, const Duration(milliseconds: 800));
      expect(
        tester.getSize(find.text('motor 2.0 is here')).width,
        greaterThan(0),
      );
      await tester.tap(find.text('PING'));
      await _pumpFor(tester, const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Sync holds every card until the last one lands', (tester) async {
    await _open(tester, 'Sync');
    // The middle card lands first, well before the left one.
    await _pumpFor(tester, const Duration(milliseconds: 800));
    expect(_faceUpCards(tester), 0);
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(_faceUpCards(tester), 3);

    await tester.tap(find.text('ON LANDING'));
    await _pumpFor(tester, const Duration(milliseconds: 800));
    expect(_faceUpCards(tester), greaterThan(0));
    expect(_faceUpCards(tester), lessThan(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phases jumps between phases and autoplays', (tester) async {
    await _open(tester, 'Phases');
    await tester.tap(find.text('FULL'));
    await _pumpFor(tester, const Duration(milliseconds: 200));
    await tester.tap(find.text('CARD'));
    await _pumpFor(tester, const Duration(seconds: 2));
    await tester.tap(find.text('AUTOPLAY'));
    await _pumpFor(tester, const Duration(seconds: 6));
    await tester.tap(find.text('STOP'));
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  // The artwork is always inside the player: 40 px wide in mini, 104 in
  // card and 272 in full.
  final artwork = find.byIcon(CupertinoIcons.music_note_2);
  double note(WidgetTester tester) => tester.getSize(artwork).width;

  testWidgets('Phases survives being dragged and flung far past its ends', (
    tester,
  ) async {
    await _open(tester, 'Phases');
    await tester.drag(artwork, const Offset(0, -1500));
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(note(tester), closeTo(40, .5));

    await tester.tap(find.text('FULL'));
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(note(tester), closeTo(272, .5));
    await tester.fling(artwork, const Offset(0, -500), 8000);
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(note(tester), closeTo(40, .5));

    await tester.drag(artwork, const Offset(0, 2500));
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(note(tester), closeTo(272, .5));
  });

  testWidgets('Phases lands a slow drag on the nearest phase', (tester) async {
    await _open(tester, 'Phases');
    // A little more than one phase down, let go slowly: card.
    await tester.drag(artwork, const Offset(0, 190));
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(note(tester), closeTo(104, .5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phases hands a drag back to autoplay', (tester) async {
    await _open(tester, 'Phases');
    await tester.tap(find.text('AUTOPLAY'));
    await _pumpFor(tester, const Duration(milliseconds: 400));
    await tester.fling(artwork, const Offset(0, 420), 600);
    await tester.pump();
    expect(find.text('STOP'), findsOneWidget);
    await _pumpFor(tester, const Duration(milliseconds: 600));
    // Landed in full, and autoplay heads back from there.
    expect(note(tester), closeTo(272, 1));
    // Autoplay walks back down to mini.
    var smallest = note(tester);
    for (var t = Duration.zero; t < const Duration(seconds: 3); t += frame) {
      await tester.pump(frame);
      smallest = math.min(smallest, note(tester));
    }
    expect(smallest, closeTo(40, 1));
    await tester.tap(find.text('STOP'));
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Scrub pauses, scrubs and resumes to the end', (tester) async {
    await _open(tester, 'Scrub');
    await tester.tap(find.text('SEND'));
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

  _scrollWinsOverScrubberTest();
}

void _scrollWinsOverScrubberTest() {
  testWidgets('Scrub plays on when a scroll takes over the scrubber', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(430, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(CupertinoApp(home: chapterNamed('Scrub').page()));
    await tester.pump();
    final slider = find.bySemanticsLabel('Playback position');
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    await tester.tap(find.text('SEND'));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    // Press the scrubber, then scroll the page: the scroll wins.
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
    }
    await gesture.up();
    await _pumpFor(tester, const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
    final caption = tester.widget<Opacity>(
      find
          .ancestor(of: find.text(r'$42 sent'), matching: find.byType(Opacity))
          .first,
    );
    expect(caption.opacity, closeTo(1, 1e-3));
  });
}
