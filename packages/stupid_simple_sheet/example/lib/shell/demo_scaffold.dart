import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';

/// A realistic app screen for a demo: a top bar with a back button, the
/// screen's [title] and an optional [trailing] action, over [body].
///
/// The bar clears the top safe area and is a control tall with 8 above and
/// below, the page gutter at its sides. The body fills the rest. Lay its
/// content out in [DemoContent] so it shares the bar's gutter and the
/// 640 measure.
class DemoScaffold extends StatelessWidget {
  /// Creates a screen.
  const DemoScaffold({
    required this.title,
    required this.body,
    super.key,
    this.trailing,
  });

  /// The screen's title, usually a [Text].
  final Widget title;

  /// An action at the end of the bar, usually a compact [CoilButton].
  final Widget? trailing;

  /// What the screen shows under the bar.
  final Widget body;

  /// The widest the content gets; wider windows center it.
  static const maxContentWidth = 640.0;

  /// The page gutter: 16 on phone widths, 24 above (DESIGN 4.3).
  static double gutterOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600 ? 16 : 24;

  /// The space between sections: 24 for pointers, 32 for touch.
  static double sectionGapOf(BuildContext context) =>
      CoilTheme.tierOf(context) == CoilTier.touch ? 32 : 24;

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context);
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
          child: DemoContent(
            child: SizedBox(
              height: metrics.controlHeight + 16,
              child: Row(
                spacing: metrics.gap,
                children: [
                  CoilButton.icon(
                    variant: CoilButtonVariant.ghost,
                    semanticLabel: 'Back',
                    icon: const CoilIcon(CoilIconRole.chevronStart),
                    onPressed: () => Navigator.maybeOf(context)?.maybePop(),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: DefaultTextStyle.merge(
                        style: text.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        child: title,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

/// Centers [child] in the demo measure: at most 640 wide with the page
/// gutter at its sides.
class DemoContent extends StatelessWidget {
  /// Creates a centered, padded column for [child].
  const DemoContent({required this.child, super.key});

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gutter = DemoScaffold.gutterOf(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: DemoScaffold.maxContentWidth + 2 * gutter,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );
  }
}
