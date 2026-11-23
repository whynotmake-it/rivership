import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:heroine_example/src/brand.dart';
import 'package:heroine_example/src/icons.dart';

/// Layout values from coil's DESIGN.md §4.3 that the demos use.
abstract final class DemoLayout {
  /// The widest a page of text gets; wider windows center it.
  static const maxContentWidth = 760.0;

  /// Page gutter: 16 on a phone, 24 everywhere else.
  static double gutterOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600 ? 16 : 24;
}

/// A coil page: its own background, a [DemoHeader], an optional one-line
/// [summary] and then [child], which fills the rest.
class DemoPage extends StatelessWidget {
  const DemoPage({
    required this.title,
    required this.child,
    super.key,
    this.summary,
    this.trailing,
    this.showBack = true,
    this.brand,
  });

  final String title;

  /// Shown in the header instead of [title], such as the example's brand.
  final Widget? brand;

  /// One sentence under the header.
  final String? summary;

  /// A widget at the end of the header.
  final Widget? trailing;

  /// Whether the header has a back button. Off for the picker, the root
  /// page of the example.
  final bool showBack;

  /// The page's content, below the header.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gutter = DemoLayout.gutterOf(context);
    final padding = MediaQuery.paddingOf(context);
    final summary = this.summary;
    return ColoredBox(
      color: CoilTheme.of(context).colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DemoHeader(
            title: title,
            trailing: trailing,
            showBack: showBack,
            brand: brand,
          ),
          if (summary != null)
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                gutter + padding.left,
                4,
                gutter + padding.right,
                16,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: DemoLayout.maxContentWidth,
                  ),
                  child: Text(
                    summary,
                    style: CoilTheme.textOf(context).muted.subtitle,
                  ),
                ),
              ),
            ),
          // The header already cleared the top safe area.
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// The bar at the top of a page: back (when there's somewhere to go back
/// to), the title and an optional [trailing] widget.
class DemoHeader extends StatelessWidget {
  const DemoHeader({
    required this.title,
    super.key,
    this.trailing,
    this.showBack = true,
    this.brand,
  });

  final String title;

  /// Shown instead of [title]. It is pulled toward the edge by
  /// [HeroineBrand.inkInsetOf], so its mark lines up with the content.
  final Widget? brand;

  /// A widget after the title, such as a settings button.
  final Widget? trailing;

  /// Whether to show the back button, which pops within the example's own
  /// router.
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final gutter = DemoLayout.gutterOf(context);
    final padding = MediaQuery.paddingOf(context);
    // Ghost icon buttons have no visible edge, so the bar pulls them toward
    // the screen edge until their ink lines up with the content's gutter:
    // by the button's padding around its glyph, and for the back chevron
    // also by the empty space Lucide's chevron-left leaves on its start
    // side (its stroke starts 8.25 into the 24-unit grid).
    final metrics = CoilTheme.metricsOf(context);
    final glyphPad = (metrics.controlHeight - metrics.iconSize) / 2;
    final start = showBack
        ? gutter - glyphPad - metrics.iconSize * 8.25 / 24
        : brand != null
        ? gutter - HeroineBrand.inkInsetOf(context)
        : gutter;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        start + padding.left,
        padding.top + 8,
        gutter - glyphPad + padding.right,
        8,
      ),
      child: Row(
        children: [
          if (showBack) ...[
            CoilButton.icon(
              variant: CoilButtonVariant.ghost,
              onPressed: context.router.maybePop,
              icon: const DemoIcon(Glyph.back),
              semanticLabel: 'Back',
            ),
            const SizedBox(width: 4),
          ],
          if (brand case final brand?)
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: brand,
              ),
            )
          else
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CoilTheme.textOf(context).title,
                ),
              ),
            ),
          ?trailing,
        ],
      ),
    );
  }
}
