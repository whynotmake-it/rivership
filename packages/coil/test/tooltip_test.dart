import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_widgets/motor_widgets.dart';

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

  testWidgets('it slides 4 px toward the trigger as a resampled image', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(_toolbar());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final sliding = tester.getRect(_bubble('Bold')).top;
    expect(_resampled(tester), isTrue);
    await tester.pumpAndSettle();
    final rest = tester.getRect(_bubble('Bold')).top;
    // Above the trigger, it comes down toward it.
    expect(rest - sliding, inExclusiveRange(0, 4));
    expect(_resampled(tester), isFalse, reason: 'at rest it paints directly');
  });

  testWidgets('with reduced motion it fades in place', (tester) async {
    _reduceMotion(tester);
    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(_toolbar());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final fading = tester.getRect(_bubble('Bold'));
    expect(_bubbleOpacity(tester, 'Bold'), inExclusiveRange(0, 1));
    expect(_resampled(tester), isFalse);
    await tester.pumpAndSettle();
    expect(tester.getRect(_bubble('Bold')), fading);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_bubbleOpacity(tester, 'Bold'), inExclusiveRange(0, 1));
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

  testWidgets('in a group one bubble glides to the next button', (
    tester,
  ) async {
    useScreen(tester, TestScreen.desktop);
    Widget button(String label) => CoilTooltip(
      message: label,
      child: CoilButton(onPressed: () {}, child: Text('[$label]')),
    );
    await tester.pumpWidget(
      testApp(
        tier: CoilTier.pointer,
        home: Center(
          child: CoilTooltipGroup(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 40,
              children: [button('Bold'), button('Italic')],
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('[Bold]')));
    await tester.pump(CoilTooltipAnchor.hoverDelay);
    await tester.pumpAndSettle();
    expect(find.text('Bold'), findsOneWidget);

    await mouse.moveTo(tester.getCenter(find.text('[Italic]')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // Mid-glide the bubble is between the buttons, not reopening.
    final mid = tester.getCenter(find.byType(MotionSize)).dx;
    expect(mid, greaterThan(tester.getCenter(find.text('[Bold]')).dx));
    expect(mid, lessThan(tester.getCenter(find.text('[Italic]')).dx));
    await tester.pumpAndSettle();
    expect(find.text('Bold'), findsNothing);
    expect(find.text('Italic'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Italic')).dx,
      closeTo(tester.getCenter(find.text('[Italic]')).dx, 1),
    );
  });

  _groupWidthTests();
}

/// A tooltip group over two buttons, the first with a long message.
Widget _group({String long = 'Strikethrough'}) {
  Widget button(String label) => CoilTooltip(
    message: label,
    child: CoilButton(onPressed: () {}, child: Text('[$label]')),
  );
  return testApp(
    tier: CoilTier.pointer,
    home: Center(
      child: CoilTooltipGroup(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 40,
          children: [button(long), button('Bold')],
        ),
      ),
    ),
  );
}

/// The bubble around the visible [message].
Finder _bubble(String message) => find
    .ancestor(of: find.text(message), matching: find.byType(DecoratedBox))
    .first;

/// Hovers `[from]` until its bubble is open, then moves to `[to]` and
/// pumps one frame.
Future<double> _glide(
  WidgetTester tester,
  String from,
  String to, {
  String long = 'Strikethrough',
}) async {
  useScreen(tester, TestScreen.desktop);
  await tester.pumpWidget(_group(long: long));
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(find.text('[$from]')));
  await tester.pump(CoilTooltipAnchor.hoverDelay);
  await tester.pumpAndSettle();
  final start = tester.getSize(_bubble(from)).width;
  await mouse.moveTo(tester.getCenter(find.text('[$to]')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  return start;
}

void _groupWidthTests() {
  testWidgets('in a group the bubble narrows while the old label fades', (
    tester,
  ) async {
    final start = await _glide(tester, 'Strikethrough', 'Bold');
    // The old label is still fading out, and the width already follows the
    // shorter one.
    expect(find.text('Strikethrough'), findsOneWidget);
    expect(tester.getSize(_bubble('Bold')).width, lessThan(start));
    await tester.pumpAndSettle();
    expect(find.text('Strikethrough'), findsNothing);
    expect(tester.getSize(_bubble('Bold')).width, lessThan(start));
  });

  testWidgets('in a group the old label keeps its lines while it fades', (
    tester,
  ) async {
    const long = 'Strikethrough text';
    // The lines the label's text is laid out on, by their tops.
    Set<double> lines() {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(long));
      return {
        for (final box in paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: long.length),
        ))
          box.top,
      };
    }

    useScreen(tester, TestScreen.desktop);
    await tester.pumpWidget(_group(long: long));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('[$long]')));
    await tester.pump(CoilTooltipAnchor.hoverDelay);
    await tester.pumpAndSettle();
    expect(lines(), hasLength(1));
    final width = tester.getSize(_bubble(long)).width;

    await mouse.moveTo(tester.getCenter(find.text('[Bold]')));
    await tester.pump();
    var frames = 0;
    while (find.text(long).evaluate().isNotEmpty) {
      expect(lines(), hasLength(1), reason: 'frame $frames');
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
    }
    // The bubble narrowed while the old label was still there.
    expect(frames, greaterThan(2));
    expect(tester.getSize(_bubble('Bold')).width, lessThan(width));
  });

  testWidgets('in a group the bubble widens for a longer label', (
    tester,
  ) async {
    final start = await _glide(tester, 'Bold', 'Strikethrough');
    final mid = tester.getSize(_bubble('Strikethrough')).width;
    expect(mid, greaterThan(start));
    await tester.pumpAndSettle();
    expect(find.text('Bold'), findsNothing);
    expect(tester.getSize(_bubble('Strikethrough')).width, greaterThan(mid));
  });

  testWidgets('with reduced motion the bubble fits the new label at once', (
    tester,
  ) async {
    _reduceMotion(tester);
    final start = await _glide(tester, 'Strikethrough', 'Bold');
    final first = tester.getSize(_bubble('Bold')).width;
    expect(first, lessThan(start));
    await tester.pumpAndSettle();
    expect(tester.getSize(_bubble('Bold')).width, first);
  });

  testWidgets('with reduced motion the bubble stays and its label '
      'crossfades', (tester) async {
    _reduceMotion(tester);
    await _glide(tester, 'Strikethrough', 'Bold');
    expect(find.text('Strikethrough'), findsOneWidget);
    expect(find.text('Bold'), findsOneWidget);
    // One bubble holds both labels.
    expect(
      tester.element(_bubble('Strikethrough')),
      tester.element(_bubble('Bold')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Strikethrough'), findsNothing);
  });
}

void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// The opacity the bubble around [message] is painted with.
double _bubbleOpacity(WidgetTester tester, String message) => tester
    .renderObject<RenderOpacity>(
      find.ancestor(of: _bubble(message), matching: find.byType(Opacity)).first,
    )
    .opacity;

Iterable<Layer> _layers(Layer layer) sync* {
  yield layer;
  if (layer is ContainerLayer) {
    for (
      var child = layer.firstChild;
      child != null;
      child = child.nextSibling
    ) {
      yield* _layers(child);
    }
  }
}

/// Whether something is painted as a resampled image (a matrix filter).
bool _resampled(WidgetTester tester) => _layers(tester.layers.first).any(
  (layer) =>
      layer is ImageFilterLayer &&
      layer.imageFilter.toString().startsWith('ImageFilter.matrix'),
);
