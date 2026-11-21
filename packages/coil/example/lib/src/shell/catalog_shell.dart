import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:coil_example/src/shell/navigation.dart';
import 'package:coil_example/src/shell/phone_frame.dart';
import 'package:coil_example/src/shell/preview_settings.dart';
import 'package:coil_example/src/shell/settings.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Below this window width the catalog is on a phone (or in a phone-sized
/// window): no top bar and no device frame, just the catalog on the touch
/// tier, full screen.
const catalogPhoneBreakpoint = 600.0;

/// The catalog: its settings, the top bar with the desktop ↔ mobile toggle,
/// and the pages with their navigation, full window or inside a device
/// frame. Uses the settings of an enclosing [CatalogSettingsScope], or owns
/// a set when mounted inside another app.
class CatalogShell extends StatefulWidget {
  const CatalogShell({super.key, this.leading});

  /// The host app's way back when the catalog is mounted inside another
  /// app; null when it runs on its own. See [CatalogHostLink].
  final Widget? leading;

  @override
  State<CatalogShell> createState() => _CatalogShellState();
}

class _CatalogShellState extends State<CatalogShell> {
  CatalogSettings? _ownSettings;

  /// Keeps the pages (their navigator, scroll positions, open sidebar
  /// groups, typed text) alive as they move into and out of the frame.
  final _contentKey = GlobalKey(debugLabel: 'catalog content');
  final _chromeNavigator = GlobalKey<NavigatorState>(
    debugLabel: 'catalog chrome',
  );

  @override
  void dispose() {
    _ownSettings?.dispose();
    super.dispose();
  }

  Future<bool> _popChrome() async {
    final navigator = _chromeNavigator.currentState;
    if (navigator == null || !navigator.canPop()) return false;
    navigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final content = KeyedSubtree(
      key: _contentKey,
      child: AutoRouter(
        builder: (context, navigator) => CatalogNavigation(
          router: AutoRouter.of(context),
          child: navigator,
        ),
      ),
    );
    // The top bar's own overlays (the preview settings) open on a
    // navigator of their own, inside the settings' theme but outside the
    // device frame.
    Widget chrome = Navigator(
      key: _chromeNavigator,
      pages: [_ChromePage(child: CatalogFrame(content: content))],
      onDidRemovePage: (_) {},
    );
    if (Router.maybeOf(context)?.backButtonDispatcher != null) {
      chrome = BackButtonListener(
        onBackButtonPressed: _popChrome,
        child: chrome,
      );
    }
    final environment = CatalogEnvironment(
      child: CatalogHostLink(link: widget.leading, child: chrome),
    );
    if (CatalogSettingsScope.maybeOf(context) != null) return environment;
    return CatalogSettingsScope(
      settings: _ownSettings ??= CatalogSettings(),
      child: environment,
    );
  }
}

/// The one page of the chrome's navigator. Its route rebuilds with each
/// new page, so the frame below always shows the current [child].
class _ChromePage extends Page<void> {
  const _ChromePage({required this.child})
    : super(key: const ValueKey('catalog chrome'));

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => _ChromeRoute(this);
}

class _ChromeRoute extends PageRoute<void> {
  _ChromeRoute(_ChromePage page) : super(settings: page);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => (settings as _ChromePage).child;

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => Duration.zero;
}

/// The host app's link, such as a "Packages › coil" breadcrumb, when the
/// catalog is mounted inside another app. The top bar shows it at its
/// start; without a top bar, each page header does.
class CatalogHostLink extends InheritedWidget {
  const CatalogHostLink({required this.link, required super.child, super.key});

  final Widget? link;

  static Widget? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CatalogHostLink>()?.link;

  @override
  bool updateShouldNotify(CatalogHostLink oldWidget) => link != oldWidget.link;
}

/// Whether the catalog shows its top bar, which holds the preview
/// settings. Without it (a phone), each page header has the settings
/// button.
class CatalogChrome extends InheritedWidget {
  const CatalogChrome({
    required this.hasTopBar,
    required super.child,
    super.key,
  });

  final bool hasTopBar;

  static bool hasTopBarOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CatalogChrome>()?.hasTopBar ??
      false;

  @override
  bool updateShouldNotify(CatalogChrome oldWidget) =>
      hasTopBar != oldWidget.hasTopBar;
}

/// Lays the catalog out for the window: on a phone, [content] full screen
/// on the touch tier; otherwise the top bar over [content], full width or
/// framed as the device the settings pick.
class CatalogFrame extends StatelessWidget {
  const CatalogFrame({required this.content, super.key});

  /// The pages and their navigation.
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final settings = CatalogSettingsScope.of(context);
    if (MediaQuery.sizeOf(context).width < catalogPhoneBreakpoint) {
      return CatalogChrome(
        hasTopBar: false,
        child: CoilAdaptiveScope(
          tier: settings.tier.tier ?? CoilTier.touch,
          child: content,
        ),
      );
    }
    final framed = settings.viewport == CatalogViewport.mobile;
    return CatalogChrome(
      hasTopBar: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CatalogTopBar(),
          Expanded(
            child: framed
                ? DeviceStage(
                    device: settings.device,
                    orientation: settings.orientation,
                    child: content,
                  )
                // Desktop is the pointer tier, unless the settings pin one.
                : CoilAdaptiveScope(
                    tier: settings.tier.tier ?? CoilTier.pointer,
                    child: content,
                  ),
          ),
        ],
      ),
    );
  }
}

/// The bar above the catalog: the wordmark, the desktop ↔ mobile toggle,
/// the device picker and rotation while framed, the light/dark switch and
/// the preview settings.
class CatalogTopBar extends StatelessWidget {
  const CatalogTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = CatalogSettingsScope.of(context);
    final colors = CoilTheme.of(context).colors;
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 840;
    final wide = width >= 960;
    final framed = settings.viewport == CatalogViewport.mobile;
    final dark = CoilTheme.of(context).brightness == Brightness.dark;
    final gap = CoilTheme.metricsOf(context).gap;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
          child: Row(
            children: [
              // Wide, the toggle sits in the middle; narrower, the
              // wordmark gives way to the mark and the controls pack right.
              if (CatalogHostLink.of(context) case final link?)
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: link,
                  ),
                )
              else if (wide)
                Expanded(child: _Wordmark(showTagline: width >= 1280))
              else ...[
                const CoilMark(),
                const Spacer(),
              ],
              SizedBox(width: gap),
              CoilTabs<CatalogViewport>(
                value: settings.viewport,
                onChanged: (value) => settings.viewport = value,
                labels: narrow ? CoilTabLabels.selected : CoilTabLabels.always,
                tabs: [
                  for (final viewport in CatalogViewport.values)
                    CoilTab(
                      value: viewport,
                      label: Text(viewport.label),
                      icon: CatalogIcon(switch (viewport) {
                        CatalogViewport.desktop => Glyph.monitor,
                        CatalogViewport.mobile => Glyph.smartphone,
                      }),
                    ),
                ],
              ),
              SizedBox(width: gap),
              Expanded(
                flex: wide ? 1 : 0,
                child: Row(
                  mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (framed) ...[
                      if (wide)
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: _DeviceSelect(settings: settings),
                          ),
                        )
                      else
                        _DeviceMenu(settings: settings),
                      const SizedBox(width: 4),
                      CoilTooltip(
                        message: const Text('Rotate'),
                        side: CoilTooltipSide.bottom,
                        child: CoilButton.icon(
                          variant: CoilButtonVariant.ghost,
                          semanticLabel: 'Rotate device',
                          icon: const CatalogIcon(Glyph.rotate),
                          onPressed: () => settings.orientation =
                              settings.orientation == Orientation.portrait
                              ? Orientation.landscape
                              : Orientation.portrait,
                        ),
                      ),
                    ],
                    SizedBox(width: gap),
                    CoilTooltip(
                      message: Text(dark ? 'Light theme' : 'Dark theme'),
                      side: CoilTooltipSide.bottom,
                      child: CoilButton.icon(
                        variant: CoilButtonVariant.ghost,
                        semanticLabel: dark
                            ? 'Use light theme'
                            : 'Use dark theme',
                        icon: CatalogIcon(dark ? Glyph.sun : Glyph.moon),
                        onPressed: () => settings.themeMode = dark
                            ? CatalogThemeMode.light
                            : CatalogThemeMode.dark,
                      ),
                    ),
                    const CoilTooltip(
                      message: Text('Preview settings'),
                      side: CoilTooltipSide.bottom,
                      child: SettingsButton(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The framed device, picked from a select.
class _DeviceSelect extends StatelessWidget {
  const _DeviceSelect({required this.settings});

  final CatalogSettings settings;

  @override
  Widget build(BuildContext context) => CoilSelect<CatalogDevice>(
    value: settings.device,
    onChanged: (value) => settings.device = value,
    options: [
      for (final device in CatalogDevice.values)
        CoilOption(
          value: device,
          label: Text(device.label),
          searchText: device.label,
          icon: CatalogIcon(_glyphOf(device)),
        ),
    ],
  );
}

/// The framed device, picked from a menu behind an icon button, where the
/// bar has no room for a select.
class _DeviceMenu extends StatelessWidget {
  const _DeviceMenu({required this.settings});

  final CatalogSettings settings;

  @override
  Widget build(BuildContext context) => CoilDropdown(
    entries: [
      for (final device in CatalogDevice.values)
        CoilAction(
          label: Text(device.label),
          searchText: device.label,
          leading: CatalogIcon(_glyphOf(device)),
          selected: device == settings.device,
          mark: CoilActionMark.check,
          onPressed: () => settings.device = device,
        ),
    ],
    builder: (context, menu) => CoilButton.icon(
      variant: CoilButtonVariant.ghost,
      semanticLabel: 'Device: ${settings.device.label}',
      icon: CatalogIcon(_glyphOf(settings.device)),
      onPressed: menu.open,
    ),
  );
}

Glyph _glyphOf(CatalogDevice device) =>
    device == CatalogDevice.iPad ? Glyph.tablet : Glyph.smartphone;

/// "coil", with the tagline on wide windows.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.showTagline});

  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final colors = CoilTheme.of(context).colors;
    return Row(
      children: [
        const CoilMark(),
        const SizedBox(width: 8),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'coil',
                  style: text.subtitle.copyWith(fontWeight: text.emphasis),
                ),
                if (showTagline)
                  TextSpan(
                    text: '   Refined Flutter components on springs',
                    style: text.caption.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// coil's mark: a brand-colored superellipse with a coiled spring stroke.
class CoilMark extends StatelessWidget {
  const CoilMark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return Semantics(
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.brand,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(size * 0.3),
            ),
          ),
          child: const CustomPaint(painter: _CoilPainter()),
        ),
      ),
    );
  }
}

class _CoilPainter extends CustomPainter {
  const _CoilPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.width * 0.075;
    // A spring seen from the side: a prolate cycloid, three loops.
    final path = Path();
    const loops = 3;
    final w = size.width;
    final h = size.height;
    final left = w * 0.2;
    final span = w * 0.6;
    final radius = h * 0.2;
    final pitch = span / (loops * 2 * math.pi + 2.4);
    for (var i = 0; i <= 120; i++) {
      final t = -1.2 + (loops * 2 * math.pi + 2.4) * i / 120;
      final x = left + pitch * (t + 1.2) - radius * 0.9 * math.sin(t);
      final y = h / 2 + radius * math.cos(t);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CoilPainter oldDelegate) => false;
}

/// [child] inside [device]'s frame, on the touch tier and with the
/// device's platform, screen size, safe areas and pixel ratio, so it lays
/// out and behaves as it would on that device. The frame scales down to
/// fit, never up.
class DeviceStage extends StatelessWidget {
  const DeviceStage({
    required this.device,
    required this.orientation,
    required this.child,
    super.key,
  });

  final CatalogDevice device;
  final Orientation orientation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final screen = device.screenSizeIn(orientation);
    final platform = switch (device.platform) {
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.android => 'Android',
      final other => other.name,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: PhoneFrame(
                device: device,
                orientation: orientation,
                child: DeviceScreen(device: device, child: child),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${device.label} · $platform · touch tier · '
            '${screen.width.round()} × ${screen.height.round()}',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.muted.caption,
          ),
        ],
      ),
    );
  }
}

/// What a device's screen sets up for the catalog inside it: the touch
/// tier, the device's platform for coil's conventions and for scrolling,
/// and drags from any pointer, so a mouse scrolls and swipes like a finger.
class DeviceScreen extends StatelessWidget {
  const DeviceScreen({required this.device, required this.child, super.key});

  final CatalogDevice device;
  final Widget child;

  @override
  Widget build(BuildContext context) => CoilAdaptiveScope(
    tier: CoilTier.touch,
    platform: device.platform,
    child: ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        platform: device.platform,
        dragDevices: PointerDeviceKind.values.toSet(),
      ),
      child: Builder(
        builder: (context) => ColoredBox(
          color: CoilTheme.of(context).colors.background,
          child: child,
        ),
      ),
    ),
  );
}
