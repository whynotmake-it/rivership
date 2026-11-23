import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';

/// A list row for pages and sheets, laid out like coil's touch rows
/// (DESIGN 13.1): [leading], a label with an optional [description] under
/// it, and a trailing value, check or chevron.
///
/// Rows are always touch rows, 44 high with one line and 60 with two,
/// whatever the tier. Text starts 16 in from the row's edges, where a
/// sheet's title starts. There are no separators. With [onPressed] the
/// whole row is one button, lit by hover and press.
class DemoRow extends StatelessWidget {
  /// Creates a row.
  const DemoRow({
    required this.label,
    super.key,
    this.description,
    this.leading,
    this.trailing,
    this.chevron = false,
    this.checked,
    this.onPressed,
    this.semanticLabel,
  });

  /// The row's text, usually a [Text].
  final Widget label;

  /// A caption under [label], muted.
  final Widget? description;

  /// A glyph or avatar before the label. Glyphs take the row's icon size
  /// and color from [IconTheme].
  final Widget? leading;

  /// A value, badge or other widget at the end of the row.
  final Widget? trailing;

  /// Whether a chevron ends the row.
  final bool chevron;

  /// A single-choice mark at the end: a check when true, an empty slot of
  /// the same width when false, nothing when null.
  final bool? checked;

  /// Makes the whole row a button. Null leaves it static.
  final VoidCallback? onPressed;

  /// Names the button for screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => CoilAdaptiveScope(
    tier: CoilTier.touch,
    size: CoilSize.regular,
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final metrics = CoilTheme.metricsOf(context);
    final radii = CoilTheme.radiiOf(context);
    final text = CoilTheme.textOf(context);
    final twoLines = description != null;
    final minHeight = twoLines
        ? metrics.controlHeight + 16
        : metrics.controlHeight;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radii.item),
    );

    Widget content({required Color fill, required bool focused}) {
      final glyph = IconThemeData(
        size: metrics.iconSize,
        color: colors.foreground,
      );
      final end = <Widget>[
        if (trailing != null)
          DefaultTextStyle.merge(style: text.muted.body, child: trailing!),
        if (chevron)
          IconTheme(
            data: glyph.copyWith(color: colors.mutedForeground),
            child: const CoilIcon(CoilIconRole.chevronEnd),
          ),
        if (checked != null)
          SizedBox.square(
            dimension: metrics.iconSize,
            child: checked!
                ? IconTheme(
                    data: glyph,
                    child: const CoilIcon(CoilIconRole.check),
                  )
                : null,
          ),
      ];
      return CoilFocusRing(
        visible: focused,
        borderRadius: BorderRadius.circular(radii.item),
        child: DecoratedBox(
          decoration: ShapeDecoration(color: fill, shape: shape),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.itemPaddingX,
                vertical: twoLines ? 8 : 0,
              ),
              child: Row(
                spacing: metrics.gap,
                children: [
                  if (leading != null) IconTheme(data: glyph, child: leading!),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DefaultTextStyle.merge(
                          style: text.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          child: label,
                        ),
                        if (description != null)
                          DefaultTextStyle.merge(
                            style: text.muted.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            child: description!,
                          ),
                      ],
                    ),
                  ),
                  ...end,
                ],
              ),
            ),
          ),
        ),
      );
    }

    final row = onPressed == null
        ? content(fill: const Color(0x00000000), focused: false)
        : CoilInteraction(
            onPressed: onPressed,
            minHitTarget: math.min(metrics.minHitTarget, minHeight),
            builder: (context, states, _) => content(
              fill: states.contains(WidgetState.pressed)
                  ? colors.active
                  : states.contains(WidgetState.hovered)
                  ? colors.hover
                  : const Color(0x00000000),
              focused: states.contains(WidgetState.focused),
            ),
          );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.popupInset),
      child: Semantics(
        container: true,
        button: onPressed != null,
        label: semanticLabel,
        child: row,
      ),
    );
  }
}
