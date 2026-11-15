import 'package:flutter_test/flutter_test.dart';
import 'package:merging_dots/merging_dots.dart';

import 'review_helper.dart';

void main() {
  group('TilesLoaders', () {
    test('have unique names and descriptions', () {
      final names = {for (final loader in TilesLoaders.all) loader.name};
      expect(names, hasLength(TilesLoaders.all.length));
      for (final loader in TilesLoaders.all) {
        expect(loader.description, isNotEmpty);
      }
    });

    for (final loader in TilesLoaders.all) {
      group(loader.name, () {
        switch (loader) {
          case GridLoader(:final sequence):
            test('keeps one grid size in every frame', () {
              final first = sequence.frames.first.state;
              for (final frame in sequence.frames) {
                expect(frame.state.columns, first.columns);
                expect(frame.state.rows, first.rows);
              }
            });
            test('has more than one frame', () {
              expect(sequence.frames.length, greaterThan(1));
            });
          case GridProgressLoader(:final build):
            test('keeps one grid size for any progress', () {
              final first = build(0);
              for (var step = 0; step <= 20; step++) {
                final grid = build(step / 20);
                expect(grid.columns, first.columns);
                expect(grid.rows, first.rows);
              }
            });
            test('shows a difference between no and full progress', () {
              expect(build(0), isNot(build(1)));
            });
          case CloudLoader() || CloudProgressLoader():
            test('is a grid loader', () => fail('Expected a grid loader.'));
        }
      });
    }

    // One widget test for all strips: the shaders load once per test file.
    testWidgets('render review film strips', (tester) async {
      for (final loader in TilesLoaders.all) {
        await reviewLoader(
          tester,
          loader,
          '/tmp/claude-0/review/tiles/${loader.name.toLowerCase()}.png',
        );
      }
    });
  });
}
