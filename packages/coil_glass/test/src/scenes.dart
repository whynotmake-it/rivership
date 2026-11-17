// Demo scenes for the glass exploration: content to put glass over, and
// one screen per variant on a phone and a desktop.

import 'dart:math' as math;

import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/input_message.dart';
import 'package:coil/primitives.dart';
import 'package:coil/scroll_area.dart';
import 'package:coil/tabs.dart';
import 'package:coil_glass/coil_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons_400.dart';

/// The variants under exploration.
enum Variant {
  /// Glass for navigation chrome only; flat platter selection.
  chrome,

  /// Chrome plus floating controls with a lens that morphs between items.
  controls,

  /// A chat composer and its queue as blended glass.
  composer,

  /// Flat chrome; glass only while the selection moves.
  transient,
}

/// Wraps a scene in coil's theme for [brightness] and [tier].
Widget themed({
  required Brightness brightness,
  required CoilTier tier,
  required Widget child,
  CoilGlassMode? mode,
  bool reduceTransparency = false,
}) {
  final base = brightness == Brightness.dark
      ? CoilThemeData.dark
      : CoilThemeData.light;
  return Directionality(
    textDirection: TextDirection.ltr,
    child: CoilTheme(
      data: base.copyWith(typography: CoilTypography.allo(), tier: tier),
      child: CoilGlassScope(
        mode: mode,
        reduceTransparency: reduceTransparency,
        child: child,
      ),
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
      final color = Color.lerp(p[2], p[3], layer / 2)!;
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_PhotoPainter old) => old.seed != seed;
}

class _Caption extends StatelessWidget {
  const _Caption(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.body.copyWith(fontWeight: FontWeight.w600)),
          Text(subtitle, style: text.muted.caption),
        ],
      ),
    );
  }
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

/// A scrolling photo library: the content layer the chrome floats over.
class Library extends StatelessWidget {
  const Library({
    required this.columns,
    super.key,
    this.top = 0,
    this.start = 0,
  });

  final int columns;
  final double top;

  /// Room for a sidebar floating over the leading edge.
  final double start;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final padding = MediaQuery.paddingOf(context);
    const gutter = 16.0;
    return ColoredBox(
      color: colors.background,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          gutter + start,
          padding.top + top,
          gutter,
          padding.bottom + 120,
        ),
        children: [
          Text('Library', style: text.display),
          Text('Trips from the last two years', style: text.muted.body),
          const SizedBox(height: 16),
          const AspectRatio(aspectRatio: 1.9, child: Photo(3, radius: 20)),
          const _Caption('Aurora week', 'Tromsø · Featured'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
            children: [
              for (final (i, place) in _places.indexed)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: Photo(i * 7 + 1, radius: 14)),
                    _Caption(place.$1, place.$2),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chrome pieces.

Widget _icon(IconData icon) => Icon(icon);

/// A round glass icon button, as in Apple's toolbars.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton(
    this.icon, {
    super.key,
    this.size = 44,
    this.variant,
  });

  final IconData icon;
  final double size;
  final CoilGlassVariant? variant;

  @override
  Widget build(BuildContext context) => CoilGlass(
    shape: CoilGlassShape.circle,
    variant: variant,
    response: CoilGlassResponse.stretch,
    child: SizedBox.square(
      dimension: size,
      child: Center(
        child: IconTheme.merge(
          data: IconThemeData(size: size * 0.42),
          child: _icon(icon),
        ),
      ),
    ),
  );
}

/// A pill of icon buttons sharing one piece of glass.
class GlassButtonPill extends StatelessWidget {
  const GlassButtonPill(this.icons, {super.key, this.height = 44});

  final List<IconData> icons;
  final double height;

  @override
  Widget build(BuildContext context) => CoilGlass(
    shape: CoilGlassShape.pill,
    child: SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final icon in icons)
              SizedBox(
                width: height - 4,
                child: Center(
                  child: IconTheme.merge(
                    data: IconThemeData(size: height * 0.42),
                    child: _icon(icon),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// A glass menu: coil's action list on a container-radius panel.
class GlassMenu extends StatelessWidget {
  const GlassMenu({super.key, this.width = 220});

  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final scroll = CoilScrollAreaStyle.fallback(theme, metrics);
    // Its own, denser layer: rows of text need more frost than a bar.
    return CoilGlassLayer(
      style: CoilGlassStyle.dense,
      child: CoilGlass(
        radius: CoilTheme.radiiOf(context).item + metrics.popupInset,
        child: SizedBox(
          width: width,
          child: CoilActionList(
            metrics: metrics,
            scrollbar: scroll.scrollbarLook,
            onClose: (_) {},
            surface: const Color(0x00000000),
            highlight: CoilOnGlass.platterOf(theme.colors),
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
              const CoilMenuSeparator(),
              CoilAction(
                label: const Text('Delete album'),
                leading: _icon(LucideIcons400.trash2),
                tone: CoilActionTone.destructive,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const tabs = [
  CoilGlassTab(
    value: 0,
    label: Text('Library'),
    icon: Icon(LucideIcons400.images),
  ),
  CoilGlassTab(
    value: 1,
    label: Text('For You'),
    icon: Icon(LucideIcons400.heart),
  ),
  CoilGlassTab(
    value: 2,
    label: Text('Albums'),
    icon: Icon(LucideIcons400.album),
  ),
  CoilGlassTab(value: 3, label: Text('Map'), icon: Icon(LucideIcons400.map)),
];

const segments = [
  CoilGlassTab(value: 0, label: Text('Years')),
  CoilGlassTab(value: 1, label: Text('Months')),
  CoilGlassTab(value: 2, label: Text('Days')),
  CoilGlassTab(value: 3, label: Text('All')),
];

/// A stateful host so tests can change the selection.
class TabHost extends StatefulWidget {
  const TabHost({required this.builder, super.key, this.initial = 0});

  final int initial;
  final Widget Function(int value, ValueChanged<int> onChanged) builder;

  @override
  State<TabHost> createState() => _TabHostState();
}

class _TabHostState extends State<TabHost> {
  late int _value = widget.initial;

  @override
  Widget build(BuildContext context) =>
      widget.builder(_value, (v) => setState(() => _value = v));
}

// ---------------------------------------------------------------------------
// Phone screens.

/// A phone screen of [variant]. [menu] opens the glass menu.
class PhoneScene extends StatelessWidget {
  const PhoneScene(this.variant, {super.key, this.menu = false});

  final Variant variant;
  final bool menu;

  @override
  Widget build(BuildContext context) {
    if (variant == Variant.composer) return const _PhoneComposer();
    final padding = MediaQuery.paddingOf(context);
    final controls = variant == Variant.controls;
    final transient = variant == Variant.transient;
    return CoilAdaptiveScope(
      tier: CoilTier.touch,
      child: CoilGlassBackdrop(
        child: Stack(
          children: [
            Positioned.fill(
              child: Library(columns: 2, top: controls ? 112 : 56),
            ),
            // Top: the navigation layer. One backdrop pass for everything up
            // here, and the menu grows out of the button pill it belongs to.
            Positioned(
              top: padding.top + 4,
              left: 16,
              right: 16,
              child: CoilGlassLayer(
                child: CoilGlassGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (transient)
                            const _FlatIconButton(LucideIcons400.chevronLeft)
                          else
                            const GlassIconButton(LucideIcons400.chevronLeft),
                          const Spacer(),
                          if (transient)
                            const _FlatIconButton(LucideIcons400.ellipsis)
                          else
                            const GlassButtonPill([
                              LucideIcons400.share,
                              LucideIcons400.ellipsis,
                            ]),
                        ],
                      ),
                      if (menu) ...[
                        const SizedBox(height: 8),
                        const Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: GlassMenu(),
                        ),
                      ],
                      if (controls) ...[
                        const SizedBox(height: 12),
                        TabHost(
                          initial: 1,
                          builder: (value, onChanged) => CoilGlassTabBar<int>(
                            key: const ValueKey('segments'),
                            tabs: segments,
                            value: value,
                            onChanged: onChanged,
                            layout: CoilGlassTabLayout.inline,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Bottom: the tab bar and its neighbors, one layer, one group.
            Positioned(
              left: 16,
              right: 16,
              bottom: padding.bottom + 4,
              child: CoilGlassLayer(
                child: CoilGlassGroup(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TabHost(
                          builder: (value, onChanged) => CoilGlassTabBar<int>(
                            key: const ValueKey('tabs'),
                            tabs: tabs,
                            value: value,
                            onChanged: onChanged,
                            chrome: transient
                                ? CoilGlassTabChrome.flat
                                : CoilGlassTabChrome.glass,
                            indicator: variant == Variant.chrome
                                ? CoilGlassIndicator.platter
                                : CoilGlassIndicator.lens,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (transient)
                        const _FlatIconButton(LucideIcons400.search, size: 62)
                      else if (controls)
                        const GlassIconButton(
                          LucideIcons400.plus,
                          size: 62,
                          variant: CoilGlassVariant.tinted,
                        )
                      else
                        const GlassIconButton(LucideIcons400.search, size: 62),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlatIconButton extends StatelessWidget {
  const _FlatIconButton(this.icon, {this.size = 44});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => CoilSurface(
    offset: CoilSurface.popoverOffset,
    shadowLevel: 3,
    borderRadius: BorderRadius.circular(size),
    child: SizedBox.square(
      dimension: size,
      child: Center(
        child: Icon(
          icon,
          size: size * 0.42,
          color: CoilTheme.of(context).colors.foreground,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Composer.

/// A chat over a photo wallpaper, with the composer and its queue in glass.
class _PhoneComposer extends StatelessWidget {
  const _PhoneComposer();

  @override
  Widget build(BuildContext context) => const CoilAdaptiveScope(
    tier: CoilTier.touch,
    child: ComposerScene(maxWidth: double.infinity),
  );
}

/// The composer variant at any width.
class ComposerScene extends StatelessWidget {
  const ComposerScene({required this.maxWidth, super.key});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final colors = CoilTheme.of(context).colors;
    return ColoredBox(
      color: colors.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  reverse: true,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    padding.top + 16,
                    16,
                    padding.bottom + 110,
                  ),
                  children: const [
                    _Bubble(
                      mine: false,
                      text:
                          'Here are the three I liked best. The second one '
                          'has the light you were after.',
                      photos: [11, 4, 9],
                    ),
                    _Bubble(
                      mine: true,
                      text: 'Can you pick a cover for the Lofoten album?',
                    ),
                    _Bubble(
                      mine: false,
                      text:
                          'Done. I grouped them by day and kept the '
                          'originals.',
                      photos: [2, 8],
                    ),
                    _Bubble(
                      mine: true,
                      text: 'Sort the trip photos by day, please.',
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: padding.bottom + 8,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: const GlassComposer(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.mine, required this.text, this.photos});

  final bool mine;
  final String text;
  final List<int>? photos;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final photos = this.photos;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        spacing: 8,
        children: [
          if (photos != null)
            SizedBox(
              height: 150,
              child: Row(
                spacing: 6,
                children: [
                  for (final seed in photos)
                    Expanded(child: Photo(seed, radius: 14)),
                ],
              ),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: mine ? colors.muted : null,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: mine ? 14 : 2,
                  vertical: mine ? 10 : 0,
                ),
                child: Text(text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The composer and two queued messages, grouped so the queue melts into
/// the composer like drops about to join it.
class GlassComposer extends StatelessWidget {
  const GlassComposer({super.key});

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    Widget queued(String message) => CoilGlass(
      shape: CoilGlassShape.pill,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
        child: Row(
          spacing: 8,
          children: [
            Icon(LucideIcons400.clock, size: 14, color: text.muted.body.color),
            Expanded(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.caption,
              ),
            ),
            Icon(LucideIcons400.x, size: 14, color: text.muted.body.color),
          ],
        ),
      ),
    );
    return CoilGlassLayer(
      child: CoilGlassGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: queued('Then export the favorites as a slideshow'),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: queued('And make a shared link for Mia'),
            ),
            const SizedBox(height: 6),
            CoilGlass(
              radius: 24,
              child: CoilInputMessage(
                onSend: (_) {},
                status: CoilMessageStatus.streaming,
                onStop: () {},
                onQueue: (_) {},
                leading: CoilButton.icon(
                  onPressed: () {},
                  variant: CoilButtonVariant.ghost,
                  semanticLabel: 'Attach',
                  icon: const Icon(LucideIcons400.plus),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop screens.

/// A desktop window of [variant].
class DesktopScene extends StatelessWidget {
  const DesktopScene(this.variant, {super.key, this.menu = false});

  final Variant variant;
  final bool menu;

  @override
  Widget build(BuildContext context) {
    if (variant == Variant.composer) {
      return const CoilAdaptiveScope(
        tier: CoilTier.pointer,
        child: ComposerScene(maxWidth: 720),
      );
    }
    final transient = variant == Variant.transient;
    final controls = variant == Variant.controls;
    return CoilAdaptiveScope(
      tier: CoilTier.pointer,
      child: CoilGlassBackdrop(
        child: Stack(
          children: [
            const Positioned.fill(
              child: Library(columns: 4, top: 72, start: 260),
            ),
            // The sidebar floats over the content's edge, inset, with the
            // window's corner radius minus the inset.
            Positioned(
              top: 12,
              bottom: 12,
              left: 12,
              width: 240,
              child: CoilGlassLayer(
                child: transient
                    ? const CoilSurface(
                        offset: CoilSurface.popoverOffset,
                        child: _SidebarContent(),
                      )
                    : const CoilGlass(child: _SidebarContent()),
              ),
            ),
            // The toolbar: one layer, its pieces grouped.
            Positioned(
              top: 16,
              left: 272,
              right: 16,
              child: CoilGlassLayer(
                child: CoilGlassGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (transient || controls)
                            SizedBox(
                              width: 360,
                              child: TabHost(
                                initial: 1,
                                builder: (value, onChanged) =>
                                    CoilGlassTabBar<int>(
                                      key: const ValueKey('segments'),
                                      tabs: segments,
                                      value: value,
                                      onChanged: onChanged,
                                      layout: CoilGlassTabLayout.inline,
                                      chrome: transient
                                          ? CoilGlassTabChrome.flat
                                          : CoilGlassTabChrome.glass,
                                    ),
                              ),
                            )
                          else
                            const _ToolbarTabs(),
                          const Spacer(),
                          if (controls) ...[
                            // Close enough to melt: one chain of glass.
                            const GlassIconButton(
                              LucideIcons400.search,
                              size: 40,
                            ),
                            const SizedBox(width: 4),
                            const GlassIconButton(
                              LucideIcons400.share,
                              size: 40,
                            ),
                            const SizedBox(width: 4),
                            const GlassIconButton(
                              LucideIcons400.ellipsis,
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            const GlassIconButton(
                              LucideIcons400.plus,
                              size: 40,
                              variant: CoilGlassVariant.tinted,
                            ),
                          ] else if (transient) ...[
                            const _FlatIconButton(
                              LucideIcons400.search,
                              size: 40,
                            ),
                            const SizedBox(width: 8),
                            const _FlatIconButton(
                              LucideIcons400.ellipsis,
                              size: 40,
                            ),
                          ] else
                            const GlassButtonPill([
                              LucideIcons400.search,
                              LucideIcons400.share,
                              LucideIcons400.ellipsis,
                            ], height: 40),
                        ],
                      ),
                      if (menu) ...[
                        const SizedBox(height: 8),
                        const Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: GlassMenu(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// coil's own tabs, unchanged, on a glass pill: the on-glass theme turns
/// their pill into a platter.
class _ToolbarTabs extends StatelessWidget {
  const _ToolbarTabs();

  @override
  Widget build(BuildContext context) => CoilGlass(
    shape: CoilGlassShape.pill,
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: TabHost(
        initial: 1,
        builder: (value, onChanged) => CoilTabs<int>(
          tabs: const [
            CoilTab(value: 0, label: Text('Years')),
            CoilTab(value: 1, label: Text('Months')),
            CoilTab(value: 2, label: Text('Days')),
            CoilTab(value: 3, label: Text('All')),
          ],
          value: value,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

class _SidebarContent extends StatelessWidget {
  const _SidebarContent();

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final text = CoilTheme.textOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Text(
              'Photos',
              style: text.subtitle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          CoilActionList(
            metrics: metrics,
            scrollbar: CoilScrollAreaStyle.fallback(
              theme,
              metrics,
            ).scrollbarLook,
            onClose: (_) {},
            surface: const Color(0x00000000),
            highlight: CoilOnGlass.platterOf(theme.colors),
            entries: [
              CoilAction(
                label: const Text('Library'),
                leading: _icon(LucideIcons400.images),
                selected: true,
                onPressed: () {},
              ),
              CoilAction(
                label: const Text('For You'),
                leading: _icon(LucideIcons400.heart),
                onPressed: () {},
              ),
              CoilAction(
                label: const Text('Albums'),
                leading: _icon(LucideIcons400.album),
                onPressed: () {},
              ),
              CoilAction(
                label: const Text('Map'),
                leading: _icon(LucideIcons400.map),
                onPressed: () {},
              ),
              const CoilMenuLabel(Text('Trips')),
              for (final place in _places.take(5))
                CoilAction(
                  label: Text(place.$1),
                  leading: _icon(LucideIcons400.mapPin),
                  onPressed: () {},
                ),
            ],
          ),
        ],
      ),
    );
  }
}
