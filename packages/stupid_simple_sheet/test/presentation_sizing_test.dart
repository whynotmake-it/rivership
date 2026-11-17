import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';
import 'package:stupid_simple_sheet/src/sheet_recede.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// How much a receded sheet or page is scaled down.
const _recededScale = 1 - 0.0835;

/// Opens and closes in a fixed, linear second, so that pumping a share of
/// it moves the sheet by the same share.
const _linear = CurvedMotion(Duration(seconds: 1));

final _device = Devices.ios.iPhone16;

/// Runs [body] on an iPhone 16 sized view, so that every layout, including
/// the one a golden is taken from, sees the same screen.
void _testWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    final restore = setTestViewForDevice(_device, Orientation.portrait);
    try {
      await body(tester);
    } finally {
      restore();
    }
  });
}

const _homeKey = ValueKey('home');

Future<NavigatorState> _pumpHome(WidgetTester tester) async {
  await tester.pumpWidget(
    const CupertinoApp(
      home: ColoredBox(
        key: _homeKey,
        color: Color(0xFFE5F0FF),
        child: SizedBox.expand(
          child: GridPaper(color: Color(0x33007AFF)),
        ),
      ),
    ),
  );
  return tester.state<NavigatorState>(find.byType(Navigator));
}

/// Content with a finite height.
Widget _short(Key key, Color color, {double height = 240}) {
  return Column(
    key: key,
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          height: height - 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    ],
  );
}

/// Content that takes all the height it is given.
Widget _list(Key key, Color color) {
  return ListView.builder(
    key: key,
    padding: const EdgeInsets.all(24),
    itemCount: 40,
    itemBuilder: (context, index) => Container(
      height: 56,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: index.isEven ? 1 : .6),
        borderRadius: BorderRadius.circular(14),
      ),
    ),
  );
}

StupidSimpleGlassSheetRoute<void> _glass(
  Widget child, {
  PresentationSizing sizing = PresentationSizing.automatic,
  Motion motion = _linear,
  SheetSnappingConfig snappingConfig = SheetSnappingConfig.full,
  bool originateAboveBottomViewInset = false,
}) {
  return StupidSimpleGlassSheetRoute<void>(
    motion: motion,
    presentationSizing: sizing,
    snappingConfig: snappingConfig,
    originateAboveBottomViewInset: originateAboveBottomViewInset,
    child: child,
  );
}

const _behind = ValueKey('behind');
const _top = ValueKey('top');

const _purple = Color(0xFF5856D6);
const _blue = Color(0xFF007AFF);
const _orange = Color(0xFFFF9500);
const _green = Color(0xFF34C759);

/// How much the widget with [key] is scaled, measured from its width against
/// its untransformed width.
double _scaleOf(WidgetTester tester, Key key) {
  final finder = find.byKey(key);
  final box = tester.renderObject<RenderBox>(finder);
  return tester.getRect(finder).width / box.size.width;
}

/// Drags down from [from] by [distance] in small steps, the way a finger
/// does, and returns the gesture without lifting it.
Future<TestGesture> _dragDown(
  WidgetTester tester,
  Offset from,
  double distance,
) async {
  final gesture = await tester.startGesture(from);
  const step = 20.0;
  for (var moved = 0.0; moved < distance; moved += step) {
    await gesture.moveBy(const Offset(0, step));
    await tester.pump(const Duration(milliseconds: 16));
  }
  return gesture;
}

/// Takes a golden named [name], then puts the iPhone 16 sized view back,
/// which taking the golden resets.
Future<void> _golden(WidgetTester tester, String name) async {
  await snap.golden(
    name: 'sizing $name',
    device: _device,
    // These goldens have no text to block, and blocking text renders
    // translucent layers, such as the dimming of a covered sheet, opaque.
    settings: const SnaptestSettings(blockText: false),
  );
  setTestViewForDevice(_device, Orientation.portrait);
  // Lay out again, then let the sheets report how far they recede.
  await tester.pump(Duration.zero);
  await tester.pump(Duration.zero);
}

void main() {
  group('recedeFactorFor', () {
    test('is 1 for a sheet that reaches the top', () {
      expect(recedeFactorFor(height: 800, maxHeight: 800), 1);
    });

    test('is 0 for a sheet further than the recede distance from the top', () {
      expect(
        recedeFactorFor(height: 800 - kSheetRecedeDistance, maxHeight: 800),
        0,
      );
      expect(recedeFactorFor(height: 200, maxHeight: 800), 0);
    });

    test('grows linearly within the recede distance', () {
      expect(
        recedeFactorFor(
          height: 800 - kSheetRecedeDistance / 4,
          maxHeight: 800,
        ),
        closeTo(.75, 1e-9),
      );
    });

    test('is 1 for an unbounded max height', () {
      expect(
        recedeFactorFor(height: 200, maxHeight: double.infinity),
        1,
      );
    });
  });

  group('StupidSimpleGlassSheetRoute presentationSizing', () {
    test('defaults to automatic', () {
      expect(
        StupidSimpleGlassSheetRoute<void>(child: const SizedBox())
            .presentationSizing,
        PresentationSizing.automatic,
      );
    });

    test('automatic is page fitted vertically', () {
      expect(
        PresentationSizing.automatic,
        PresentationSizing.page.fitted(horizontal: false),
      );
      expect(PresentationSizing.page.fitted(), isNot(PresentationSizing.page));
    });

    group('sizes', () {
      _testWidgets('a fitted sheet to short content', (tester) async {
        final navigator = await _pumpHome(tester);
        navigator.push(_glass(_short(_top, _purple))).ignore();
        await tester.pumpAndSettle();

        final screen = tester.getSize(find.byType(CupertinoApp));
        final sheet = tester.getRect(find.byType(SheetBackground));
        expect(sheet.height, 240);
        expect(sheet.bottom, screen.height);
        await _golden(tester, 'fitted short');
      });

      _testWidgets('a fitted sheet with a scroll view to full height',
          (tester) async {
        final navigator = await _pumpHome(tester);
        navigator.push(_glass(_list(_top, _blue))).ignore();
        await tester.pumpAndSettle();

        final full = tester.getSize(find.byType(CupertinoApp)).height -
            _device.safeAreas.top;
        expect(
          tester.getSize(find.byType(SheetBackground)).height,
          moreOrLessEquals(full),
        );
        await _golden(tester, 'fitted scroll view');
      });

      _testWidgets('a page sheet to full height', (tester) async {
        final navigator = await _pumpHome(tester);
        navigator
            .push(
              _glass(_short(_top, _purple), sizing: PresentationSizing.page),
            )
            .ignore();
        await tester.pumpAndSettle();

        final screen = tester.getSize(find.byType(CupertinoApp));
        expect(
          tester.getSize(find.byType(SheetBackground)).height,
          moreOrLessEquals(screen.height - _device.safeAreas.top),
        );
        expect(
          tester.getRect(find.byKey(_top)).top,
          tester.getRect(find.byType(SheetBackground)).top,
          reason: 'short content sits at the top of a page sheet',
        );
        await _golden(tester, 'page short');
      });
    });

    group('attached to the bottom edge', () {
      _testWidgets('takes the full width with narrow content', (tester) async {
        final navigator = await _pumpHome(tester);
        navigator
            .push(
              _glass(
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [SizedBox(key: _top, width: 100, height: 100)],
                ),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();

        final screen = tester.getSize(find.byType(CupertinoApp));
        expect(
          tester.getSize(find.byType(SheetBackground)),
          const Size(393, 100),
        );
        expect(screen.width, 393);
      });

      _testWidgets('ignores horizontal fitting', (tester) async {
        final navigator = await _pumpHome(tester);
        navigator
            .push(
              _glass(
                _short(_top, _purple),
                sizing: PresentationSizing.page.fitted(vertical: false),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();

        final screen = tester.getSize(find.byType(CupertinoApp));
        expect(
          tester.getSize(find.byType(SheetBackground)),
          Size(screen.width, screen.height - _device.safeAreas.top),
          reason: 'a sheet that only fits horizontally keeps the page height',
        );
      });
    });

    group('the page behind the first sheet', () {
      for (final (name, sizing) in [
        ('automatic', PresentationSizing.automatic),
        ('page', PresentationSizing.page),
      ]) {
        _testWidgets('does not recede for a $name sheet', (tester) async {
          final navigator = await _pumpHome(tester);
          navigator
              .push(_glass(_short(_top, _purple), sizing: sizing))
              .ignore();
          await tester.pumpAndSettle();
          expect(_scaleOf(tester, _homeKey), 1);
        });
      }
    });

    group('stacked', () {
      _testWidgets('a short fitted sheet leaves a page sheet in place',
          (tester) async {
        final navigator = await _pumpHome(tester);
        navigator
            .push(
              _glass(_list(_behind, _blue), sizing: PresentationSizing.page),
            )
            .ignore();
        await tester.pumpAndSettle();
        navigator.push(_glass(_short(_top, _purple))).ignore();

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(_scaleOf(tester, _behind), 1, reason: 'not while opening');
        await _golden(tester, 'stacked fitted short over page open 50');

        await tester.pumpAndSettle();
        expect(_scaleOf(tester, _behind), 1);
        await _golden(tester, 'stacked fitted short over page');
      });

      _testWidgets('a page sheet pushes back a short fitted sheet',
          (tester) async {
        final navigator = await _pumpHome(tester);
        navigator.push(_glass(_short(_behind, _purple))).ignore();
        await tester.pumpAndSettle();
        navigator
            .push(
              _glass(_short(_top, _orange), sizing: PresentationSizing.page),
            )
            .ignore();
        await tester.pumpAndSettle();
        expect(_scaleOf(tester, _behind), moreOrLessEquals(_recededScale));
        await _golden(tester, 'stacked page over fitted short');
      });

      _testWidgets('two short fitted sheets leave each other in place',
          (tester) async {
        final navigator = await _pumpHome(tester);
        navigator.push(_glass(_short(_behind, _purple, height: 360))).ignore();
        await tester.pumpAndSettle();
        navigator.push(_glass(_short(_top, _orange))).ignore();
        await tester.pumpAndSettle();
        expect(_scaleOf(tester, _behind), 1);
        await _golden(tester, 'stacked two fitted short');
      });

      for (final (name, sizing, content) in [
        ('page', PresentationSizing.page, _short(_top, _orange)),
        (
          'fitted scroll view',
          PresentationSizing.automatic,
          _list(_top, _green)
        ),
      ]) {
        _testWidgets(
            'a $name sheet pushes back a page sheet as far as it has opened',
            (tester) async {
          final navigator = await _pumpHome(tester);
          navigator
              .push(
                _glass(_list(_behind, _blue), sizing: PresentationSizing.page),
              )
              .ignore();
          await tester.pumpAndSettle();
          navigator.push(_glass(content, sizing: sizing)).ignore();
          await tester.pump();

          for (final percent in [25, 50, 75]) {
            await tester.pump(const Duration(milliseconds: 250));
            expect(
              _scaleOf(tester, _behind),
              moreOrLessEquals(1 - (1 - _recededScale) * percent / 100),
              reason: 'at $percent %',
            );
            await _golden(tester, 'stacked $name over page open $percent');
          }

          await tester.pumpAndSettle();
          expect(_scaleOf(tester, _behind), moreOrLessEquals(_recededScale));
          await _golden(tester, 'stacked $name over page');
        });
      }

      _testWidgets(
          'a fitted sheet growing to full height pushes back the sheet '
          'behind as it reaches the top', (tester) async {
        final navigator = await _pumpHome(tester);
        navigator
            .push(
              _glass(_list(_behind, _blue), sizing: PresentationSizing.page),
            )
            .ignore();
        await tester.pumpAndSettle();

        final height = ValueNotifier<double>(240);
        addTearDown(height.dispose);
        navigator
            .push(
              _glass(
                ValueListenableBuilder(
                  valueListenable: height,
                  builder: (context, value, _) =>
                      _short(_top, _green, height: value),
                ),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
        expect(_scaleOf(tester, _behind), 1);
        await _golden(tester, 'stacked fitted growing short');

        final full = tester.getSize(find.byType(CupertinoApp)).height -
            _device.safeAreas.top -
            11;
        height.value = full - kSheetRecedeDistance / 2;
        await tester.pumpAndSettle();
        expect(
          _scaleOf(tester, _behind),
          moreOrLessEquals(1 - (1 - _recededScale) / 2),
          reason: 'halfway into the recede distance',
        );
        await _golden(tester, 'stacked fitted growing near top');

        height.value = full;
        await tester.pumpAndSettle();
        expect(_scaleOf(tester, _behind), moreOrLessEquals(_recededScale));
        await _golden(tester, 'stacked fitted growing full');
      });

      _testWidgets('the sheet behind follows the top sheet while dragging',
          (tester) async {
        final navigator = await _pumpHome(tester);
        navigator
            .push(
              _glass(_list(_behind, _blue), sizing: PresentationSizing.page),
            )
            .ignore();
        await tester.pumpAndSettle();
        navigator
            .push(_glass(_list(_top, _orange), sizing: PresentationSizing.page))
            .ignore();
        await tester.pumpAndSettle();

        final sheet = find.byType(SheetBackground).last;
        final sheetHeight = tester.getSize(sheet).height;
        final openTop = tester.getRect(sheet).top;
        final gesture = await _dragDown(
          tester,
          tester.getCenter(find.byKey(_top)),
          sheetHeight / 2,
        );
        final value = 1 - (tester.getRect(sheet).top - openTop) / sheetHeight;
        expect(value, closeTo(.5, .05));
        expect(
          _scaleOf(tester, _behind),
          moreOrLessEquals(1 - (1 - _recededScale) * value),
        );
        await gesture.up();
        await tester.pumpAndSettle();
      });

      _testWidgets('the sheet behind returns when the top sheet is popped',
          (tester) async {
        final navigator = await _pumpHome(tester);
        navigator
            .push(
              _glass(_list(_behind, _blue), sizing: PresentationSizing.page),
            )
            .ignore();
        await tester.pumpAndSettle();
        navigator.push(_glass(_list(_top, _green))).ignore();
        await tester.pumpAndSettle();
        expect(_scaleOf(tester, _behind), moreOrLessEquals(_recededScale));

        // Like the system back gesture or button.
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          _scaleOf(tester, _behind),
          moreOrLessEquals(1 - (1 - _recededScale) / 2),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(_top), findsNothing);
        expect(_scaleOf(tester, _behind), 1);
      });
    });

    group('with fitted content', () {
      _testWidgets('drags to dismiss', (tester) async {
        final navigator = await _pumpHome(tester);
        navigator
            .push(
              _glass(
                _short(_top, _purple),
                motion: const CupertinoMotion.smooth(snapToEnd: true),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();

        await tester.drag(find.byKey(_top), const Offset(0, 200));
        await tester.pumpAndSettle();
        expect(find.byKey(_top), findsNothing);
      });

      _testWidgets('moves with the finger', (tester) async {
        final navigator = await _pumpHome(tester);
        navigator.push(_glass(_short(_top, _purple))).ignore();
        await tester.pumpAndSettle();

        final before = tester.getRect(find.byKey(_top)).top;
        final gesture =
            await tester.startGesture(tester.getCenter(find.byKey(_top)));
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();
        // The sheet follows the whole movement, including the touch slop.
        expect(tester.getRect(find.byKey(_top)).top, before + 80);
        await gesture.up();
        await tester.pumpAndSettle();
      });

      _testWidgets('snaps to points relative to its own height',
          (tester) async {
        final navigator = await _pumpHome(tester);
        navigator
            .push(
              _glass(
                _short(_top, _purple, height: 400),
                snappingConfig: const SheetSnappingConfig([.5, 1]),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();

        final screen = tester.getSize(find.byType(CupertinoApp));
        expect(tester.getRect(find.byKey(_top)).top, screen.height - 200);

        await tester.flingFrom(
          tester.getTopLeft(find.byKey(_top)) + const Offset(100, 40),
          const Offset(0, -100),
          1000,
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(_top)).top, screen.height - 400);
      });

      _testWidgets('sits above the keyboard', (tester) async {
        tester.view.viewInsets = FakeViewPadding(
          bottom: 300 * tester.view.devicePixelRatio,
        );
        addTearDown(tester.view.resetViewInsets);
        final navigator = await _pumpHome(tester);
        navigator
            .push(
              _glass(
                _short(_top, _purple),
                originateAboveBottomViewInset: true,
              ),
            )
            .ignore();
        await tester.pumpAndSettle();

        final screen = tester.getSize(find.byType(CupertinoApp));
        final content = tester.getRect(find.byKey(_top));
        expect(content.bottom, screen.height - 300);
        expect(content.height, 240);
      });

      _testWidgets('hands scrolling over to the sheet at the top',
          (tester) async {
        final navigator = await _pumpHome(tester);
        navigator.push(_glass(_list(_top, _blue))).ignore();
        await tester.pumpAndSettle();

        final sheetTop = tester.getRect(find.byType(SheetBackground)).top;

        // Scrolling up scrolls the list, not the sheet.
        await tester.drag(find.byKey(_top), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(SheetBackground)).top, sheetTop);
        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .pixels,
          greaterThan(0),
        );

        // Scrolling back to the top and further only scrolls in this gesture.
        var gesture = await _dragDown(
          tester,
          tester.getCenter(find.byKey(_top)),
          500,
        );
        expect(tester.getRect(find.byType(SheetBackground)).top, sheetTop);
        await gesture.up();
        await tester.pumpAndSettle();

        // A new gesture at the top drags the sheet.
        gesture = await _dragDown(
          tester,
          tester.getCenter(find.byKey(_top)),
          200,
        );
        expect(
          tester.getRect(find.byType(SheetBackground)).top,
          greaterThan(sheetTop + 150),
        );
        await gesture.up();
        await tester.pumpAndSettle();
      });
    });
  });

  group('StupidSimpleCupertinoSheetRoute presentationSizing', () {
    test('defaults to page', () {
      expect(
        StupidSimpleCupertinoSheetRoute<void>(child: const SizedBox())
            .presentationSizing,
        PresentationSizing.page,
      );
    });

    for (final (name, sizing, content, scale) in [
      ('page', PresentationSizing.page, _short(_top, _purple), _recededScale),
      (
        'fitted short',
        PresentationSizing.automatic,
        _short(_top, _purple),
        1.0
      ),
      (
        'fitted scroll view',
        PresentationSizing.automatic,
        _list(_top, _blue),
        _recededScale,
      ),
    ]) {
      _testWidgets(
          'a $name sheet ${scale == 1 ? 'leaves' : 'pushes back'} the page '
          'behind', (tester) async {
        final navigator = await _pumpHome(tester);
        navigator
            .push(
              StupidSimpleCupertinoSheetRoute<void>(
                motion: _linear,
                presentationSizing: sizing,
                child: content,
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
        expect(_scaleOf(tester, _homeKey), moreOrLessEquals(scale));
        await _golden(tester, 'cupertino $name');
      });
    }

    for (final (name, content, scale) in [
      ('fitted short', _short(_top, _orange), 1.0),
      ('fitted scroll view', _list(_top, _green), _recededScale),
    ]) {
      _testWidgets(
          'a stacked $name sheet ${scale == 1 ? 'leaves' : 'pushes back'} '
          'the sheet behind', (tester) async {
        final navigator = await _pumpHome(tester);
        navigator
            .push(
              StupidSimpleCupertinoSheetRoute<void>(
                motion: _linear,
                child: _list(_behind, _blue),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
        navigator
            .push(
              StupidSimpleCupertinoSheetRoute<void>(
                motion: _linear,
                presentationSizing: PresentationSizing.automatic,
                child: content,
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
        expect(_scaleOf(tester, _behind), moreOrLessEquals(scale));
        await _golden(tester, 'cupertino stacked $name');
      });
    }
  });
}
