import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/ask_user_questions/ask_user_questions_style.dart';
import 'package:coil/src/components/ask_user_questions/question.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The motions a row animates with, resolved once per step.
@immutable
class QuestionRowMotions {
  /// Bundles the motions.
  const QuestionRowMotions({
    required this.label,
    required this.hint,
    required this.hintExit,
    required this.press,
    required this.release,
  });

  /// Label color and weight, and key fills.
  final Motion label;

  /// The submit arrow appearing over a key.
  final Motion hint;

  /// The submit arrow leaving.
  final Motion hintExit;

  /// The touch press fill appearing.
  final Motion press;

  /// The touch press fill leaving.
  final Motion release;
}

/// One option row: the label (and description), with the number key at
/// one edge. The row's selected block, hover highlight and focus ring are
/// painted by the step's motion layer behind it.
class QuestionOptionRow<T> extends StatelessWidget {
  /// Creates a row.
  const QuestionOptionRow({
    required this.option,
    required this.number,
    required this.kind,
    required this.layout,
    required this.keyPosition,
    required this.selected,
    required this.showKeys,
    required this.look,
    required this.motions,
    required this.focusNode,
    required this.statesController,
    required this.onPressed,
    super.key,
    this.size,
  });

  /// The option.
  final CoilQuestionOption<T> option;

  /// Its number key, from 1.
  final int number;

  /// Single or multiple choice.
  final CoilQuestionKind kind;

  /// Where the description goes.
  final CoilQuestionLayout layout;

  /// Which edge the key sits on.
  final CoilQuestionKeyPosition keyPosition;

  /// Whether the option is picked.
  final bool selected;

  /// Whether number keys show (pointer tier). On touch only a picked
  /// multiple-choice row shows a check.
  final bool showKeys;

  /// The resolved style.
  final CoilAskUserQuestionsStyle look;

  /// The motions.
  final QuestionRowMotions motions;

  /// The row's focus node, from the step.
  final FocusNode focusNode;

  /// The row's states, from the step.
  final WidgetStatesController statesController;

  /// Picks or toggles the option.
  final VoidCallback onPressed;

  /// Pins the row to one size step.
  final CoilSize? size;

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context, size: size);
    final single = kind == CoilQuestionKind.single;
    final lit = CoilHoverItem.isActive(context, number - 1);
    // A lit single-choice row offers its submit arrow (pointer only: a
    // finger never lights a row).
    final hint = single && showKeys && lit;
    final description = option.description;
    final semanticLabel = description == null
        ? option.label
        : '${option.label}, $description';
    final stacked = layout == CoilQuestionLayout.stacked;
    // On touch a single-choice row has no key slot at all.
    final hasKey = showKeys || !single;

    Widget keySlot({required bool withHint}) => QuestionKey(
      number: number,
      kind: kind,
      filled: selected,
      showKeys: showKeys,
      hint: withHint && hint,
      look: look,
      motions: motions,
      lineStyle: look.labelStyle!,
    );

    return Semantics(
      container: true,
      enabled: true,
      inMutuallyExclusiveGroup: single,
      checked: selected,
      label: semanticLabel,
      child: CoilChoiceItem(
        size: size,
        onPressed: onPressed,
        focusNode: focusNode,
        statesController: statesController,
        pressFill: look.selection!,
        radius: look.itemRadius!,
        pressMotion: motions.press,
        releaseMotion: motions.release,
        builder: (context, _, _) => ConstrainedBox(
          constraints: BoxConstraints(minHeight: metrics.controlHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.controlPaddingX,
              vertical: metrics.controlPaddingY(metrics.body),
            ),
            child: Row(
              crossAxisAlignment: stacked
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              spacing: keyPosition == CoilQuestionKeyPosition.start
                  ? metrics.gap
                  : metrics.gap + 4,
              children: [
                if (hasKey && keyPosition == CoilQuestionKeyPosition.start)
                  keySlot(withHint: false),
                Expanded(
                  child: ExcludeSemantics(
                    child: _Body(
                      option: option,
                      selected: selected,
                      stacked: stacked,
                      look: look,
                      metrics: metrics,
                      motion: motions.label,
                    ),
                  ),
                ),
                if (hasKey && keyPosition == CoilQuestionKeyPosition.end)
                  keySlot(withHint: true)
                else if (single && showKeys)
                  // The key stays at the start; the arrow gets its own slot.
                  QuestionKey.arrowOnly(
                    hint: hint,
                    look: look,
                    motions: motions,
                    lineStyle: look.labelStyle!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The label, semibold when picked, and the description.
class _Body<T> extends StatelessWidget {
  const _Body({
    required this.option,
    required this.selected,
    required this.stacked,
    required this.look,
    required this.metrics,
    required this.motion,
  });

  final CoilQuestionOption<T> option;
  final bool selected;
  final bool stacked;
  final CoilAskUserQuestionsStyle look;
  final CoilMetrics metrics;
  final Motion motion;

  @override
  Widget build(BuildContext context) {
    final base = look.labelStyle!.copyWith(color: look.label);
    final description = option.description;
    return SingleMotionBuilder(
      value: selected ? 1 : 0,
      motion: motion,
      debugLabel: 'CoilAskUserQuestions label weight',
      builder: (context, t, _) {
        final weighted = base.copyWith(
          fontVariations: [
            FontVariation('wght', _lerp(_normal.wght, _semibold.wght, t)),
            FontVariation('opsz', _lerp(_normal.opsz, _semibold.opsz, t)),
          ],
        );
        final ghost = base.copyWith(fontVariations: _semibold.variations);
        Widget label(TextStyle style, {required bool wrap}) => DefaultTextStyle(
          style: style,
          maxLines: wrap ? null : 1,
          overflow: wrap ? TextOverflow.clip : TextOverflow.ellipsis,
          child: option.child ?? Text(option.label),
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 2,
            children: [
              // A hidden semibold copy holds the label's widest wrap, so
              // picking a row never reflows it.
              Stack(
                children: [
                  Opacity(opacity: 0, child: label(ghost, wrap: true)),
                  label(weighted, wrap: true),
                ],
              ),
              if (description != null)
                Text(
                  description,
                  style: CoilTheme.of(
                    context,
                  ).typography.style(metrics.caption, color: look.description),
                ),
            ],
          );
        }
        if (option.child != null) {
          // A custom label can't join a text span: the description follows
          // it on the same baseline.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Stack(
                  children: [
                    Opacity(opacity: 0, child: label(ghost, wrap: false)),
                    label(weighted, wrap: false),
                  ],
                ),
              ),
              if (description != null)
                Flexible(
                  child: Text(
                    ' $description',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: look.descriptionStyle!.copyWith(
                      color: look.description,
                    ),
                  ),
                ),
            ],
          );
        }
        InlineSpan line(TextStyle label) => TextSpan(
          children: [
            TextSpan(text: option.label, style: label),
            if (description != null)
              TextSpan(
                text: ' $description',
                style: look.descriptionStyle!.copyWith(color: look.description),
              ),
          ],
        );
        return Stack(
          children: [
            Opacity(
              opacity: 0,
              child: Text.rich(
                line(ghost),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text.rich(
              line(weighted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}

const _normal = CoilWeight.normal;
const _semibold = CoilWeight.semibold;

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// A row's number key, centered on the first line of the label.
///
/// On pointer: the number (single choice), or the number in a small box
/// that fills when picked (multiple choice). Over a lit single-choice row a
/// filled arrow replaces it. On touch there are no keys; a picked
/// multiple-choice row shows a check.
class QuestionKey extends StatelessWidget {
  /// Creates a key.
  const QuestionKey({
    required int this.number,
    required CoilQuestionKind this.kind,
    required this.filled,
    required this.showKeys,
    required this.hint,
    required this.look,
    required this.motions,
    required this.lineStyle,
    super.key,
  });

  /// Only the submit arrow, for rows whose key sits at the start.
  const QuestionKey.arrowOnly({
    required this.hint,
    required this.look,
    required this.motions,
    required this.lineStyle,
    super.key,
  }) : number = null,
       kind = null,
       filled = false,
       showKeys = true;

  /// The number shown, from 1. Null for [QuestionKey.arrowOnly].
  final int? number;

  /// Single or multiple choice. Null for [QuestionKey.arrowOnly].
  final CoilQuestionKind? kind;

  /// Whether the key is picked.
  final bool filled;

  /// Whether keys show at all (pointer tier).
  final bool showKeys;

  /// Whether the submit arrow covers the key.
  final bool hint;

  /// The resolved style.
  final CoilAskUserQuestionsStyle look;

  /// The motions.
  final QuestionRowMotions motions;

  /// The style whose first line the key centers on.
  final TextStyle lineStyle;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final metrics = CoilTheme.metricsOf(context);
    final compact = metrics.size == CoilSize.compact;
    // Glyph-like boxes scale with text (DESIGN §10).
    final extent = scaler.scale(compact ? 18 : 20);
    final multiple = kind == CoilQuestionKind.multiple;

    if (!showKeys) {
      // Touch: no number keys. A multiple-choice row keeps a check slot,
      // which keeps its width when empty.
      if (!multiple) return const SizedBox.shrink();
      return CoilLineBox(
        style: lineStyle,
        child: IconTheme(
          data: IconThemeData(
            size: metrics.iconSize,
            applyTextScaling: true,
            color: look.keySelected,
            weight: CoilIconWeight.emphasis,
          ),
          child: SingleMotionBuilder(
            value: filled ? 1 : 0,
            motion: motions.label,
            debugLabel: 'CoilAskUserQuestions check',
            builder: (context, t, _) =>
                CoilDrawnGlyph(CoilGlyph.check, progress: t),
          ),
        ),
      );
    }

    final number = this.number;
    final key = number == null
        ? SizedBox.square(dimension: extent)
        : MotionBuilder<Color>(
            value: filled
                ? (multiple ? look.keySelectedLabel! : look.keySelected!)
                : look.keyColor!,
            converter: MotionConverter.colorRgb,
            motion: motions.label,
            debugLabel: 'CoilAskUserQuestions key',
            builder: (context, color, _) => MotionBuilder<Color>(
              value: multiple && filled
                  ? look.keySelected!
                  : look.keySelected!.withValues(alpha: 0),
              converter: MotionConverter.colorRgb,
              motion: motions.label,
              debugLabel: 'CoilAskUserQuestions key fill',
              builder: (context, fill, _) => Container(
                width: extent,
                height: extent,
                alignment: Alignment.center,
                decoration: multiple
                    ? ShapeDecoration(
                        color: fill,
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(
                            scaler.scale(look.keyRadius!),
                          ),
                          side: filled
                              ? BorderSide.none
                              : BorderSide(color: look.keyBorder!),
                        ),
                      )
                    : null,
                child: Text(
                  '$number',
                  style: look.keyStyle!.copyWith(
                    color: color,
                    fontVariations: filled
                        ? CoilWeight.semibold.variations
                        : CoilWeight.normal.variations,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          );

    // The arrow is drawn 4 past the key on each side, over the row's
    // padding, so it reads as a button the size of a compact control.
    final arrowExtent = extent + 8;
    return ExcludeSemantics(
      child: CoilLineBox(
        style: lineStyle,
        child: SingleMotionBuilder(
          value: hint ? 1 : 0,
          motion: hint ? motions.hint : motions.hintExit,
          debugLabel: 'CoilAskUserQuestions hint',
          builder: (context, t, _) => Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Opacity(opacity: (1 - t).clamp(0.0, 1.0), child: key),
              if (t > 0)
                Positioned(
                  left: -4,
                  top: -4,
                  right: -4,
                  bottom: -4,
                  child: Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * t,
                      child: Container(
                        width: arrowExtent,
                        height: arrowExtent,
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: look.keySelected,
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(
                              look.itemRadius!,
                            ),
                          ),
                        ),
                        child: IconTheme(
                          data: IconThemeData(
                            size: compact ? 12 : 14,
                            applyTextScaling: true,
                            color: look.keySelectedLabel,
                            weight: CoilIconWeight.emphasis,
                          ),
                          child: const CoilDrawnGlyph(CoilGlyph.chevronEnd),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
