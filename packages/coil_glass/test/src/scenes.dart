// Demo scenes for the glass exploration. The screens use coil's own
// components only (glass button variants, CoilMaterialGroup, CoilDropdown);
// `themed(glass: true)` adds the CoilGlassScope that turns them into glass.

import 'dart:math' as math;

import 'package:coil/button.dart';
import 'package:coil/dropdown.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil_glass/coil_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons_400.dart';

/// Wraps a scene in coil's theme for [brightness] and an overlay for
/// popovers; [glass] installs the glass material.
Widget themed({
  required Brightness brightness,
  required Widget child,
  bool glass = true,
  CoilGlassMode? mode,
  bool reduceTransparency = false,
}) {
  final base = brightness == Brightness.dark
      ? CoilThemeData.dark
      : CoilThemeData.light;
  final app = Overlay(initialEntries: [OverlayEntry(builder: (_) => child)]);
  return Directionality(
    textDirection: TextDirection.ltr,
    child: CoilTheme(
      data: base.copyWith(typography: CoilTypography.allo()),
      child: glass
          ? CoilGlassScope(
              mode: mode,
              reduceTransparency: reduceTransparency,
              child: app,
            )
          : app,
    ),
  );
}

// ---------------------------------------------------------------------------
// Content: generated "photographs" so the glass has color to bend.

const _palettes = [
  [Color(0xFFFFB347), Color(0xFFFF6A3D), Color(0xFFB8336A), Color(0xFF3B1E54)],
  [Color(0xFF9BE7FF), Color(0xFF3D7BFF), Color(0xFF243B8A), Color(0xFF0D1B3E)],
  [Color(0xFFFFE29A), Color(0xFF7BD389), Color(0xFF2E8B57), Color(0xFF13432B)],
  [Color(0xFFFFC6E0), Color(0xFFFF7EB6), Color(0xFF8A4FFF), Color(0xFF2A1458)],
  [Color(0xFFFFF1C1), Color(0xFFFFB86B), Color(0xFFEF476F), Color(0xFF26547C)],
  [Color(0xFFC9F2FF), Color(0xFF6EC6CA), Color(0xFF08708A), Color(0xFF032B43)],
];

/// A generated landscape: a sky, a sun and layered hills.
class Photo extends StatelessWidget {
  const Photo(this.seed, {super.key, this.radius = 0});

  final int seed;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRSuperellipse(
    borderRadius: BorderRadius.circular(radius),
    child: CustomPaint(
      painter: _PhotoPainter(seed),
      child: const SizedBox.expand(),
    ),
  );
}

class _PhotoPainter extends CustomPainter {
  _PhotoPainter(this.seed);

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final p = _palettes[seed % _palettes.length];
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p[0], p[1], p[2]],
        ).createShader(rect),
    );
    final sun = Offset(
      size.width * (0.2 + 0.6 * random.nextDouble()),
      size.height * (0.25 + 0.2 * random.nextDouble()),
    );
    final sunRadius = size.shortestSide * (0.12 + 0.08 * random.nextDouble());
    canvas
      ..drawCircle(
        sun,
        sunRadius * 2.4,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFFFFF).withValues(alpha: 0.5),
              const Color(0x00FFFFFF),
            ],
          ).createShader(Rect.fromCircle(center: sun, radius: sunRadius * 2.4)),
      )
      ..drawCircle(sun, sunRadius, Paint()..color = const Color(0xFFFFF6E0));
    for (var layer = 0; layer < 3; layer++) {
      final base = size.height * (0.55 + 0.14 * layer);
      final path = Path()..moveTo(0, size.height);
      final amplitude = size.height * (0.10 - 0.02 * layer);
      final phase = random.nextDouble() * math.pi * 2;
      final frequency = 1.2 + random.nextDouble() * 1.6;
      for (var x = 0.0; x <= size.width; x += 4) {
        final t = x / size.width;
        path.lineTo(
          x,
          base -
              amplitude *
                  (math.sin(t * math.pi * frequency + phase) * 0.7 +
                      math.sin(t * math.pi * frequency * 2.3 + phase) * 0.3),
        );
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = Color.lerp(p[2], p[3], layer / 2)!,
      );
    }
  }

  @override
  bool shouldRepaint(_PhotoPainter old) => old.seed != seed;
}

const _places = [
  ('Lofoten', 'Norway · 214 photos'),
  ('Atacama', 'Chile · 96 photos'),
  ('Dolomites', 'Italy · 158 photos'),
  ('Kyoto', 'Japan · 302 photos'),
  ('Big Sur', 'California · 77 photos'),
  ('Faroe', 'Denmark · 121 photos'),
  ('Patagonia', 'Argentina · 64 photos'),
  ('Hokkaido', 'Japan · 189 photos'),
  ('Madeira', 'Portugal · 88 photos'),
  ('Iceland', 'Ring road · 410 photos'),
  ('Sahara', 'Morocco · 52 photos'),
  ('Tasmania', 'Australia · 133 photos'),
];

/// A photo album: a full-bleed cover under the top chrome, then a grid
/// that runs under the bottom chrome.
class Album extends StatelessWidget {
  const Album({required this.columns, required this.cover, super.key});

  final int columns;
  final double cover;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final padding = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: colors.background,
      child: ListView(
        padding: EdgeInsets.only(bottom: padding.bottom + 24),
        children: [
          SizedBox(height: cover + padding.top, child: const Photo(3)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aurora week', style: text.display),
                Text('Tromsø · 48 photos', style: text.muted.body),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (var i = 0; i < _places.length; i++)
                  Photo(i * 7 + 1, radius: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The screen: coil components only.

Widget _icon(IconData icon) => Icon(icon);

/// The album's menu: a plain `CoilDropdown` opened from a glass button.
class AlbumMenu extends StatelessWidget {
  const AlbumMenu({required this.controller, super.key});

  final CoilPopupController controller;

  @override
  Widget build(BuildContext context) => CoilDropdown(
    controller: controller,
    presentation: CoilPresentation.popover,
    entries: [
      CoilAction(
        label: const Text('Share album'),
        leading: _icon(LucideIcons400.share),
        onPressed: () {},
      ),
      CoilAction(
        label: const Text('Add to favorites'),
        leading: _icon(LucideIcons400.heart),
        onPressed: () {},
      ),
      CoilAction(
        label: const Text('Slideshow'),
        leading: _icon(LucideIcons400.play),
        onPressed: () {},
      ),
      CoilAction(
        label: const Text('Show map'),
        leading: _icon(LucideIcons400.map),
        onPressed: () {},
      ),
      const CoilMenuSeparator(),
      CoilAction(
        label: const Text('Delete album'),
        leading: _icon(LucideIcons400.trash2),
        tone: CoilActionTone.destructive,
        onPressed: () {},
      ),
    ],
    builder: (context, menu) => CoilButton.icon(
      key: const ValueKey('more'),
      onPressed: menu.open,
      variant: CoilButtonVariant.glass,
      semanticLabel: 'More',
      icon: _icon(LucideIcons400.ellipsis),
    ),
  );
}

/// The album screen on a phone or a desktop.
class AlbumScreen extends StatelessWidget {
  const AlbumScreen({required this.menu, required this.desktop, super.key});

  final CoilPopupController menu;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    const gap = SizedBox(width: 6);
    CoilButton iconButton(IconData icon, String label) => CoilButton.icon(
      onPressed: () {},
      variant: CoilButtonVariant.glass,
      semanticLabel: label,
      icon: _icon(icon),
    );

    // Buttons 6 px apart sit within the blend distance: each cluster is
    // one piece of glass with a bead per button.
    final top = Row(
      children: [
        CoilMaterialGroup(
          child: Row(
            children: [
              iconButton(LucideIcons400.chevronLeft, 'Back'),
              if (desktop) ...[
                gap,
                iconButton(LucideIcons400.chevronRight, 'Forward'),
              ],
            ],
          ),
        ),
        const Spacer(),
        CoilMaterialGroup(
          child: Row(
            children: [
              iconButton(LucideIcons400.share, 'Share'),
              gap,
              iconButton(LucideIcons400.heart, 'Favorite'),
              gap,
              AlbumMenu(controller: menu),
            ],
          ),
        ),
      ],
    );
    final bottom = Row(
      children: [
        CoilMaterialGroup(
          child: CoilButton(
            onPressed: () {},
            variant: CoilButtonVariant.glass,
            leading: _icon(LucideIcons400.squareCheck),
            child: const Text('Select'),
          ),
        ),
        const Spacer(),
        CoilMaterialGroup(
          child: Row(
            children: [
              iconButton(LucideIcons400.search, 'Search'),
              gap,
              CoilButton(
                onPressed: () {},
                variant: CoilButtonVariant.glassProminent,
                leading: _icon(LucideIcons400.plus),
                child: const Text('Add photos'),
              ),
            ],
          ),
        ),
      ],
    );
    return CoilAdaptiveScope(
      tier: desktop ? CoilTier.pointer : CoilTier.touch,
      child: Stack(
        children: [
          Positioned.fill(
            child: Album(columns: desktop ? 6 : 3, cover: desktop ? 420 : 380),
          ),
          Positioned(
            top: padding.top + (desktop ? 16 : 6),
            left: 16,
            right: 16,
            child: top,
          ),
          Positioned(
            bottom: padding.bottom + (desktop ? 16 : 6),
            left: 16,
            right: 16,
            child: bottom,
          ),
        ],
      ),
    );
  }
}
