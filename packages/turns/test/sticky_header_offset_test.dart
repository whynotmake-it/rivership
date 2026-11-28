import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:turns/scroll.dart';

const _viewport = Size(390, 800);

void main() {
  testWidgets(
    'the sticky header sits at stickyHeaderTopOffset, and scrollTo clears it '
    'wherever it is',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = _viewport;
      addTearDown(tester.view.reset);
      final controller = TurnScrollController();
      addTearDown(controller.dispose);

      Widget view({double? offset}) => Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: _viewport),
          child: TurnScrollView<int>.sectioned(
            controller: controller,
            itemCount: 100,
            itemId: (i) => 'm$i',
            sectionId: (i) => i ~/ 10,
            stickyHeaderTopOffset: offset,
            padding: const EdgeInsets.only(top: 100),
            autoScrollMotion: const Motion.instant(),
            sectionHeaderBuilder: (context, section, isSticky) => SizedBox(
              key: ValueKey('hdr:$section:${isSticky ? 's' : 'i'}'),
              height: 30,
            ),
            itemBuilder: (context, i) =>
                SizedBox(key: ValueKey('box:m$i'), height: 60),
          ),
        ),
      );

      for (final offset in [null, 20.0, 160.0]) {
        await tester.pumpWidget(view(offset: offset));
        await tester.pumpAndSettle();
        unawaited(controller.scrollTo('m45', animate: false));
        await tester.pumpAndSettle();

        final sticky = find.byKey(const ValueKey('hdr:4:s'));
        expect(sticky, findsOneWidget, reason: 'offset $offset');
        final stickyBox = tester.getRect(sticky);
        // Null means the top clearance (the 100 of padding).
        expect(stickyBox.top, closeTo(offset ?? 100, 1));
        // The item the view scrolled to is not under the overlay.
        final item = tester.getTopLeft(find.byKey(const ValueKey('box:m45')));
        expect(item.dy, greaterThanOrEqualTo(stickyBox.bottom - 1));
        // And not above the top clearance either.
        expect(item.dy, greaterThanOrEqualTo(100 - 1));
      }
    },
  );
}
