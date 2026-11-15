import 'package:flutter_test/flutter_test.dart';
import 'package:merging_dots/merging_dots.dart';

import 'review_helper.dart';

void main() {
  group('GooLoaders', () {
    test('have unique names and descriptions', () {
      final names = {for (final loader in GooLoaders.all) loader.name};
      expect(names, hasLength(GooLoaders.all.length));
      for (final loader in GooLoaders.all) {
        expect(loader.description, isNotEmpty);
      }
    });

    for (final loader in GooLoaders.all) {
      group(loader.name, () {
        test('keeps one grid size', () {
          switch (loader) {
            case GridLoader(:final sequence):
              expect(sequence.frames, isNotEmpty);
              final first = sequence.frames.first.state;
              for (final frame in sequence.frames) {
                expect(frame.state.columns, first.columns);
                expect(frame.state.rows, first.rows);
              }
            case GridProgressLoader(:final build):
              final first = build(0);
              for (var step = 0; step <= 100; step++) {
                final grid = build(step / 100);
                expect(grid.columns, first.columns);
                expect(grid.rows, first.rows);
              }
            case CloudLoader() || CloudProgressLoader():
              fail('Goo loaders are grids.');
          }
        });

        testWidgets('renders for review', (tester) async {
          await reviewLoader(
            tester,
            loader,
            '/tmp/claude-0/review/goo/${loader.name.toLowerCase()}.png',
          );
        });
      });
    }
  });
}
