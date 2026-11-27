import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:turns_example/src/shell/turns_environment.dart';
import 'package:turns_example/src/shell/turns_shell.dart';

/// Overview page introducing `turns`, its five interactive demos, and its core
/// scroll and streaming-markdown building blocks.
class TurnsOverviewPage extends StatelessWidget {
  const TurnsOverviewPage({super.key});

  static const _maxContentWidth = 760.0;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final gap = CoilTheme.metricsOf(context).gap;
    final padding = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final gutter =
        CoilTheme.tierOf(context) == CoilTier.touch &&
            width < turnsPhoneBreakpoint
        ? 16.0
        : 24.0;
    final sectionGap = CoilTheme.tierOf(context) == CoilTier.touch
        ? 32.0
        : 24.0;
    final columns = width >= 960 ? 2 : 1;

    return ColoredBox(
      color: CoilTheme.of(context).colors.background,
      child: CoilScrollArea(
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(
            gutter + padding.left,
            24,
            gutter + padding.right,
            48 + padding.bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const TurnsLogo(size: 32),
                            const SizedBox(width: 12),
                            Text('turns', style: text.display),
                            const SizedBox(width: 8),
                            const CoilBadge(child: Text('0.1')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Turn-anchored scroll views and incremental streaming '
                        'markdown parsing for Flutter chat and AI interfaces. '
                        'O(1) bidirectional timelines, sticky section headers, '
                        'and Motor-driven springs.',
                        style: text.muted.subtitle,
                      ),
                      SizedBox(height: gap * 2),
                      const CoilInputCopy(
                        value: 'flutter pub add turns',
                        variant: CoilInputCopyVariant.button,
                      ),
                    ],
                  ),
                  SizedBox(height: sectionGap),
                  Semantics(
                    header: true,
                    child: Text(
                      'Interactive Demos',
                      style: text.subtitle.copyWith(fontWeight: text.emphasis),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CoilCardGroup(
                    columns: columns,
                    children: [
                      for (final demo in turnsDemos)
                        CoilCard(
                          variant: CoilCardVariant.inline,
                          icon: TurnsGlyphIcon(demo.glyph),
                          title: Text(demo.title),
                          description: Text(demo.description),
                          onPressed: () => unawaited(
                            openTurnsRoute(
                              AutoRouter.of(context),
                              demo.routeName,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: sectionGap),
                  Semantics(
                    header: true,
                    child: Text(
                      'Core Primitives',
                      style: text.subtitle.copyWith(fontWeight: text.emphasis),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CoilCardGroup(
                    columns: columns,
                    children: const [
                      CoilCard(
                        variant: CoilCardVariant.inline,
                        title: Text('TurnScrollView'),
                        description: Text(
                          'Bidirectional Viewport(center:) timeline with '
                          '0px prepend stability, SliverTurnStage pinning, '
                          'and O(1) opening at any message.',
                        ),
                      ),
                      CoilCard(
                        variant: CoilCardVariant.inline,
                        title: Text('TurnScrollView.sectioned'),
                        description: Text(
                          'Typed section headers with an isPinned flag for '
                          'inline dividers vs floating sticky pills, O(1) '
                          'open, and smooth push-up across the center seam.',
                        ),
                      ),
                      CoilCard(
                        variant: CoilCardVariant.inline,
                        title: Text('CustomTurnScrollView + SliverTurnList'),
                        description: Text(
                          'Escape hatch for bounded feeds needing '
                          'SliverAppBar, SliverGrid, or stacked '
                          'SliverPersistentHeaders with offscreen scrollTo().',
                        ),
                      ),
                      CoilCard(
                        variant: CoilCardVariant.inline,
                        title: Text('MarkdownSession'),
                        description: Text(
                          'Pure-Dart incremental GFM parser that freezes '
                          'settled blocks and closes in-flight syntax cleanly '
                          'while tokens stream.',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
