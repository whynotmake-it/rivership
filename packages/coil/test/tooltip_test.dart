import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

Widget _toolbar({List<String>? pressed}) => testApp(
  home: Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final name in ['Bold', 'Italic'])
          CoilTooltip(
            message: name,
            child: CoilButton.icon(
              onPressed: () => pressed?.add(name),
              semanticLabel: '$name button',
              icon: const SizedBox.square(dimension: 16),
            ),
          ),
      ],
    ),
  ),
);

void main() {
  testWidgets('a mouse opens it after the hover delay; leaving closes it', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(_toolbar());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.bySemanticsLabel('Bold button')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Bold'), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Bold'), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.text('Bold'), findsNothing);
  });

  testWidgets('right after one closes, the next opens without a delay', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(_toolbar());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.bySemanticsLabel('Bold button')));
    await tester.pump(const Duration(milliseconds: 250));
    await mouse.moveTo(
      tester.getCenter(find.bySemanticsLabel('Italic button')),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Italic'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('keyboard focus opens it at once; Escape closes it', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(_toolbar());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('Bold'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Bold'), findsNothing);
  });

  testWidgets('screen readers get the message', (tester) async {
    await tester.pumpWidget(_toolbar());
    final node = tester.getSemantics(find.bySemanticsLabel('Bold button'));
    expect(node.getSemanticsData().tooltip, 'Bold');
  });

  testWidgets(
    'a long-press shows it on Android only, without pressing the button',
    (tester) async {
      final pressed = <String>[];
      await tester.pumpWidget(_toolbar(pressed: pressed));
      final finger = await tester.startGesture(
        tester.getCenter(find.bySemanticsLabel('Bold button')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      final android = defaultTargetPlatform == TargetPlatform.android;
      expect(find.text('Bold'), android ? findsOneWidget : findsNothing);

      await finger.up();
      await tester.pumpAndSettle();
      expect(find.text('Bold'), findsNothing);
      // iOS has no tooltip here, so releasing taps the button like any
      // long touch; on Android the long-press belongs to the tooltip.
      expect(pressed, android ? isEmpty : ['Bold']);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
