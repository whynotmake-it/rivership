import 'package:coil/coil.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

final _anchor = find.byKey(const ValueKey('anchor'));
final _content = find.byKey(const ValueKey('content'));
final _controller = CoilPopupController();

/// An app with an anchor at [anchorTop]; opening it shows a popover of
/// [contentHeight].
Widget _app({
  required double anchorTop,
  double contentHeight = 200,
  bool reduceMotion = false,
  bool openOnLongPress = false,
  String? anchorLabel,
  CoilTier tier = CoilTier.pointer,
  CoilMotion? motion,
}) => MediaQuery(
  data: MediaQueryData(
    size: const Size(400, 600),
    disableAnimations: reduceMotion,
  ),
  child: WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, navigator) => CoilTheme(
      data: CoilThemeData.light,
      child: CoilAdaptiveScope(tier: tier, child: navigator!),
    ),
    onGenerateRoute: (_) => PageRouteBuilder<void>(
      pageBuilder: (context, _, _) => Stack(
        children: [
          Positioned(
            left: 40,
            top: anchorTop,
            child: CoilAdaptivePopup(
              controller: _controller,
              presentation: CoilPresentation.popover,
              motion: motion,
              traits: () => const CoilOverlayTraits(
                kind: CoilOverlayKind.actionMenu,
                itemCount: 1,
              ),
              content: (context, popup) => Semantics(
                label: 'Content',
                container: true,
                child: SizedBox(
                  key: const ValueKey('content'),
                  width: 160,
                  height: contentHeight,
                ),
              ),
              popover: (context, content) => content,
              sheet: (context, content) => content,
              child: Semantics(
                label: anchorLabel,
                container: anchorLabel != null,
                child: GestureDetector(
                  key: const ValueKey('anchor'),
                  behavior: HitTestBehavior.opaque,
                  onTap: openOnLongPress ? null : _controller.open,
                  onLongPress: openOnLongPress ? _controller.open : null,
                  child: const SizedBox(width: 120, height: 36),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(_anchor);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens below the anchor when the content fits there', (
    tester,
  ) async {
    await tester.pumpWidget(_app(anchorTop: 40));
    await _open(tester);
    expect(
      tester.getRect(_content).top,
      tester.getRect(_anchor).bottom + 6,
    );
  });

  testWidgets('opens above when the laid-out content needs more room', (
    tester,
  ) async {
    // 200 below the anchor's bottom is not enough for 300 of content; above
    // there is more room.
    await tester.pumpWidget(_app(anchorTop: 380, contentHeight: 300));
    await _open(tester);
    expect(
      tester.getRect(_content).bottom,
      tester.getRect(_anchor).top - 6,
    );
  });

  testWidgets('follows the anchor in the same frame when it moves', (
    tester,
  ) async {
    await tester.pumpWidget(_app(anchorTop: 40));
    await _open(tester);
    await tester.pumpWidget(_app(anchorTop: 100));
    expect(
      tester.getRect(_content).top,
      tester.getRect(_anchor).bottom + 6,
    );
  });

  testWidgets('under reduced motion it fades without growing', (
    tester,
  ) async {
    await tester.pumpWidget(_app(anchorTop: 40, reduceMotion: true));
    await tester.tap(_anchor);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.getSize(_content), const Size(160, 200));
    expect(
      tester.getRect(_content).top,
      tester.getRect(_anchor).bottom + 6,
      reason: 'no slide while it fades in',
    );
    await tester.pumpAndSettle();
  });

  group("opens and closes on the tier's tokens", () {
    // Far apart, so the tier's choice shows in the timing.
    const motion = CoilMotion(
      quickExit: CupertinoMotion(duration: Duration(milliseconds: 100)),
      standard: CupertinoMotion(duration: Duration(milliseconds: 800)),
      standardExit: CupertinoMotion(duration: Duration(milliseconds: 800)),
    );

    Future<bool> openAfter300ms(WidgetTester tester, CoilTier tier) async {
      await tester.pumpWidget(
        _app(anchorTop: 40, tier: tier, motion: motion),
      );
      await tester.tap(_anchor);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final grown = tester.getRect(_content).width == 160;
      await tester.pumpAndSettle();
      return grown;
    }

    Future<bool> goneAfter300ms(WidgetTester tester, CoilTier tier) async {
      await tester.pumpWidget(
        _app(anchorTop: 40, tier: tier, motion: motion),
      );
      await _open(tester);
      _controller.close();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final gone = _content.evaluate().isEmpty;
      await tester.pumpAndSettle();
      return gone;
    }

    for (final (tier, settled) in [
      (CoilTier.pointer, true),
      (CoilTier.touch, false),
    ]) {
      testWidgets('${tier.name}: in 300 ms it is ${settled ? '' : 'not '}'
          'fully in', (tester) async {
        expect(await openAfter300ms(tester, tier), settled);
      });

      testWidgets('${tier.name}: in 300 ms it is ${settled ? '' : 'not '}'
          'gone', (tester) async {
        expect(await goneAfter300ms(tester, tier), settled);
      });
    }
  });

  testWidgets('scales an image of its content while it grows, not the text', (
    tester,
  ) async {
    // Text drawn under an animated scale is re-rasterized every frame and
    // its glyphs snap to the pixel grid one by one, so they jitter.
    bool resampled() => _layers(tester.layers.first).any(
      (layer) =>
          layer is ImageFilterLayer &&
          layer.imageFilter.toString().startsWith('ImageFilter.matrix'),
    );
    await tester.pumpWidget(_app(anchorTop: 40));
    await tester.tap(_anchor);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.getRect(_content).width, lessThan(160));
    expect(resampled(), isTrue);
    await tester.pumpAndSettle();
    expect(resampled(), isFalse, reason: 'at rest it paints directly');
  });

  testWidgets('a long press that opens it lifts without closing it', (
    tester,
  ) async {
    await tester.pumpWidget(_app(anchorTop: 40, openOnLongPress: true));
    await tester.longPress(_anchor);
    await tester.pumpAndSettle();
    expect(_content, findsOneWidget);
    await tester.tapAt(const Offset(390, 590));
    await tester.pumpAndSettle();
    expect(_content, findsNothing, reason: 'a later tap outside closes it');
  });

  testWidgets('screen readers reach the content right after its anchor', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(anchorTop: 40, anchorLabel: 'Anchor'));
    await _open(tester);
    final order = tester.semantics
        .simulatedAccessibilityTraversal()
        .map((node) => node.label)
        .where((label) => label.isNotEmpty)
        .toList();
    expect(order.indexOf('Content'), order.indexOf('Anchor') + 1);
    semantics.dispose();
  });
}

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
