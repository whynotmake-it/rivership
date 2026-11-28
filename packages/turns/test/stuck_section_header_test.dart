import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:turns/scroll.dart';

const _viewport = Size(390, 800);

void main() {
  testWidgets(
    'a stuck inline header is hidden unless stuckSectionHeaderBuilder draws '
    'what the sticky copy leaves out, and no other header is affected',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = _viewport;
      addTearDown(tester.view.reset);
      final controller = TurnScrollController();
      addTearDown(controller.dispose);

      // A divider made of a rule and a date pill; only the pill is sticky.
      Widget pill(int day) => Text('day $day');
      Widget view({required bool drawStuck}) => Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: _viewport),
          child: TurnScrollView<int>.sectioned(
            controller: controller,
            itemCount: 100,
            itemId: (i) => 'm$i',
            sectionId: (i) => i ~/ 10,
            autoScrollMotion: const Motion.instant(),
            sectionHeaderBuilder: (context, day, isSticky) => SizedBox(
              height: 30,
              child: isSticky
                  ? pill(day)
                  : Stack(children: [Text('rule $day'), pill(day)]),
            ),
            stuckSectionHeaderBuilder: drawStuck
                ? (context, day) =>
                      SizedBox(height: 30, child: Text('rule $day'))
                : null,
            itemBuilder: (context, i) =>
                SizedBox(key: ValueKey('box:m$i'), height: 200),
          ),
        ),
      );

      Future<void> openOnDay4() async {
        unawaited(controller.scrollTo('m40', animate: false));
        await tester.pumpAndSettle();
      }

      // By default the stuck header is hidden whole: its rule goes with the
      // pill the sticky copy repeats.
      await tester.pumpWidget(view(drawStuck: false));
      await tester.pumpAndSettle();
      await openOnDay4();
      final hidden = tester.widget<Visibility>(
        find
            .ancestor(
              of: find.text('rule 4'),
              matching: find.byType(Visibility),
            )
            .first,
      );
      expect(hidden.visible, isFalse);

      // With a stuck builder the rule stays, and the pill shows once: the
      // sticky one.
      await tester.pumpWidget(view(drawStuck: true));
      await tester.pumpAndSettle();
      await openOnDay4();
      expect(find.text('rule 4'), findsOneWidget);
      expect(find.text('day 4'), findsOneWidget);

      // A header further down that is not stuck keeps its rule and its pill.
      unawaited(controller.scrollTo('m48', animate: false));
      await tester.pumpAndSettle();
      expect(find.text('rule 5'), findsOneWidget);
      expect(find.text('day 5'), findsOneWidget);
    },
  );
}
