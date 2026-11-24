import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nested corners share a center: a container's radius is the drawn radius
/// of the control in its corner plus the inset between them (DESIGN.md §5).

const _shapes = {'rounded': CoilShape.rounded, 'pill': CoilShape.pill};

Widget _app({
  required CoilShape shape,
  required CoilTier tier,
  required Widget home,
}) {
  final theme = CoilThemeData.light.copyWith(
    typography: CoilTypography.allo(),
    shape: shape,
  );
  return WidgetsApp(
    color: theme.colors.brand,
    debugShowCheckedModeBanner: false,
    builder: (context, navigator) => CoilAdaptiveScope(
      tier: tier,
      child: CoilTheme(
        data: theme,
        child: ColoredBox(color: theme.colors.background, child: navigator),
      ),
    ),
    onGenerateRoute: (settings) => PageRouteBuilder<void>(
      settings: settings,
      pageBuilder: (context, _, _) => Center(
        child: SizedBox(width: 360, child: home),
      ),
    ),
  );
}

void _screen(WidgetTester tester, CoilTier tier) {
  tester.view
    ..devicePixelRatio = 2
    ..physicalSize =
        (tier == CoilTier.pointer
            ? const Size(800, 600)
            : const Size(390, 844)) *
        2;
  addTearDown(tester.view.reset);
}

/// The radius a superellipse of [size] draws for [radius].
double _drawn(double radius, Size size) =>
    math.min(radius, size.shortestSide / 2);

double _radiusOf(Decoration decoration) {
  final shape = (decoration as ShapeDecoration).shape;
  return ((shape as RoundedSuperellipseBorder).borderRadius as BorderRadius)
      .topLeft
      .x;
}

/// The first superellipse-decorated box under [of].
Finder _shapedBox(Finder of) => find
    .descendant(
      of: of,
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is ShapeDecoration &&
            (w.decoration as ShapeDecoration).shape
                is RoundedSuperellipseBorder,
      ),
    )
    .first;

/// The visual square of an icon button (inside its touch hit box).
Finder _iconVisual(Finder button, double extent) => find
    .descendant(
      of: button,
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == extent && w.height == extent,
      ),
    )
    .first;

CoilMetrics _compact(CoilTier tier) =>
    CoilThemeData.light.metrics.resolve(tier, CoilSize.compact);

void main() {
  group('CoilRadii.concentric', () {
    test('adds the inset to the drawn inner radius', () {
      const rounded = CoilRadii(item: 8, container: 12, focusRing: 10);
      expect(rounded.concentric(8, 4), 12);
      expect(rounded.concentric(8, 8, innerExtent: 28), 16);
      const pill = CoilRadii(item: 20, container: 24, focusRing: 22);
      // A 28 px button at radius 20 draws 14.
      expect(pill.concentric(20, 8, innerExtent: 28), 22);
      expect(pill.concentric(20, 4, innerExtent: 36), 22);
      expect(pill.concentric(20, 4, innerExtent: 44), 24);
    });

    test('a family that nests square keeps its container radius', () {
      expect(CoilShape.sharp.pointer.concentric(1, 8), 1);
    });

    test('nested undoes it', () {
      const pill = CoilRadii(item: 20, container: 24, focusRing: 22);
      final outer = pill.concentric(14, 8);
      expect(CoilShape.nested(outer, 8), 14);
    });
  });

  group('CoilInputMessage corners are concentric with its buttons', () {
    for (final MapEntry(key: name, value: shape) in _shapes.entries) {
      for (final tier in CoilTier.values) {
        for (final lines in [1, 4]) {
          testWidgets('$name, ${tier.name}, $lines line(s)', (tester) async {
            _screen(tester, tier);
            await tester.pumpWidget(
              _app(
                shape: shape,
                tier: tier,
                home: CoilInputMessage(
                  onSend: (_) {},
                  controller: TextEditingController(
                    text: List.filled(lines, 'Draft').join('\n'),
                  ),
                  leading: CoilButton.icon(
                    variant: CoilButtonVariant.ghost,
                    size: CoilSize.compact,
                    semanticLabel: 'Attach',
                    onPressed: () {},
                    icon: const CoilDrawnGlyph(CoilGlyph.copy),
                  ),
                ),
              ),
            );
            final composer = _shapedBox(find.byType(CoilInputMessage));
            final outer = tester.getRect(composer);
            final radius = _radiusOf(
              tester.widget<DecoratedBox>(composer).decoration,
            );
            final extent = _compact(tier).controlHeight;
            final send = tester.getRect(
              _iconVisual(find.byType(CoilButton).last, extent),
            );
            final attach = tester.getRect(
              _iconVisual(find.byType(CoilButton).first, extent),
            );
            final inner = _drawn(shape.radii(tier).item, send.size);

            final insetX = outer.right - send.right;
            final insetY = outer.bottom - send.bottom;
            expect(insetX, closeTo(insetY, 0.5));
            expect(radius, closeTo(inner + insetX, 0.5));
            // The attach button shares the other bottom corner.
            expect(attach.left - outer.left, closeTo(insetX, 0.5));
            // A tall draft keeps the concentric corner, not a pill's.
            expect(_drawn(radius, outer.size), closeTo(radius, 0.5));
            if (lines > 1) expect(outer.height, greaterThan(4 * 20));
          });
        }
      }
    }

    testWidgets('attachment tiles nest in the top corners', (tester) async {
      _screen(tester, CoilTier.pointer);
      await tester.pumpWidget(
        _app(
          shape: CoilShape.pill,
          tier: CoilTier.pointer,
          home: CoilInputMessage(
            onSend: (_) {},
            attachments: const CoilFileThumbnail(
              name: 'brief.pdf',
              dimension: 48,
            ),
          ),
        ),
      );
      final composer = _shapedBox(find.byType(CoilInputMessage));
      final outer = tester.getRect(composer);
      final radius = _radiusOf(
        tester.widget<DecoratedBox>(composer).decoration,
      );
      final tileBox = _shapedBox(find.byType(CoilFileThumbnail));
      final tile = tester.getRect(tileBox);
      final tileRadius = _radiusOf(
        tester.widget<DecoratedBox>(tileBox).decoration,
      );
      expect(tile.top - outer.top, tile.left - outer.left);
      expect(radius, closeTo(tileRadius + tile.left - outer.left, 0.5));
    });

    testWidgets('sharp stays square', (tester) async {
      _screen(tester, CoilTier.pointer);
      await tester.pumpWidget(
        _app(
          shape: CoilShape.sharp,
          tier: CoilTier.pointer,
          home: CoilInputMessage(onSend: (_) {}),
        ),
      );
      final composer = _shapedBox(find.byType(CoilInputMessage));
      expect(_radiusOf(tester.widget<DecoratedBox>(composer).decoration), 1);
    });
  });

  group('popovers are concentric with their rows', () {
    for (final MapEntry(key: name, value: shape) in _shapes.entries) {
      for (final tier in CoilTier.values) {
        testWidgets('dropdown, $name, ${tier.name}', (tester) async {
          _screen(tester, tier);
          await tester.pumpWidget(
            _app(
              shape: shape,
              tier: tier,
              home: CoilDropdown(
                presentation: CoilPresentation.popover,
                entries: [
                  CoilAction(label: const Text('Rename'), onPressed: () {}),
                  CoilAction(label: const Text('Move'), onPressed: () {}),
                ],
                builder: (context, menu) => CoilButton(
                  onPressed: menu.open,
                  child: const Text('Actions'),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Actions'));
          await tester.pumpAndSettle();
          final surface = find
              .descendant(
                of: find.byType(CoilPopoverSurface),
                matching: find.byType(CoilSurface),
              )
              .first;
          final outer = tester.getRect(surface);
          final radius =
              (tester.widget<CoilSurface>(surface).borderRadius!
                      as BorderRadius)
                  .topLeft
                  .x;
          final metrics = CoilThemeData.light.metrics.resolve(
            tier,
            CoilSize.regular,
          );
          final row = tester.getRect(
            find
                .ancestor(
                  of: find.text('Rename'),
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is ConstrainedBox &&
                        w.constraints.minHeight == metrics.controlHeight,
                  ),
                )
                .first,
          );
          final inset = row.top - outer.top;
          final inner = _drawn(shape.radii(tier).item, row.size);
          expect(radius, closeTo(inner + inset, 0.5));
        });
      }
    }
  });

  group('corner buttons nest in their cards', () {
    for (final MapEntry(key: name, value: shape) in _shapes.entries) {
      for (final tier in CoilTier.values) {
        testWidgets('card dismiss, $name, ${tier.name}', (tester) async {
          _screen(tester, tier);
          await tester.pumpWidget(
            _app(
              shape: shape,
              tier: tier,
              home: CoilCard(
                title: const Text('Title'),
                onDismissed: () {},
                child: const Text('A card with enough text to be tall.'),
              ),
            ),
          );
          final card = tester.getRect(
            find
                .descendant(
                  of: find.byType(CoilCard),
                  matching: find.byType(ClipRSuperellipse),
                )
                .first,
          );
          final outer = _drawn(shape.radii(tier).container, card.size);
          final button = find.byType(CoilButton);
          final extent = _compact(tier).controlHeight;
          final visual = tester.getRect(_iconVisual(button, extent));
          final inner = _drawn(
            tester.widget<CoilButton>(button).style!.radius!,
            visual.size,
          );
          final insetX = card.right - visual.right;
          expect(visual.top - card.top, closeTo(insetX, 0.5));
          expect(outer, closeTo(inner + insetX, 0.5));
        });

        testWidgets('queued message actions, $name, ${tier.name}', (
          tester,
        ) async {
          _screen(tester, tier);
          await tester.pumpWidget(
            _app(
              shape: shape,
              tier: tier,
              home: CoilQueuedStack(
                messages: const [
                  CoilQueuedMessage(
                    id: 'a',
                    child: Text('Ship it'),
                  ),
                ],
                onChanged: (_) {},
                onEdit: (_) {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          // A pointer shows the actions on hover.
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer();
          addTearDown(mouse.removePointer);
          await mouse.moveTo(tester.getCenter(find.text('Ship it')));
          await tester.pumpAndSettle();
          final card = tester.getRect(
            find
                .descendant(
                  of: find.byType(CoilQueuedStack),
                  matching: find.byType(CoilSurface),
                )
                .first,
          );
          final outer = _drawn(shape.radii(tier).container, card.size);
          final remove = find.byType(CoilButton).last;
          final extent = _compact(tier).controlHeight;
          final visual = tester.getRect(_iconVisual(remove, extent));
          final inner = _drawn(
            tester.widget<CoilButton>(remove).style!.radius!,
            visual.size,
          );
          final insetX = card.right - visual.right;
          expect(visual.top - card.top, closeTo(insetX, 0.5));
          expect(card.bottom - visual.bottom, closeTo(insetX, 0.5));
          expect(outer, closeTo(inner + insetX, 0.5));
        });

        testWidgets('ask-user-questions footer, $name, ${tier.name}', (
          tester,
        ) async {
          _screen(tester, tier);
          await tester.pumpWidget(
            _app(
              shape: shape,
              tier: tier,
              home: CoilAskUserQuestions<String>(
                questions: const [
                  CoilQuestion<String>.multiple(
                    id: 'platforms',
                    title: Text('Which platforms ship first?'),
                    options: [
                      CoilQuestionOption(value: 'ios', label: Text('iOS')),
                      CoilQuestionOption(value: 'web', label: Text('Web')),
                    ],
                  ),
                ],
                controller: CoilAskUserQuestionsController(
                  answers: {
                    'platforms': const CoilAnswer(values: {'ios'}),
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final cardBox = _shapedBox(find.byType(CoilAskUserQuestions<String>));
          final card = tester.getRect(cardBox);
          final radius = _radiusOf(
            tester.widget<DecoratedBox>(cardBox).decoration,
          );
          final extent = _compact(tier).controlHeight;
          final visual = tester.getRect(
            find
                .descendant(
                  of: find.byType(CoilButton).last,
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is ConstrainedBox &&
                        w.constraints.minHeight == extent,
                  ),
                )
                .first,
          );
          final inner = _drawn(shape.radii(tier).item, visual.size);
          final insetX = card.right - visual.right;
          expect(card.bottom - visual.bottom, closeTo(insetX, 0.5));
          expect(radius, closeTo(inner + insetX, 0.5));
        });
      }
    }
  });
}
