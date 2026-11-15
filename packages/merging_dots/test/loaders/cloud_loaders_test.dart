import 'package:flutter_test/flutter_test.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots/src/presets/cloud_loaders.dart';

import 'review_helper.dart';

void main() {
  group('CloudLoaders', () {
    test('have unique names and descriptions', () {
      final names = {for (final loader in CloudLoaders.all) loader.name};
      expect(names, hasLength(CloudLoaders.all.length));
      for (final loader in CloudLoaders.all) {
        expect(loader.name, isNotEmpty);
        expect(loader.description, endsWith('.'));
        expect(loader.isDeterminate, isFalse);
      }
    });

    for (final loader in CloudLoaders.all) {
      group(loader.name, () {
        final cloudLoader = loader as CloudLoader;
        final sequence = cloudLoader.sequence;

        test('keeps the canvas and dot count in every keyframe', () {
          expect(sequence.frames.length, greaterThan(1));
          expect(sequence.loop, LoopMode.loop);
          final first = sequence.frames.first.state;
          expect(first.dots, isNotEmpty);
          for (final frame in sequence.frames) {
            expect(frame.state.size, first.size);
            expect(frame.state.dots, hasLength(first.dots.length));
            for (final dot in frame.state.dots) {
              expect(dot.radius, greaterThanOrEqualTo(0));
              expect(dot.x.isFinite && dot.y.isFinite, isTrue);
            }
          }
        });

        test('uses the ambient color', () {
          expect(cloudLoader.style.color, isNull);
          expect(cloudLoader.style.blend, inInclusiveRange(4, 30));
        });
      });
    }

    // One test films them all: the shaders load once per test binding.
    testWidgets('render review film strips', (tester) async {
      for (final loader in CloudLoaders.all) {
        final sequence = (loader as CloudLoader).sequence;
        // One film frame per pose, so the strip shows a whole loop. Each
        // frame is a little longer than a pose, as a display's next vsync
        // would be.
        final steps = sequence.frames.length;
        final frameTime =
            sequence.motion.duration! + const Duration(milliseconds: 1);
        final fileName = loader.name.toLowerCase().replaceAll(' ', '_');
        await reviewLoader(
          tester,
          loader,
          '/tmp/claude-0/review/cloud/$fileName.png',
          duration: frameTime * steps,
          frames: steps,
        );
        // The same loop at spinner size.
        await reviewLoader(
          tester,
          loader,
          '/tmp/claude-0/review/cloud/small/$fileName.png',
          duration: frameTime * steps,
          frames: steps,
          size: 32,
        );
      }
    });
  });
}
