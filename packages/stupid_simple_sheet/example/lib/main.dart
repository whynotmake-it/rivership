import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_card.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';
import 'package:stupid_simple_sheet_example/widgets/section_header.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_logo.dart';
import 'advanced/custom_route_example.dart';
import 'advanced/dynamic_content_example.dart';
import 'advanced/share_sheet_example.dart';
import 'playground/playground_page.dart';
import 'presets/cupertino_sheet_preset.dart';
import 'presets/glass_sheet_preset.dart';
import 'recipes/basic_sheet.dart';
import 'recipes/content_sized.dart';
import 'recipes/content_sized_above_keyboard.dart';
import 'recipes/non_draggable.dart';
import 'recipes/programmatic_control_recipe.dart';
import 'recipes/slide_vs_shrink_recipe.dart';
import 'recipes/snapping_recipe.dart';
import 'recipes/sticky_footer_recipe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(CupertinoApp.router(routerConfig: router.config()));
}

final stupidSimpleSheetRoutes = [
  NamedRouteDef(
    name: 'Stupid Simple Sheet Examples',
    path: '',
    type: RouteType.cupertino(),
    builder: (context, state) => const _HomePage(),
  ),
  NamedRouteDef(
    name: 'Slide vs Shrink',
    path: 'slide-vs-shrink',
    type: RouteType.cupertino(),
    builder: (context, data) => const SlideVsShrinkRecipe(),
  ),
  NamedRouteDef(
    name: 'Playground',
    path: 'playground',
    type: RouteType.cupertino(),
    builder: (context, data) => const PlaygroundPage(),
  ),
  NamedRouteDef(
    name: 'Cupertino Sheet',
    path: 'cupertino-preset',
    builder: (context, data) => const CupertinoSheetPreset(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) =>
          StupidSimpleCupertinoSheetRoute<T>(
        backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
        settings: page,
        child: child,
      ),
    ),
  ),
  NamedRouteDef(
    name: 'Glass Sheet',
    path: 'glass-preset',
    builder: (context, data) => const GlassSheetPreset(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) =>
          StupidSimpleGlassSheetRoute<T>(
        backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
        settings: page,
        child: child,
      ),
    ),
  ),
  NamedRouteDef(
    name: 'Share Sheet',
    path: 'share-sheet',
    builder: (context, data) => const ShareSheetExample(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) =>
          StupidSimpleGlassSheetRoute<T>(
        snappingConfig: SheetSnappingConfig([.5, 1]),
        backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
        dismissalMode: DismissalMode.shrink,
        settings: page,
        child: child,
      ),
    ),
  ),
  NamedRouteDef(
    name: 'Custom Route',
    path: 'custom-route',
    builder: (context, data) => const CustomRouteExample(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) => CustomSheetRoute<T>(
        settings: page,
        child: child,
      ),
    ),
  ),
  NamedRouteDef(
    name: 'Dynamic Content',
    path: 'dynamic-content',
    builder: (context, data) => const DynamicContentExample(),
    type: RouteType.custom(
      customRouteBuilder: <T>(context, child, page) =>
          StupidSimpleSheetRoute<T>(
        backgroundSnapshotMode: RouteSnapshotMode.settled,
        settings: page,
        motion: CupertinoMotion.smooth(),
        originateAboveBottomViewInset: true,
        child: child,
      ),
    ),
  ),
];

final router = RootStackRouter.build(
  routes: [
    NamedRouteDef.shell(
      name: 'Home',
      path: '/',
      type: RouteType.cupertino(),
      children: stupidSimpleSheetRoutes,
    ),
  ],
);

const _cardMaxWidth = 340.0;
const _cardSpacing = 36.0;

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CupertinoPageScaffold(
      backgroundColor: t.canvas,
      child: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: const SectionHeader(
                        logo: SheetLogo(),
                        title: 'Stupid Simple Sheet',
                        subtitle:
                            'Interactive examples for Flutter\'s most flexible bottom sheet package.',
                        hint: '(tap to view pattern)',
                      ),
                    ),
                  ),
                  _cardSection(
                    label: 'RECIPES',
                    prefix: 'RCP',
                    cards: _recipeCards(context, t),
                  ),
                  _cardSection(
                    label: 'PLAYGROUND',
                    prefix: 'PLY',
                    cards: _playgroundCards(context, t),
                  ),
                  _cardSection(
                    label: 'BUNDLED PRESETS',
                    prefix: 'PRE',
                    cards: _presetCards(context, t),
                  ),
                  _cardSection(
                    label: 'ADVANCED',
                    prefix: 'ADV',
                    cards: _advancedCards(context, t),
                  ),
                  const SliverPadding(
                    padding: EdgeInsets.only(bottom: 64),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _cardSection({
    required String label,
    required String prefix,
    required List<Widget> cards,
  }) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: _SubsectionLabel(label)),
        SliverToBoxAdapter(
          child: CardSection(
            prefix: prefix,
            child: _CardGrid(children: cards),
          ),
        ),
      ],
    );
  }

  List<Widget> _recipeCards(BuildContext context, ExampleTheme t) => [
        ExampleCard(
          index: 0,
          pillLabel: 'Scroll + Drag',
          pillIcon: CupertinoIcons.arrow_up_arrow_down,
          pillColor: t.accentGreen,
          codeHint: 'StupidSimpleSheetRoute(child: ...)',
          preview: const BasicSheetPreview(),
          title: 'Basic Sheet',
          description: 'Scrollable content with drag-to-dismiss.',
          onTap: () => showBasicSheet(context),
        ),
        ExampleCard(
          index: 1,
          pillLabel: 'How to hide',
          pillIcon: CupertinoIcons.arrow_turn_down_right,
          pillColor: t.accentBlue,
          codeHint: 'dismissalMode: DismissalMode.shrink',
          preview: const SlideVsShrinkPreview(),
          title: 'Slide vs Shrink',
          description: 'Compare slide (translate) and shrink (collapse).',
          onTap: () => context.navigateTo(const NamedRoute('Slide vs Shrink')),
        ),
        ExampleCard(
          index: 2,
          pillLabel: 'Detents',
          pillIcon: CupertinoIcons.line_horizontal_3,
          pillColor: t.accentGold,
          codeHint: 'SheetSnappingConfig([0.33, 0.66, 1.0])',
          preview: const SnappingPreview(),
          title: 'Snapping',
          description: 'Configurable detents at 33%, 66%, 100%.',
          onTap: () => showSnappingSheet(context),
        ),
        ExampleCard(
          index: 3,
          pillLabel: 'Intrinsic Height',
          pillIcon: CupertinoIcons.crop,
          pillColor: t.accentIndigo,
          codeHint: 'Size',
          preview: const ContentSizedPreview(),
          title: 'Content-Sized Sheet',
          description:
              'The child dictates the sheet height. You have full control.',
          onTap: () => showContentSizedSheet(context),
        ),
        ExampleCard(
          index: 4,
          pillLabel: 'View Inset',
          pillIcon: CupertinoIcons.keyboard,
          pillColor: t.accentOrange,
          codeHint: 'originateAboveBottomViewInset: true',
          preview: const ContentSizedKeyboardPreview(),
          title: 'Above Keyboard',
          description: 'Sheet origin moves up with the software keyboard.',
          onTap: () => showContentSizedKeyboardSheet(context),
        ),
        ExampleCard(
          index: 5,
          pillLabel: 'Drag Resistance',
          pillIcon: CupertinoIcons.lock_fill,
          pillColor: t.accentPurple,
          codeHint: 'draggable: false',
          preview: const NonDraggablePreview(),
          title: 'Non-Draggable',
          description: 'Drag gestures resisted. Dismiss programmatically.',
          onTap: () => showNonDraggableSheet(context),
        ),
        ExampleCard(
          index: 6,
          pillLabel: 'Shrink + Footer',
          pillIcon: CupertinoIcons.pin_fill,
          pillColor: t.accentGreen,
          codeHint: 'DismissalMode.shrink',
          preview: const StickyFooterPreview(),
          title: 'Sticky Footer',
          description: 'Scrollable list with a footer that stays visible.',
          onTap: () => showStickyFooterSheet(context),
        ),
        ExampleCard(
          index: 7,
          pillLabel: 'SheetController',
          pillIcon: CupertinoIcons.slider_horizontal_3,
          pillColor: t.accentBlue,
          codeHint: 'controller.animateToRelative(0.5)',
          preview: const ProgrammaticControlPreview(),
          title: 'Programmatic Control',
          description: 'Drive the sheet position from code.',
          onTap: () => showProgrammaticControlSheet(context),
        ),
      ];

  List<Widget> _playgroundCards(BuildContext context, ExampleTheme t) => [
        ExampleCard(
          index: 0,
          pillLabel: 'Configurator',
          pillIcon: CupertinoIcons.slider_horizontal_below_rectangle,
          pillColor: t.accentOrange,
          codeHint: 'Toggle every setting live',
          preview: const PlaygroundPreview(),
          title: 'Playground',
          description: 'Configure and test every sheet parameter.',
          onTap: () => context.navigateTo(const NamedRoute('Playground')),
        ),
      ];

  List<Widget> _presetCards(BuildContext context, ExampleTheme t) => [
        ExampleCard(
          index: 0,
          pillLabel: 'iOS 18',
          pillIcon: CupertinoIcons.layers,
          pillColor: t.accentIndigo,
          codeHint: 'StupidSimpleCupertinoSheetRoute(...)',
          preview: const CupertinoSheetPreview(),
          title: 'Cupertino Sheet',
          description: 'iOS 18 push-back style with cascading stacks.',
          onTap: () => context.navigateTo(const NamedRoute('Cupertino Sheet')),
        ),
        ExampleCard(
          index: 1,
          pillLabel: 'iOS 26',
          pillIcon: CupertinoIcons.sparkles,
          pillColor: t.accentPurple,
          codeHint: 'StupidSimpleGlassSheetRoute(...)',
          preview: const GlassSheetPreview(),
          title: 'Glass Sheet',
          description:
              'The first sheet blurs and fades the background. Subsequent sheets stack on top of each other.',
          onTap: () => context.navigateTo(const NamedRoute('Glass Sheet')),
        ),
      ];

  List<Widget> _advancedCards(BuildContext context, ExampleTheme t) => [
        ExampleCard(
          index: 0,
          pillLabel: 'Shrink + Snap',
          pillIcon: CupertinoIcons.share,
          pillColor: t.accentGold,
          codeHint: 'DismissalMode.shrink + snapping',
          preview: const ShareSheetPreview(),
          title: 'Share Sheet',
          description: 'Shrink dismissal with scrollable contacts.',
          onTap: () => context.navigateTo(const NamedRoute('Share Sheet')),
        ),
        ExampleCard(
          index: 1,
          pillLabel: 'AnimatedSize',
          pillIcon: CupertinoIcons.text_badge_plus,
          pillColor: t.accentOrange,
          codeHint: 'AnimatedSize + originateAboveKeyboard',
          preview: const DynamicContentPreview(),
          title: 'Dynamic Content',
          description: 'Growing list with text input above keyboard.',
          onTap: () => context.navigateTo(const NamedRoute('Dynamic Content')),
        ),
        ExampleCard(
          index: 2,
          pillLabel: 'TransitionMixin',
          pillIcon: CupertinoIcons.hammer,
          pillColor: t.accentGreen,
          codeHint: 'StupidSimpleSheetTransitionMixin',
          preview: const CustomRoutePreview(),
          title: 'Custom Route',
          description: 'Build your own PopupRoute with the sheet mixin.',
          onTap: () => context.navigateTo(const NamedRoute('Custom Route')),
        ),
      ];
}

class _SubsectionLabel extends StatelessWidget {
  const _SubsectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 20),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: t.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Lays out [ExampleCard] children in a responsive wrap grid.
///
/// On narrow screens (phone) this produces a single column of centered cards.
/// On wider screens (tablet / desktop) cards flow into multiple columns
/// with consistent spacing.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / (_cardMaxWidth + _cardSpacing))
            .floor()
            .clamp(1, 4);
        final itemWidth = columns == 1
            ? constraints.maxWidth.clamp(0.0, _cardMaxWidth)
            : (constraints.maxWidth - (columns - 1) * _cardSpacing) / columns;

        return Wrap(
          spacing: _cardSpacing,
          runSpacing: _cardSpacing,
          alignment: WrapAlignment.center,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}
