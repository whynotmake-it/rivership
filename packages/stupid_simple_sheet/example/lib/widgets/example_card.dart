import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';

/// Provides a category prefix (e.g. `'RCP'`, `'ADV'`) to descendant
/// [ExampleCard]s so they can derive their badge label from their index
/// alone (e.g. `RCP.003`).
///
/// Wrap a group of cards in a [CardSection] and each card only needs its
/// 0-based [ExampleCard.index] to display the correct label.
class CardSection extends InheritedWidget {
  const CardSection({
    required this.prefix,
    required super.child,
    super.key,
  });

  /// A short uppercase abbreviation, e.g. `'RCP'`, `'PLY'`, `'PRE'`, `'ADV'`.
  final String prefix;

  static CardSection? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CardSection>();

  /// Formats a badge label like `RCP.003` from the [prefix] and a 0-based
  /// [index].
  String labelFor(int index) =>
      '$prefix.${(index + 1).toString().padLeft(3, '0')}';

  @override
  bool updateShouldNotify(CardSection oldWidget) => prefix != oldWidget.prefix;
}

/// A tappable recipe card with a tall preview area, a floating pill badge,
/// a title + description, and a mono code hint.
///
/// Matches the "recipe card" design: rounded-24, 12px padding, tall preview,
/// pill badge overlapping the preview bottom, and a text footer.
///
/// Each card has a subtle random rotation at rest that straightens on press,
/// giving the page a scattered, tactile feel.
///
/// Set [index] and wrap the card in a [CardSection] to auto-generate the
/// category badge (e.g. `RCP.001`). Alternatively pass [categoryId] directly.
class ExampleCard extends StatefulWidget {
  const ExampleCard({
    required this.preview,
    required this.title,
    required this.description,
    required this.onTap,
    this.pillLabel,
    this.pillColor,
    this.pillIcon,
    this.codeHint,
    this.index,
    this.categoryId,
    super.key,
  });

  /// A widget rendered inside the preview area.
  final Widget preview;

  /// The card title.
  final String title;

  /// A short description shown below the title.
  final String description;

  /// Called when the card is tapped.
  final VoidCallback onTap;

  /// Label for the floating pill badge (e.g. "Core Pattern").
  final String? pillLabel;

  /// Accent color for the pill icon.
  final Color? pillColor;

  /// Icon shown in the pill badge.
  final IconData? pillIcon;

  /// Mono-spaced code hint shown below the description.
  final String? codeHint;

  /// 0-based index of this card within its [CardSection].
  ///
  /// Used together with [CardSection] to derive the category badge
  /// (e.g. index 2 inside a `'RCP'` section → `RCP.003`).
  /// Ignored when [categoryId] is set explicitly.
  final int? index;

  /// Explicit system ID shown in the preview corner (e.g. "RCP.001").
  ///
  /// When `null` and [index] is set, the label is derived from the nearest
  /// [CardSection].
  final String? categoryId;

  @override
  State<ExampleCard> createState() => _ExampleCardState();
}

final _cardRandom = math.Random();

class _ExampleCardState extends State<ExampleCard>
    with SingleTickerProviderStateMixin {
  /// Random resting rotation in radians, generated once per card instance.
  /// Range: roughly -2 to +2 degrees.
  late final double _restingRotation =
      (_cardRandom.nextDouble() * 2 - 1) * math.pi / 180;

  bool _isPressed = false;

  void _onTapDown(TapDownDetails _) => setState(() {
        _isPressed = true;
      });

  void _onTapUp(TapUpDetails _) {
    setState(() {
      _isPressed = false;
    });
    widget.onTap();
  }

  void _onTapCancel() => setState(() {
        _isPressed = false;
      });

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);

    return MotionBuilder<(double, double)>(
      value: _isPressed ? (.97, 0.0) : (1, _restingRotation),
      motion: CupertinoMotion.snappy(
        duration: const Duration(milliseconds: 250),
      ),
      converter: MotionConverter.custom(
        normalize: (value) => [value.$1, value.$2],
        denormalize: (values) => (values[0], values[1]),
      ),
      builder: (context, value, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scaleByDouble(value.$1, value.$1, 1, 1)
          ..rotateZ(value.$2),
        child: child,
      ),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(ExampleTheme.cardRadius),
            border: Border.all(color: t.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: t.cardShadow,
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: t.cardShadow.withValues(alpha: .02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Preview area with pill badge
                _buildPreview(t),

                const SizedBox(height: 20),

                // Footer: title + description + code hint
                _buildFooter(t),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(ExampleTheme t) {
    final categoryLabel = widget.categoryId ??
        (widget.index != null
            ? CardSection.maybeOf(context)?.labelFor(widget.index!)
            : null);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Preview container
        ClipRRect(
          borderRadius: BorderRadius.circular(ExampleTheme.previewRadius),
          child: CustomPaint(
            foregroundPainter: _InnerShadowPainter(
              borderRadius: ExampleTheme.previewRadius,
              shadowColor: t.innerShadowColor,
              shadowBlur: 8,
              shadowOffset: Offset.zero,
              borderColor: t.innerBorderColor,
            ),
            child: Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: t.previewBg,
                borderRadius: BorderRadius.circular(ExampleTheme.previewRadius),
              ),
              child: Stack(
                children: [
                  // The preview content
                  Positioned.fill(child: widget.preview),

                  // Category ID badge in top-right
                  if (categoryLabel != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: t.surface.withValues(alpha: .8),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: t.pillBorder),
                          boxShadow: [
                            BoxShadow(
                              color: t.pillShadow,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          categoryLabel,
                          textHeightBehavior: TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                            leadingDistribution: TextLeadingDistribution.even,
                          ),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: t.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Floating pill badge
        if (widget.pillLabel != null)
          Positioned(
            bottom: -14,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                      vertical: 6,
                    ) +
                    EdgeInsets.only(
                      left: widget.pillIcon != null ? 12 : 14,
                      right: 14,
                    ),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: t.pillBorder),
                  boxShadow: [
                    BoxShadow(
                      color: t.pillShadow,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    if (widget.pillIcon != null) ...[
                      Icon(
                        widget.pillIcon,
                        size: 14,
                        color: widget.pillColor ?? t.accent,
                      ),
                    ],
                    Text(
                      widget.pillLabel!,
                      textHeightBehavior: TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                        leadingDistribution: TextLeadingDistribution.even,
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFooter(ExampleTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.description,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: t.textSecondary,
            ),
          ),
          if (widget.codeHint != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.codeHint!,
              style: TextStyle(
                fontSize: 10,
                color: t.textTertiary,
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: const ['monospace', 'Menlo'],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Paints an inset shadow and a 1px border inside a rounded rectangle.
class _InnerShadowPainter extends CustomPainter {
  _InnerShadowPainter({
    required this.borderRadius,
    required this.shadowColor,
    required this.shadowBlur,
    required this.shadowOffset,
    required this.borderColor,
  });

  final double borderRadius;
  final Color shadowColor;
  final double shadowBlur;
  final Offset shadowOffset;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    canvas.save();
    canvas.clipRRect(rrect);

    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur);

    final outer = rect.inflate(shadowBlur * 2);
    final hole = Path()..addRRect(rrect);
    final frame = Path()..addRect(outer);
    final shadowPath =
        Path.combine(PathOperation.difference, frame, hole).shift(shadowOffset);

    canvas.drawPath(shadowPath, shadowPaint);
    canvas.restore();

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(rrect.deflate(0.5), borderPaint);
  }

  @override
  bool shouldRepaint(_InnerShadowPainter oldDelegate) =>
      borderRadius != oldDelegate.borderRadius ||
      shadowColor != oldDelegate.shadowColor ||
      shadowBlur != oldDelegate.shadowBlur ||
      shadowOffset != oldDelegate.shadowOffset ||
      borderColor != oldDelegate.borderColor;
}
