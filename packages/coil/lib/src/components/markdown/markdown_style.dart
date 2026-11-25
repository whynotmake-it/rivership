/// @docImport 'package:coil/markdown.dart';
library;

import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// The look of [CoilMarkdown]: a type ramp and block rhythm for prose, on
/// top of the ambient text style.
///
/// Sizes and gaps are multiples of the body's font size, so the ramp holds
/// at every tier and text scale. Null fields fall back to
/// [CoilMarkdownStyle.fallback].
@immutable
class CoilMarkdownStyle {
  /// Creates a style; null fields fall back to [CoilMarkdownStyle.fallback].
  const CoilMarkdownStyle({
    this.headingScale,
    this.headingWeight,
    this.blockGap,
    this.headingGapAbove,
    this.headingGapBelow,
    this.listItemGap,
    this.ruleGap,
    this.markerColor,
    this.ruleColor,
    this.codeFill,
    this.codeStyle,
    this.linkStyle,
  });

  /// Coil's defaults for [context]: H1 1.25× the body, H2 1.125×, H3 to H6
  /// the body size, all in [CoilTextTheme.emphasis]; more room above a
  /// heading than below it; list items close; markers and rules muted.
  factory CoilMarkdownStyle.fallback(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    return CoilMarkdownStyle(
      headingScale: const [1.25, 1.125, 1, 1, 1, 1],
      headingWeight: text.emphasis,
      blockGap: 0.75,
      headingGapAbove: 1.25,
      headingGapBelow: 0.4,
      listItemGap: 0.3,
      ruleGap: 1,
      markerColor: colors.mutedForeground,
      ruleColor: colors.border,
      codeFill: colors.muted,
      codeStyle: const TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: ['Menlo', 'SF Mono', 'Consolas', 'Roboto Mono'],
      ),
      linkStyle: TextStyle(
        decoration: TextDecoration.underline,
        decorationColor: colors.mutedForeground,
      ),
    );
  }

  /// Font size of H1 to H6, as multiples of the body size.
  final List<double>? headingScale;

  /// The headings' weight.
  final FontWeight? headingWeight;

  /// Room between blocks, in body font sizes.
  final double? blockGap;

  /// Room above an H1 or H2, in body font sizes; smaller headings take
  /// [blockGap] + a quarter.
  final double? headingGapAbove;

  /// Room between a heading and what follows it, in body font sizes.
  final double? headingGapBelow;

  /// Room between list items, in body font sizes.
  final double? listItemGap;

  /// Room above and below a rule, in body font sizes.
  final double? ruleGap;

  /// Bullets, numbers and task boxes.
  final Color? markerColor;

  /// Rules, quote bars and table lines.
  final Color? ruleColor;

  /// Behind code.
  final Color? codeFill;

  /// Code, merged onto the body style at 0.9× its size.
  final TextStyle? codeStyle;

  /// Links, merged onto the surrounding text.
  final TextStyle? linkStyle;

  /// This style with [other]'s non-null fields on top.
  CoilMarkdownStyle merge(CoilMarkdownStyle? other) => other == null
      ? this
      : CoilMarkdownStyle(
          headingScale: other.headingScale ?? headingScale,
          headingWeight: other.headingWeight ?? headingWeight,
          blockGap: other.blockGap ?? blockGap,
          headingGapAbove: other.headingGapAbove ?? headingGapAbove,
          headingGapBelow: other.headingGapBelow ?? headingGapBelow,
          listItemGap: other.listItemGap ?? listItemGap,
          ruleGap: other.ruleGap ?? ruleGap,
          markerColor: other.markerColor ?? markerColor,
          ruleColor: other.ruleColor ?? ruleColor,
          codeFill: other.codeFill ?? codeFill,
          codeStyle: codeStyle?.merge(other.codeStyle) ?? other.codeStyle,
          linkStyle: linkStyle?.merge(other.linkStyle) ?? other.linkStyle,
        );

  @override
  bool operator ==(Object other) =>
      other is CoilMarkdownStyle &&
      _listEquals(other.headingScale, headingScale) &&
      other.headingWeight == headingWeight &&
      other.blockGap == blockGap &&
      other.headingGapAbove == headingGapAbove &&
      other.headingGapBelow == headingGapBelow &&
      other.listItemGap == listItemGap &&
      other.ruleGap == ruleGap &&
      other.markerColor == markerColor &&
      other.ruleColor == ruleColor &&
      other.codeFill == codeFill &&
      other.codeStyle == codeStyle &&
      other.linkStyle == linkStyle;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(headingScale ?? const []),
    headingWeight,
    blockGap,
    headingGapAbove,
    headingGapBelow,
    listItemGap,
    ruleGap,
    markerColor,
    ruleColor,
    codeFill,
    codeStyle,
    linkStyle,
  );
}

bool _listEquals(List<double>? a, List<double>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
