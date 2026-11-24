import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/shell/motor_shell.dart';
import 'package:motor_example/widgets/code_block.dart';
import 'package:motor_example/widgets/icons.dart';

/// Layout values from coil's DESIGN.md §4.3 that the gallery's pages use.
abstract final class PageLayout {
  /// The widest a page's content gets; wider windows center it.
  static const maxContentWidth = 760.0;

  /// Page gutter: 16 on a touch phone, 24 everywhere else.
  static double gutterOf(BuildContext context) =>
      CoilTheme.tierOf(context) == CoilTier.touch &&
          MediaQuery.sizeOf(context).width < phoneBreakpoint
      ? 16
      : 24;

  /// Section → section: 24 pointer, 32 touch.
  static double sectionGapOf(BuildContext context) =>
      CoilTheme.tierOf(context) == CoilTier.touch ? 32 : 24;
}

/// A page of the gallery: the header with the sidebar trigger and the
/// title, then [children] in a centered, scrolling column.
class GalleryPage extends StatelessWidget {
  const GalleryPage({
    required this.title,
    required this.children,
    this.lead,
    super.key,
  });

  final String title;

  /// What to try and what to notice, in a sentence or two.
  final String? lead;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final gutter = PageLayout.gutterOf(context);
    final sectionGap = PageLayout.sectionGapOf(context);
    final padding = MediaQuery.paddingOf(context);
    final text = CoilTheme.textOf(context);
    final lead = this.lead;
    return ColoredBox(
      color: CoilTheme.of(context).colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: title),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: CoilScrollArea(
                child: SingleChildScrollView(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    gutter + padding.left,
                    8,
                    gutter + padding.right,
                    48 + padding.bottom,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: PageLayout.maxContentWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (lead != null) ...[
                            Text(lead, style: text.muted.subtitle),
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The bar at the top of every page: the sidebar's trigger and the title.
class PageHeader extends StatelessWidget {
  const PageHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final gutter = PageLayout.gutterOf(context);
    final padding = MediaQuery.paddingOf(context);
    // A ghost icon button has no visible edge, so the bar pulls it 8
    // toward the screen edge to line its glyph up with the content.
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
          // Outside the gallery's sidebar (a page on its own) there is
          // nothing to open.
          if (HasSidebar.of(context)) ...[
            const CoilSidebarTrigger(icon: GlyphIcon(Glyph.panelLeft)),
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
                style: CoilTheme.textOf(context).title,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The layout every demo shares: a short lead, the stage, the code that is
/// running, an optional timeline, and a link to the next demo.
class ChapterPage extends StatelessWidget {
  const ChapterPage({
    required this.chapter,
    required this.lead,
    required this.stage,
    this.code,
    this.below,
    this.stageHeight = 400,
    super.key,
  });

  final Chapter chapter;

  /// What to try and what to notice, in a few short sentences.
  final String lead;

  /// The live demo. It fills the stage, edge to edge.
  final Widget stage;

  /// The code this demo is about. Pages update it as you interact, so it
  /// shows the call that's running.
  final ValueListenable<String>? code;

  /// Shown under the code, usually a [LiveTimeline].
  final Widget? below;

  final double stageHeight;

  @override
  Widget build(BuildContext context) {
    final next = chapter.next;
    final gap = CoilTheme.metricsOf(context).gap;
    // Stages lay out text in a fixed height, so they grow with larger text.
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return GalleryPage(
      title: chapter.title,
      lead: lead,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: stageHeight * math.max(1, textScale),
              child: DemoStage(child: stage),
            ),
            if (code case final code?) ...[
              SizedBox(height: gap),
              ValueListenableBuilder(
                valueListenable: code,
                builder: (context, code, _) => CodeBlock(code),
              ),
            ],
            if (below case final below?) ...[SizedBox(height: gap), below],
          ],
        ),
        if (next != null) NextChapter(next: next),
      ],
    );
  }
}

/// The surface a live demo plays on: a card's level with a hairline and
/// no drop shadow, clipped to its corners.
class DemoStage extends StatelessWidget {
  const DemoStage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).container);
    final colors = CoilTheme.of(context).colors;
    return CoilSurface(
      offset: CoilSurface.popoverOffset,
      shadowLevel: 1,
      borderRadius: radius,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: radius,
            side: BorderSide(color: colors.border),
          ),
        ),
        child: ClipRSuperellipse(
          borderRadius: radius,
          // The stage stands in for a page, so controls on it are lit like
          // controls on the page.
          child: CoilPlasticityScope(elevated: false, child: child),
        ),
      ),
    );
  }
}

/// A link to the demo after this one, at the end of a page.
class NextChapter extends StatelessWidget {
  const NextChapter({required this.next, super.key});

  final Chapter next;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final card = CoilCard(
      variant: CoilCardVariant.inline,
      semanticLabel: 'Next: ${next.title}',
      icon: GlyphIcon(next.glyph),
      title: Text(next.title),
      description: Text(next.idea),
      onPressed: () {
        final router = AutoRouter.of(context);
        unawaited(openChapter(router, next));
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: Text('Next', style: text.muted.caption)),
        const SizedBox(height: 6),
        card,
      ],
    );
  }
}
