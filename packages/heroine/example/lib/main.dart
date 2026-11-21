import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:flutter/cupertino.dart';
import 'package:heroine/heroine.dart';
import 'package:heroine_example/image_grid.dart';
import 'package:heroine_example/keyboard.dart';
import 'package:heroine_example/src/brand.dart';
import 'package:heroine_example/src/chrome.dart';
import 'package:heroine_example/src/icons.dart';
import 'package:heroine_example/zoom_transition.dart';

void main() => runApp(const HeroineExampleApp());

/// The example's routes, for an app that mounts them as a shell's children:
///
/// ```dart
/// NamedRouteDef.shell(
///   path: '/heroine',
///   name: 'Heroine',
///   children: heroineRoutesFor(onHome: () => router.navigate(home)),
/// )
/// ```
///
/// With [onHome], the brand at the top of the picker leads back to the app
/// around the example.
List<AutoRoute> heroineRoutesFor({VoidCallback? onHome}) => [
  NamedRouteDef(
    name: 'Heroine',
    path: '',
    type: RouteType.cupertino(),
    builder: (context, _) => HeroineExamplePicker(onHome: onHome),
  ),
  NamedRouteDef(
    name: ImageGridExample.name,
    path: ImageGridExample.path,
    type: RouteType.cupertino(),
    builder: (context, _) => const ImageGridExample(),
  ),
  NamedRouteDef(
    name: ZoomTransitionExample.name,
    path: ZoomTransitionExample.path,
    type: RouteType.cupertino(),
    builder: (context, _) => const ZoomTransitionExample(),
  ),
  NamedRouteDef(
    name: KeyboardCardExample.name,
    path: KeyboardCardExample.path,
    type: RouteType.cupertino(),
    builder: (context, _) => const KeyboardCardExample(),
  ),
];

/// The example's routes with an inert brand. See [heroineRoutesFor].
final heroineRoutes = heroineRoutesFor();

/// The routes as their own app, under a shell like the one that mounts them
/// in the gallery (root paths must start with a slash).
final router = RootStackRouter.build(
  routes: [
    NamedRouteDef.shell(
      name: 'Heroine example',
      path: '/',
      children: heroineRoutes,
    ),
  ],
);

class HeroineExampleApp extends StatelessWidget {
  const HeroineExampleApp({super.key});

  @override
  Widget build(BuildContext context) => CupertinoApp.router(
    debugShowCheckedModeBanner: false,
    routerConfig: router.config(
      navigatorObservers: () => [HeroController(), HeroineController()],
    ),
  );
}

/// The demos, one card each.
class HeroineExamplePicker extends StatelessWidget {
  const HeroineExamplePicker({super.key, this.onHome});

  /// Makes the brand a link back to the app around the example.
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    final gutter = DemoLayout.gutterOf(context);
    final padding = MediaQuery.paddingOf(context);
    return DemoPage(
      title: 'Heroine',
      showBack: false,
      brand: HeroineBrand(onHome: onHome),
      summary: 'Spring-based hero transitions that keep their velocity.',
      child: ListView(
        padding: EdgeInsetsDirectional.fromSTEB(
          gutter + padding.left,
          8,
          gutter + padding.right,
          gutter + padding.bottom,
        ),
        children: [
          // Start-aligned like the header and summary above it.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: DemoLayout.maxContentWidth,
              ),
              child: CoilCardGroup(
                layout: CoilCardGroupLayout.separated,
                children: [
                  _DemoCard(
                    glyph: Glyph.grid,
                    route: ImageGridExample.name,
                    title: 'Photo grid',
                    description:
                        'Open a photo, then drag it away. It flies back as '
                        'fast as you threw it.',
                  ),
                  _DemoCard(
                    glyph: Glyph.zoom,
                    route: ZoomTransitionExample.name,
                    title: 'Zoom transition',
                    description:
                        'The iOS zoom transition: a photo grows into its page '
                        'and shrinks back when you drag the page down.',
                  ),
                  _DemoCard(
                    glyph: Glyph.keyboard,
                    route: KeyboardCardExample.name,
                    title: 'Keyboard',
                    description:
                        'A caption field flies to the middle and follows its '
                        'target while the keyboard opens.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.glyph,
    required this.route,
    required this.title,
    required this.description,
  });

  final Glyph glyph;
  final String route;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => CoilCard(
    variant: CoilCardVariant.inline,
    icon: DemoIcon(glyph),
    title: Text(title),
    description: Text(description),
    onPressed: () => context.navigateTo(NamedRoute(route)),
  );
}
