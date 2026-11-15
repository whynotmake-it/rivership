import 'package:flutter_test/flutter_test.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots/src/presets/grid_progress_loaders.dart';

import 'review_helper.dart';

/// The loaders whose ink doesn't grow with progress, by design.
///
/// The hourglass only moves sand from one chamber to the other.
const _inkConserving = {'Hourglass'};

double _ink(DotGrid grid) => grid.values.fold(0, (sum, value) => sum + value);

void main() {
  final loaders = GridProgressLoaders.all.cast<GridProgressLoader>();

  test('names are unique', () {
    final names = loaders.map((loader) => loader.name).toSet();
    expect(names, hasLength(loaders.length));
  });

  for (final loader in loaders) {
    group(loader.name, () {
      final samples = [for (var i = 0; i <= 100; i++) i / 100];
      final grids = [for (final p in samples) loader.build(p)];

      test('has a description', () {
        expect(loader.description, isNotEmpty);
        expect(loader.isDeterminate, isTrue);
      });

      test('keeps the same size for every progress', () {
        for (final grid in grids) {
          expect(grid.columns, grids.first.columns);
          expect(grid.rows, grids.first.rows);
        }
      });

      test('values stay between 0 and 1', () {
        for (final grid in grids) {
          for (final value in grid.values) {
            expect(value, inInclusiveRange(0, 1));
          }
        }
      });

      test('starts minimal and ends complete', () {
        final start = grids.first;
        final end = grids.last;
        // Complete: no cell is left partially filled, apart from the faint
        // track of an emptied hourglass chamber.
        for (final value in end.values) {
          expect(value < 0.2 + 1e-3 || value > 1 - 1e-3, isTrue);
        }
        if (_inkConserving.contains(loader.name)) {
          // Everything that was full at the start has moved.
          for (var i = 0; i < start.values.length; i++) {
            if (start.values[i] > 0.5) expect(end.values[i], lessThan(0.5));
          }
          expect(_ink(end), closeTo(_ink(start), 1e-3));
        } else {
          for (var i = 0; i < start.values.length; i++) {
            expect(start.values[i], lessThanOrEqualTo(end.values[i] + 1e-6));
          }
          expect(_ink(start), lessThan(_ink(end) * 0.7));
        }
      });

      test('changes smoothly with progress', () {
        // A 1% step never pops a whole cell in: at most the waffle's one
        // dot per percent.
        for (var i = 1; i < grids.length; i++) {
          for (var cell = 0; cell < grids[i].values.length; cell++) {
            final change = grids[i].values[cell] - grids[i - 1].values[cell];
            expect(change.abs(), lessThanOrEqualTo(0.7 + 1e-4));
          }
        }
      });

      if (!_inkConserving.contains(loader.name)) {
        test('ink never decreases', () {
          for (var i = 1; i < grids.length; i++) {
            expect(
              _ink(grids[i]),
              greaterThanOrEqualTo(_ink(grids[i - 1]) - 1e-4),
            );
            // Not just in total: no single cell shrinks either.
            for (var cell = 0; cell < grids[i].values.length; cell++) {
              expect(
                grids[i].values[cell],
                greaterThanOrEqualTo(grids[i - 1].values[cell] - 1e-6),
              );
            }
          }
        });
      }
    });
  }

  // One widget test films them all: the shaders load once per test zone,
  // and a load cached by an earlier widget test never resolves in a later
  // one.
  testWidgets('review film strips', (tester) async {
    for (final loader in loaders) {
      final file = loader.name.toLowerCase().replaceAll(' ', '_');
      await reviewLoader(
        tester,
        loader,
        '/tmp/claude-0/review/grid_progress/$file.png',
      );
    }
  });
}
