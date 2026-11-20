import 'package:coil/coil.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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

bool _resampled(WidgetTester tester) => _layers(tester.layers.first).any(
  (layer) =>
      layer is ImageFilterLayer &&
      layer.imageFilter.toString().startsWith('ImageFilter.matrix'),
);

Widget _fade(double presence, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: CoilBlurFade(
        presence: AlwaysStoppedAnimation(presence),
        offset: const Offset(0, 4),
        child: const SizedBox(width: 100, height: 40),
      ),
    ),
  ),
);

void main() {
  // Text drawn under an animated scale is re-rasterized every frame and its
  // glyphs snap to the pixel grid one by one, so they jitter.
  testWidgets('scales and slides an image of its child, not the text', (
    tester,
  ) async {
    await tester.pumpWidget(_fade(0.5));
    expect(_resampled(tester), isTrue);
  });

  testWidgets('at rest it paints its child directly', (tester) async {
    await tester.pumpWidget(_fade(1));
    expect(_resampled(tester), isFalse);
  });

  testWidgets('under reduced motion it only fades', (tester) async {
    await tester.pumpWidget(_fade(0.5, reduceMotion: true));
    expect(_resampled(tester), isFalse);
    expect(
      tester.getRect(find.byType(SizedBox)).width,
      100,
      reason: 'no scale',
    );
  });
}
