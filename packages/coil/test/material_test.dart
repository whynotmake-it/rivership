import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what it is asked to build and wraps the surface in a marker.
class _RecordingMaterial extends CoilMaterial {
  final specs = <CoilSurfaceSpec>[];
  int groups = 0;

  @override
  Widget? surface(BuildContext context, CoilSurfaceSpec spec, Widget child) {
    specs.add(spec);
    return KeyedSubtree(key: ValueKey(spec.role), child: child);
  }

  @override
  Widget group(BuildContext context, Widget child) {
    groups++;
    return child;
  }
}

Widget _app(Widget child, {CoilMaterial? material}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(size: Size(800, 600)),
    child: CoilTheme(
      data: CoilThemeData.light,
      child: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (context) => CoilMaterialScope(
              material: material,
              child: Center(child: child),
            ),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  group('CoilMaterial', () {
    testWidgets('builds glass buttons, with their emphasis', (tester) async {
      final material = _RecordingMaterial();
      await tester.pumpWidget(
        _app(
          material: material,
          CoilMaterialGroup(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CoilButton(
                  onPressed: () {},
                  variant: CoilButtonVariant.glass,
                  child: const Text('Share'),
                ),
                CoilButton(
                  onPressed: () {},
                  variant: CoilButtonVariant.glassProminent,
                  child: const Text('New'),
                ),
                CoilButton(onPressed: () {}, child: const Text('Plain')),
              ],
            ),
          ),
        ),
      );
      expect(material.groups, 1);
      expect(
        material.specs.map((s) => (s.role, s.emphasis)).toSet(),
        {
          (CoilSurfaceRole.control, CoilSurfaceEmphasis.regular),
          (CoilSurfaceRole.control, CoilSurfaceEmphasis.prominent),
        },
      );
      // A capsule: radius = height / 2.
      final height = tester.getSize(find.byType(CoilButton).first).height;
      expect(material.specs.first.borderRadius.topLeft.x, height / 2);
    });

    testWidgets('without a material, glass is coil\'s raised surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CoilButton(
            onPressed: () {},
            variant: CoilButtonVariant.glass,
            child: const Text('Share'),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(CoilButton),
          matching: find.byType(CoilSurface),
        ),
        findsOneWidget,
      );
    });

    testWidgets('builds popover surfaces', (tester) async {
      final material = _RecordingMaterial();
      await tester.pumpWidget(
        _app(
          material: material,
          const CoilPopoverSurface(child: SizedBox(width: 100, height: 40)),
        ),
      );
      expect(material.specs.single.role, CoilSurfaceRole.popover);
      expect(find.byKey(const ValueKey(CoilSurfaceRole.popover)), findsOne);
      // The level scope stays, so what opens from the popover sits above.
      expect(find.byType(CoilSurface), findsOneWidget);
    });

    testWidgets('a material that declines leaves coil\'s surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          material: const _DecliningMaterial(),
          const CoilPopoverSurface(child: SizedBox(width: 100, height: 40)),
        ),
      );
      final surface = tester.widget<CoilSurface>(find.byType(CoilSurface));
      expect(surface.shadowLevel, 3);
    });
  });
}

class _DecliningMaterial extends CoilMaterial {
  const _DecliningMaterial();

  @override
  Widget? surface(BuildContext context, CoilSurfaceSpec spec, Widget child) =>
      null;
}
