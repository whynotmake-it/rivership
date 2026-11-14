import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:coil_example/src/shell/settings_sheet.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:coil_example/src/widgets/type_roles.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Layout values from DESIGN.md §4.3 that the catalog's pages use.
abstract final class CatalogLayout {
  /// The widest a page's content gets; wider windows center it.
  static const maxContentWidth = 760.0;

  /// Page gutter: 16 on a touch phone, 24 everywhere else.
  static double gutterOf(BuildContext context) =>
      CoilTheme.tierOf(context) == CoilTier.touch &&
          MediaQuery.sizeOf(context).width < 600
      ? 16
      : 24;

  /// Section → section: 24 pointer, 32 touch.
  static double sectionGapOf(BuildContext context) =>
      CoilTheme.tierOf(context) == CoilTier.touch ? 32 : 24;
}

/// A catalog page: a header with back and settings buttons, then
/// [children] in a centered, scrolling column.
class CatalogPage extends StatelessWidget {
  const CatalogPage({
    required this.title,
    required this.children,
    super.key,
    this.summary,
  });

  final String title;

  /// One or two sentences under the header.
  final String? summary;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final gutter = CatalogLayout.gutterOf(context);
    final sectionGap = CatalogLayout.sectionGapOf(context);
    final summary = this.summary;
    final padding = MediaQuery.paddingOf(context);
    // A page owns its background, so a page pushed on top covers the one
    // below instead of showing through it.
    return ColoredBox(
      color: CoilTheme.of(context).colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CatalogHeader(title: title),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: ListView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  gutter + padding.left,
                  8,
                  gutter + padding.right,
                  gutter + padding.bottom,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: CatalogLayout.maxContentWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (summary != null) ...[
                            RoleText(
                              summary,
                              role: TypeRole.subtitle,
                              muted: true,
                            ),
                            SizedBox(height: sectionGap),
                          ],
                          for (final (i, child) in children.indexed) ...[
                            if (i > 0) SizedBox(height: sectionGap),
                            child,
                          ],
                        ],
                      ),
                    ),
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

/// The bar at the top of every page: back (when there's somewhere to go
/// back to), the title, and the settings button.
class CatalogHeader extends StatelessWidget {
  const CatalogHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final router = context.router;
    final gutter = CatalogLayout.gutterOf(context);
    final padding = MediaQuery.paddingOf(context);
    // Ghost icon buttons have no visible edge, so the bar pulls them 8
    // toward the screen edge to line their glyphs up with the content.
    final inset = gutter - 8;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        inset + padding.left,
        padding.top + 8,
        inset + padding.right,
        8,
      ),
      child: Row(
        children: [
          if (router.canPop()) ...[
            CoilButton.icon(
              variant: CoilButtonVariant.ghost,
              semanticLabel: 'Back',
              icon: const CatalogIcon(Glyph.back),
              onPressed: router.maybePop,
            ),
            const SizedBox(width: 4),
          ] else
            const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeRole.title.styleOf(context),
              ),
            ),
          ),
          const SettingsButton(),
        ],
      ),
    );
  }
}

/// A titled block on a page, with the live example on a raised stage.
class DemoSection extends StatelessWidget {
  const DemoSection({
    required this.title,
    required this.child,
    super.key,
    this.description,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final description = this.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: RoleText(
            title,
            role: TypeRole.subtitle,
            weight: CoilWeight.semibold,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          RoleText(description, role: TypeRole.caption, muted: true),
        ],
        const SizedBox(height: 12),
        DemoStage(child: child),
      ],
    );
  }
}

/// A card-like surface (surface 3, hairline, container radius) that holds
/// live examples. Its border darkens while keyboard focus is inside, so you
/// can see which example takes your keys.
class DemoStage extends StatelessWidget {
  const DemoStage({required this.child, super.key, this.padding = 16});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final motion = CoilTheme.motionOf(context);
    final radius = CoilTheme.radiiOf(context).container;
    final focusedBorder = colors.foreground.withValues(
      alpha: colors.brightness == Brightness.dark ? 0.7 : 0.65,
    );
    return CoilFocusWithin(
      builder: (context, focused, child) => SingleMotionBuilder(
        value: focused ? 1 : 0,
        motion: focused ? motion.fade : motion.fadeExit,
        debugLabel: 'DemoStage focus',
        builder: (context, t, child) => DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.surface(3),
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(
                color: Color.lerp(
                  colors.border,
                  focusedBorder,
                  t.clamp(0, 1),
                )!,
              ),
            ),
          ),
          child: child,
        ),
        child: child,
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }
}

/// Examples laid out in a wrapping row, each with an optional caption.
class DemoWrap extends StatelessWidget {
  const DemoWrap({
    required this.children,
    super.key,
    this.spacing,
    this.crossAxisAlignment = WrapCrossAlignment.center,
  });

  final List<Widget> children;
  final double? spacing;
  final WrapCrossAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final gap = spacing ?? CoilTheme.metricsOf(context).gap;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }
}

/// A caption above an example, naming its variant or state.
class Labeled extends StatelessWidget {
  const Labeled(this.label, {required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RoleText(label, role: TypeRole.caption, muted: true),
      const SizedBox(height: 6),
      child,
    ],
  );
}

/// A vertical stack with DESIGN.md's field → field spacing.
class DemoColumn extends StatelessWidget {
  const DemoColumn({required this.children, super.key, this.spacing});

  final List<Widget> children;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final gap =
        spacing ?? (CoilTheme.tierOf(context) == CoilTier.touch ? 16.0 : 12.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) SizedBox(height: gap),
          child,
        ],
      ],
    );
  }
}
