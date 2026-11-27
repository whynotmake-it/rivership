import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:turns_example/src/shell/turns_environment.dart';
import 'package:turns_example/src/shell/turns_shell.dart';

/// The layout every concept shares: a short lead, a live stage, what the
/// stage measured, the code that is running, and a link to the next concept.
class ConceptPage extends StatelessWidget {
  const ConceptPage({
    required this.routeName,
    required this.lead,
    required this.stage,
    super.key,
    this.controls,
    this.readout,
    this.code,
    this.stageHeight = 440,
  });

  /// This concept's route, to find the one after it.
  final String routeName;

  /// What to try and what to notice, in two or three short sentences.
  final String lead;

  /// Buttons and settings that drive the stage, above it.
  final Widget? controls;

  /// The live demo. It fills the stage, edge to edge.
  final Widget stage;

  /// What the stage measured, under it.
  final Widget? readout;

  /// The code the stage runs. Pages may update it as you interact.
  final ValueListenable<String>? code;

  final double stageHeight;

  static const maxContentWidth = 820.0;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final padding = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final gutter =
        CoilTheme.tierOf(context) == CoilTier.touch &&
            width < turnsPhoneBreakpoint
        ? 16.0
        : 24.0;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final index = turnsConcepts.indexWhere((c) => c.routeName == routeName);
    final next = index >= 0 && index + 1 < turnsConcepts.length
        ? turnsConcepts[index + 1]
        : null;

    return ColoredBox(
      color: CoilTheme.of(context).colors.background,
      child: CoilScrollArea(
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(
            gutter + padding.left,
            20,
            gutter + padding.right,
            48 + padding.bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 14,
                children: [
                  Text(lead, style: text.muted.body),
                  if (controls case final controls?) controls,
                  SizedBox(
                    height: stageHeight * math.max(1, textScale),
                    child: ConceptStage(child: stage),
                  ),
                  ?readout,
                  if (code case final code?)
                    ValueListenableBuilder(
                      valueListenable: code,
                      builder: (context, code, _) => ConceptCode(code),
                    ),
                  if (next != null) ...[
                    const SizedBox(height: 10),
                    _NextConcept(next: next),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The surface a live demo plays on: a hairline card, clipped to its
/// corners.
class ConceptStage extends StatelessWidget {
  const ConceptStage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).container);
    final colors = CoilTheme.of(context).colors;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.border),
        ),
      ),
      child: ClipRSuperellipse(
        borderRadius: radius,
        child: ColoredBox(color: colors.surfaces[1], child: child),
      ),
    );
  }
}

/// A few lines of Dart, rendered as a fenced code block.
class ConceptCode extends StatelessWidget {
  const ConceptCode(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) => CoilMarkdown('```dart\n$code\n```');
}

/// A labelled number under a stage, such as "Rows built · 23".
class ConceptStat extends StatelessWidget {
  const ConceptStat({
    required this.label,
    required this.value,
    super.key,
    this.tone = ConceptTone.neutral,
  });

  final String label;
  final String value;
  final ConceptTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final ink = switch (tone) {
      ConceptTone.neutral => colors.foreground,
      ConceptTone.good => colors.brandInk,
      ConceptTone.bad => colors.destructive,
    };
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.surfaces[1],
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(CoilTheme.radiiOf(context).item),
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: text.muted.micro),
            const SizedBox(height: 2),
            Text(
              value,
              style: text.subtitle.tabular.copyWith(
                color: ink,
                fontWeight: text.emphasis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ConceptTone { neutral, good, bad }

/// A row of [ConceptStat]s that wraps on narrow screens.
class ConceptStats extends StatelessWidget {
  const ConceptStats({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}

class _NextConcept extends StatelessWidget {
  const _NextConcept({required this.next});

  final TurnsDemoEntry next;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: Text('Next', style: text.muted.caption)),
        const SizedBox(height: 6),
        CoilCard(
          variant: CoilCardVariant.inline,
          semanticLabel: 'Next: ${next.title}',
          icon: TurnsGlyphIcon(next.glyph),
          title: Text(next.title),
          description: Text(next.description),
          onPressed: () =>
              unawaited(openTurnsRoute(AutoRouter.of(context), next.routeName)),
        ),
      ],
    );
  }
}
