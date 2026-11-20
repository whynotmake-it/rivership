import 'package:coil/coil.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// An app's icon: laid out like Flutter's `Icon` (a box of the
/// [IconTheme]'s size, the glyph centered in it), with its own layer so a
/// test can read how visible it is.
class _AppIcon extends StatelessWidget {
  const _AppIcon(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final size = CoilIconSize.of(context);
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: RepaintBoundary(
          child: SizedBox.square(dimension: size),
        ),
      ),
    );
  }
}

/// An app's check that animates itself from its presence, recording what
/// it was given.
class _DrawnCheck extends StatelessWidget {
  const _DrawnCheck(this.seen);

  final List<double> seen;

  @override
  Widget build(BuildContext context) {
    final presence = CoilIconPresence.maybeOf(context);
    return SizedBox.square(
      dimension: CoilIconSize.of(context),
      child: RepaintBoundary(
        child: CustomPaint(painter: _Recorder(presence, seen)),
      ),
    );
  }
}

class _Recorder extends CustomPainter {
  _Recorder(this.presence, this.seen) : super(repaint: presence);

  final Animation<double>? presence;
  final List<double> seen;

  @override
  void paint(Canvas canvas, Size size) => seen.add(presence?.value ?? 1);

  @override
  bool shouldRepaint(_Recorder old) => old.presence != presence;
}

Widget _app(
  Widget child, {
  CoilIcons icons = const CoilIcons(),
  bool reduceMotion = false,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: CoilTheme(
      data: CoilThemeData(tier: CoilTier.pointer, icons: icons),
      // Overlay keeps its first entries: a new screen is a new overlay.
      child: Overlay(
        key: ValueKey(child.runtimeType),
        initialEntries: [
          OverlayEntry(builder: (_) => Center(child: child)),
        ],
      ),
    ),
  ),
);

/// How visible the icon at [finder] is: its layer's opacity times every
/// opacity above it.
double _shown(WidgetTester tester, Finder finder) {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.descendant(of: finder, matching: find.byType(RepaintBoundary)).first,
  );
  var opacity = 1.0;
  for (Layer? layer = boundary.debugLayer; layer != null;) {
    if (layer is OpacityLayer) opacity *= (layer.alpha ?? 255) / 255;
    layer = layer.parent;
  }
  return opacity;
}

Finder _within(String label, Finder matching) => find.descendant(
  of: find.bySemanticsLabel(label),
  matching: matching,
);

void main() {
  testWidgets(
    "an app's icon set replaces coil's glyphs wherever they show, in the "
    "same place, while a component's slot still wins",
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      addTearDown(tester.view.reset);
      Widget screen() => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Places that have no slot of their own.
            SizedBox(
              width: 300,
              child: CoilCalendar(
                selected: DateTime(2026, 11, 19),
                onSelected: (_) {},
              ),
            ),
            const CoilSheetCloseButton(),
            const CoilCheckbox(value: true, onChanged: null),
            // A slot passed to one component.
            SizedBox(
              width: 300,
              child: CoilBanner(
                title: const Text('Update ready'),
                onDismissRequested: () {},
                dismissIcon: const _AppIcon('slot'),
              ),
            ),
            // A role the app leaves to coil.
            const SizedBox(
              width: 300,
              child: CoilField(error: Text('Required'), child: CoilInput()),
            ),
          ],
        ),
      );

      // Where coil draws its own glyphs.
      await tester.pumpWidget(_app(screen()));
      Rect glyphIn(String label) =>
          tester.getRect(_within(label, find.byType(CoilDrawnGlyph)));
      final previous = glyphIn('Previous month');
      final next = glyphIn('Next month');
      final close = glyphIn('Close');

      await tester.pumpWidget(
        _app(
          screen(),
          icons: const CoilIcons(
            chevronStart: _AppIcon('start'),
            chevronEnd: _AppIcon('end'),
            close: _AppIcon('close'),
            check: _AppIcon('check'),
          ),
        ),
      );
      Rect appIconIn(String label) => tester.getRect(
        _within(label, find.byType(_AppIcon)),
      );
      expect(appIconIn('Previous month'), previous);
      expect(appIconIn('Next month'), next);
      expect(appIconIn('Close'), close);
      expect(
        find.descendant(
          of: find.byType(CoilCheckbox),
          matching: find.byType(_AppIcon),
        ),
        findsOneWidget,
      );
      // No drawn glyph is left where the app named a role.
      for (final label in ['Previous month', 'Next month', 'Close']) {
        expect(_within(label, find.byType(CoilDrawnGlyph)), findsNothing);
      }

      // The banner's own slot wins over the app's close icon.
      final dismiss = find.bySemanticsLabel('Dismiss');
      expect(
        find.descendant(of: dismiss, matching: find.byType(_AppIcon)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<_AppIcon>(
              find.descendant(of: dismiss, matching: find.byType(_AppIcon)),
            )
            .name,
        'slot',
      );
      // The field's alert, which the app didn't name, is still coil's.
      expect(
        find.descendant(
          of: find.byType(CoilField),
          matching: find.byType(CoilDrawnGlyph),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(CoilField),
          matching: find.byType(_AppIcon),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'an icon that reads its presence animates itself and a plain one fades, '
    'through a real check and copy; under reduced motion both land at once',
    (tester) async {
      // The clipboard accepts every copy.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      Future<void> run({required bool reduceMotion}) async {
        final seen = <double>[];
        var checked = false;
        Future<void> show(Widget child) => tester.pumpWidget(
          _app(
            reduceMotion: reduceMotion,
            icons: CoilIcons(
              check: _DrawnCheck(seen),
              copy: const _AppIcon('copy'),
            ),
            child,
          ),
        );
        await show(
          StatefulBuilder(
            builder: (context, setState) => CoilCheckbox(
              value: checked,
              onChanged: (v) => setState(() => checked = v!),
            ),
          ),
        );
        final checkbox = find.byType(CoilCheckbox);
        final copy = find.byType(CoilInputCopy);
        Finder check(Finder within) =>
            find.descendant(of: within, matching: find.byType(_DrawnCheck));
        final copyIcon = find.descendant(
          of: copy,
          matching: find.byType(_AppIcon),
        );

        // Check the checkbox: the app's check draws itself in from its
        // presence, with no fade on top.
        await tester.tap(checkbox);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        if (reduceMotion) {
          expect(seen.last, 1);
        } else {
          expect(seen.last, inExclusiveRange(0, 1));
          expect(_shown(tester, check(checkbox)), 1);
        }
        await tester.pumpAndSettle();
        expect(seen.last, 1);
        expect(_shown(tester, check(checkbox)), 1);

        // Copy: the plain copy icon fades out while the app's check comes
        // in, drawing itself.
        await show(
          const SizedBox(width: 240, child: CoilInputCopy(value: 'sk-123')),
        );
        await tester.pumpAndSettle();
        seen.clear();
        await tester.tap(copy);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        if (reduceMotion) {
          expect(copyIcon, findsNothing);
          expect(seen.last, 1);
        } else {
          expect(_shown(tester, copyIcon), inExclusiveRange(0, 1));
          expect(seen.last, inExclusiveRange(0, 1));
          expect(_shown(tester, check(copy)), 1);
        }
        await tester.pumpAndSettle();
        expect(copyIcon, findsNothing);
        expect(seen.last, 1);

        // The result's hold ends: the plain copy icon fades back in.
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 30));
        if (reduceMotion) {
          expect(_shown(tester, copyIcon), 1);
          expect(check(copy), findsNothing);
        } else {
          expect(_shown(tester, copyIcon), inExclusiveRange(0, 1));
        }
        await tester.pumpAndSettle();
        expect(_shown(tester, copyIcon), 1);
        expect(check(copy), findsNothing);
      }

      await run(reduceMotion: false);
      await run(reduceMotion: true);
    },
  );
}
