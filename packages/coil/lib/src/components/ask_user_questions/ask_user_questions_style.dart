import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilAskUserQuestions` looks. Unset fields come from
/// [CoilAskUserQuestionsStyle.fallback], derived from the theme's tokens.
/// Set a style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
class CoilAskUserQuestionsStyle
    extends CoilComponentStyle<CoilAskUserQuestionsStyle> {
  /// Creates a style.
  const CoilAskUserQuestionsStyle({
    this.surface,
    this.border,
    this.radius,
    this.maxWidth,
    this.stepStyle,
    this.titleStyle,
    this.labelStyle,
    this.descriptionStyle,
    this.keyStyle,
    this.errorStyle,
    this.label,
    this.description,
    this.keyColor,
    this.keyBorder,
    this.keySelected,
    this.keySelectedLabel,
    this.highlight,
    this.selection,
    this.itemRadius,
    this.keyRadius,
    this.fieldFocusFill,
    this.fieldFocusBorder,
  });

  /// The defaults from the theme's tokens: a hairline card on the
  /// surface it sits on.
  factory CoilAskUserQuestionsStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    final t = theme.typography.resolve(metrics.tier, metrics.size);
    final radii = theme.shape.radii(metrics.tier);
    final light = c.brightness == Brightness.light;
    final compact = metrics.size == CoilSize.compact;
    return CoilAskUserQuestionsStyle(
      surface: c.surface(light ? 3 : 2),
      border: BorderSide(color: c.border),
      radius: radii.container,
      maxWidth: 520,
      stepStyle: t.caption.copyWith(color: c.mutedForeground),
      titleStyle: t.title.copyWith(color: c.foreground),
      labelStyle: t.body,
      descriptionStyle: t.body,
      keyStyle: t.micro,
      errorStyle: t.caption.copyWith(color: c.destructive),
      label: c.foreground,
      description: c.mutedForeground,
      keyColor: c.mutedForeground,
      keyBorder: c.border,
      keySelected: c.foreground,
      keySelectedLabel: c.background,
      highlight: c.hover,
      selection: c.active,
      itemRadius: radii.item,
      keyRadius: compact ? 4 : 5,
      fieldFocusFill: c.surface(light ? 3 : 2),
      fieldFocusBorder: c.border,
    );
  }

  /// The card's fill.
  final Color? surface;

  /// The card's hairline.
  final BorderSide? border;

  /// The card's corner radius.
  final double? radius;

  /// The widest the card grows.
  final double? maxWidth;

  /// "Question 2 of 4".
  final TextStyle? stepStyle;

  /// The question.
  final TextStyle? titleStyle;

  /// An option's label (color from [label]).
  final TextStyle? labelStyle;

  /// An option's description in the inline layout (color from
  /// [description]). The stacked layout uses the caption role.
  final TextStyle? descriptionStyle;

  /// The number on a key (color from [keyColor] or [keySelectedLabel]).
  final TextStyle? keyStyle;

  /// A free-text answer's validation message.
  final TextStyle? errorStyle;

  /// The option label color.
  final Color? label;

  /// The option description color.
  final Color? description;

  /// The number key at rest.
  final Color? keyColor;

  /// The outline of a multiple-choice key.
  final Color? keyBorder;

  /// A picked key: the number of a single-choice key, the fill of a
  /// multiple-choice one, and the submit arrow's fill.
  final Color? keySelected;

  /// The number on a filled key, and the submit arrow.
  final Color? keySelectedLabel;

  /// The gliding hover highlight.
  final Color? highlight;

  /// The merged block behind picked rows.
  final Color? selection;

  /// The corner radius of rows, blocks and the highlight.
  final double? itemRadius;

  /// The corner radius of a multiple-choice key.
  final double? keyRadius;

  /// The fill of an empty "other" field while it has focus.
  final Color? fieldFocusFill;

  /// The outline of an empty "other" field while it has focus.
  final Color? fieldFocusBorder;

  @override
  CoilAskUserQuestionsStyle merge(CoilAskUserQuestionsStyle? other) =>
      other == null
      ? this
      : CoilAskUserQuestionsStyle(
          surface: other.surface ?? surface,
          border: other.border ?? border,
          radius: other.radius ?? radius,
          maxWidth: other.maxWidth ?? maxWidth,
          stepStyle: stepStyle?.merge(other.stepStyle) ?? other.stepStyle,
          titleStyle: titleStyle?.merge(other.titleStyle) ?? other.titleStyle,
          labelStyle: labelStyle?.merge(other.labelStyle) ?? other.labelStyle,
          descriptionStyle:
              descriptionStyle?.merge(other.descriptionStyle) ??
              other.descriptionStyle,
          keyStyle: keyStyle?.merge(other.keyStyle) ?? other.keyStyle,
          errorStyle: errorStyle?.merge(other.errorStyle) ?? other.errorStyle,
          label: other.label ?? label,
          description: other.description ?? description,
          keyColor: other.keyColor ?? keyColor,
          keyBorder: other.keyBorder ?? keyBorder,
          keySelected: other.keySelected ?? keySelected,
          keySelectedLabel: other.keySelectedLabel ?? keySelectedLabel,
          highlight: other.highlight ?? highlight,
          selection: other.selection ?? selection,
          itemRadius: other.itemRadius ?? itemRadius,
          keyRadius: other.keyRadius ?? keyRadius,
          fieldFocusFill: other.fieldFocusFill ?? fieldFocusFill,
          fieldFocusBorder: other.fieldFocusBorder ?? fieldFocusBorder,
        );

  @override
  List<Object?> get props => [
    surface,
    border,
    radius,
    maxWidth,
    stepStyle,
    titleStyle,
    labelStyle,
    descriptionStyle,
    keyStyle,
    errorStyle,
    label,
    description,
    keyColor,
    keyBorder,
    keySelected,
    keySelectedLabel,
    highlight,
    selection,
    itemRadius,
    keyRadius,
    fieldFocusFill,
    fieldFocusBorder,
  ];
}
