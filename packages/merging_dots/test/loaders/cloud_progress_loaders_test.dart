import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merging_dots/merging_dots.dart';

import 'review_helper.dart';

void main() {
  final loaders = CloudProgressLoaders.all.cast<CloudProgressLoader>();

  test('names are unique', () {
    final names = loaders.map((loader) => loader.name).toSet();
    expect(names, hasLength(loaders.length));
  });

  for (final loader in loaders) {
    group(loader.name, () {
      final samples = [for (var i = 0; i <= 100; i++) loader.build(i / 100)];

      test('is determinate, described and uncolored', () {
        expect(loader.isDeterminate, isTrue);
        expect(loader.description, isNotEmpty);
        expect(loader.style.color, isNull);
      });

      test('keeps its canvas and dot count', () {
        final first = samples.first;
        expect(first.dotCount, greaterThan(0));
        expect(first.dotCount, lessThanOrEqualTo(DotCloud.maxDots));
        for (final cloud in samples) {
          expect(cloud.size, first.size);
          expect(cloud.dotCount, first.dotCount);
          for (final dot in cloud.dots) {
            expect(dot.radius, greaterThanOrEqualTo(0));
            expect(dot.x.isFinite && dot.y.isFinite, isTrue);
          }
        }
      });

      test('changes continuously', () {
        final longest = math.max(
          samples.first.size.width,
          samples.first.size.height,
        );
        // Between progress p and p + 0.01, no visible dot jumps.
        final maxMove = longest * 0.05;
        final maxGrowth = longest * 0.03;
        for (var s = 0; s < samples.length - 1; s++) {
          final before = samples[s].dots;
          final after = samples[s + 1].dots;
          for (var i = 0; i < before.length; i++) {
            final visible = before[i].radius > 0.05 || after[i].radius > 0.05;
            final moved = (before[i].center - after[i].center).distance;
            final grew = (before[i].radius - after[i].radius).abs();
            expect(
              !visible || moved <= maxMove,
              isTrue,
              reason: 'dot $i moved $moved at ${s / 100}',
            );
            expect(
              grew,
              lessThanOrEqualTo(maxGrowth),
              reason: 'dot $i changed radius by $grew at ${s / 100}',
            );
          }
        }
      });
    });
  }

  // One widget test films them all: the shaders load once, inside this
  // test's fake clock, so every review can wait on them.
  testWidgets('film strips for review', (tester) async {
    for (final loader in loaders) {
      await reviewLoader(
        tester,
        loader,
        '/tmp/claude-0/review/cloud_progress/${loader.name.toLowerCase()}.png',
      );
    }
  });
}
