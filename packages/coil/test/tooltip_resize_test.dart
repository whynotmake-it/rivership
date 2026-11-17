// A shown anchored overlay (tooltip, popover) on a page that another page
// covers keeps laying itself out at the overlay's old size; when the window
// resized meanwhile, Flutter asserted `size == theater.size`.
import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

late BuildContext _home;

Widget _app(Widget anchor) => testApp(
  tier: CoilTier.pointer,
  home: Builder(
    builder: (context) {
      _home = context;
      return Center(child: anchor);
    },
  ),
);

final _tooltip = CoilTooltipAnchor.controlled(
  presence: const AlwaysStoppedAnimation(1),
  content: const Text('42'),
  bubble: (context, presence, content) => CoilTooltipBubble(child: content),
  child: const SizedBox.square(dimension: 20),
);

const _sizes = [Size(1432, 871), Size(300, 200), Size(800, 600)];

Future<void> _resizeThrough(WidgetTester tester) async {
  for (final size in _sizes) {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'at $size');
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'a frame later at $size');
  }
}

/// Covers the home page with an opaque page, resizes the window, and
/// uncovers it again.
Future<void> _coverAndResize(WidgetTester tester) async {
  Navigator.of(_home)
      .push(
        PageRouteBuilder<void>(
          pageBuilder: (context, _, _) => const SizedBox.expand(),
        ),
      )
      .ignore();
  await tester.pumpAndSettle();
  await _resizeThrough(tester);
  Navigator.of(_home).pop();
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('a shown tooltip follows the window resizing', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(_app(_tooltip));
    await _resizeThrough(tester);
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('a shown tooltip on a covered page survives the window '
      'resizing, and is back when uncovered', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(_app(_tooltip));
    await _coverAndResize(tester);
    expect(find.text('42'), findsOneWidget);
    // Placed for the new window: above the trigger, in the center.
    final bubble = tester.getRect(find.byType(CoilTooltipBubble));
    final trigger = tester.getRect(find.byType(CoilTooltipAnchor));
    expect(bubble.bottom, lessThanOrEqualTo(trigger.top));
    expect(bubble.center.dx, moreOrLessEquals(trigger.center.dx));
  });

  testWidgets('an open popover on a covered page survives the window '
      'resizing, and is back when uncovered', (tester) async {
    useScreen(tester, TestScreen.desktop);
    final controller = CoilPopoverController();
    await tester.pumpWidget(
      _app(
        CoilPopover(
          controller: controller,
          onClose: (_) => controller.hide(),
          popover: (context) => const SizedBox(width: 100, child: Text('pop')),
          child: const SizedBox.square(dimension: 20),
        ),
      ),
    );
    controller.show();
    await tester.pumpAndSettle();
    expect(find.text('pop'), findsOneWidget);
    await _coverAndResize(tester);
    expect(controller.isOpen, isTrue);
    expect(find.text('pop'), findsOneWidget);
  });

  testWidgets('a grouped tooltip follows the window resizing', (tester) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(
      _app(
        CoilTooltip(
          message: const Text('Bold'),
          child: CoilButton.icon(
            onPressed: () {},
            semanticLabel: 'Bold button',
            icon: const SizedBox.square(dimension: 16),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('Bold'), findsOneWidget);
    await _resizeThrough(tester);
    expect(find.text('Bold'), findsOneWidget);
  });
}
