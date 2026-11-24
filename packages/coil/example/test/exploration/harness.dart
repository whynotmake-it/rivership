// Shared pieces of the accent exploration boards. Not part of the catalog.
import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A brand seed the boards compare.
class Seed {
  const Seed(this.name, this.color);

  final String name;
  final Color color;

  String get hex {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

const seeds = [
  Seed('blue', Color(0xFF6B97FF)), // coil's default brand
  Seed('orange', Color(0xFFF97316)),
  Seed('green', Color(0xFF16A34A)),
  Seed('purple', Color(0xFF8B5CF6)),
  Seed('yellow', Color(0xFFFACC15)),
  Seed('navy', Color(0xFF1E3A8A)),
];

final typography = CoilTypography.allo();

/// The theme for [seed] in [brightness], lit at [plasticity].
CoilThemeData themeFor(
  Seed seed,
  Brightness brightness, {
  CoilTier tier = CoilTier.pointer,
  double plasticity = 0.5,
}) => CoilThemeData(
  colors: CoilColors.fromSeed(brightness: brightness, brand: seed.color),
  typography: typography,
  tier: tier,
  plasticity: CoilPlasticity(amount: plasticity),
);

/// A page-colored panel with [theme], a caption and [child].
class Panel extends StatelessWidget {
  const Panel({
    required this.theme,
    required this.child,
    super.key,
    this.caption,
    this.padding = 24,
  });

  final CoilThemeData theme;
  final String? caption;
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => CoilTheme(
    data: theme,
    child: Builder(
      builder: (context) {
        final c = CoilTheme.of(context).colors;
        return ColoredBox(
          color: c.background,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caption case final caption?) ...[
                  Text(
                    caption,
                    style: typography.pointerCompact.caption.copyWith(
                      color: c.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                child,
              ],
            ),
          ),
        );
      },
    ),
  );
}

final _boardKey = GlobalKey();

/// Pumps [board], painted at 2x, on a [surface]-sized canvas, settles it
/// and returns a finder for its repaint boundary.
Future<Finder> pumpBoard(
  WidgetTester tester,
  Widget board, {
  Size surface = const Size(5200, 5200),
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = surface;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    WidgetsApp(
      color: const Color(0xFF6B97FF),
      debugShowCheckedModeBanner: false,
      builder: (context, _) => Overlay(
        key: UniqueKey(),
        initialEntries: [
          OverlayEntry(
            builder: (_) => Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: _boardKey,
                child: _Doubled(
                  child: KeyedSubtree(key: UniqueKey(), child: board),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  return find.byKey(_boardKey);
}

/// The touched-up mapping: [theme] with brand on the controls that mark a
/// choice or a value. Style overrides only; no component changes.
CoilThemeData withBrandTouches(CoilThemeData theme) {
  final colors = theme.colors;
  final dark = colors.brightness == Brightness.dark;
  final ink = colors.brandInk;
  // A translucent brand reads as a dark shade over a dark page, so a
  // yellow or lime leans warm there too (amber, not olive).
  final (:l, :c, :h) = CoilColorMix.toOklch(colors.brand);
  final base = dark
      ? CoilColorMix.oklch(math.max(l, 0.5), c, CoilColors.warmShade(h, 0.3))
      : colors.brand;
  final wash = base.withValues(alpha: dark ? 0.22 : 0.14);
  return theme
      .withComponentStyle(
        CoilSwitchStyle(
          track: WidgetStateProperty<Color?>.fromMap({
            WidgetState.selected: colors.brandFill,
          }),
        ),
      )
      .withComponentStyle(CoilCheckboxStyle(glyphColor: ink))
      .withComponentStyle(CoilRadioGroupStyle(dot: colors.brandFill))
      .withComponentStyle(
        CoilSliderStyle(fill: base.withValues(alpha: dark ? 0.3 : 0.2)),
      )
      .withComponentStyle(
        CoilTabsStyle(
          pill: wash,
          label: WidgetStateProperty<Color?>.fromMap({
            WidgetState.selected: ink,
            WidgetState.hovered: colors.foreground,
            WidgetState.any: colors.mutedForeground,
          }),
        ),
      )
      .withComponentStyle(
        CoilToggleGroupStyle(
          selection: wash,
          label: WidgetStateProperty<Color?>.fromMap({
            WidgetState.selected: ink,
            WidgetState.hovered | WidgetState.focused: colors.foreground,
            WidgetState.any: colors.mutedForeground,
          }),
        ),
      )
      .withComponentStyle(CoilInputStyle(cursorColor: ink));
}

/// Lays [child] out at its own size and paints it at twice that, so a
/// 1x capture comes out at 2x.
class _Doubled extends SingleChildRenderObjectWidget {
  const _Doubled({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderDoubled();
}

class _RenderDoubled extends RenderProxyBox {
  static final _scale = Matrix4.diagonal3Values(2, 2, 1);

  @override
  void performLayout() {
    child!.layout(constraints.loosen() / 2, parentUsesSize: true);
    size = constraints.constrain(child!.size * 2);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushTransform(needsCompositing, offset, _scale, super.paint);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_scale);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintTransform(
        transform: _scale,
        position: position,
        hitTest: (result, position) =>
            super.hitTestChildren(result, position: position),
      );
}
