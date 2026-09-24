import 'dart:math' as math;

import 'package:example_design/src/example_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';

/// Provides a category prefix (e.g. `'EVD'`, `'CMP'`) to descendant
/// [ExampleCard]s so they can derive their badge label from their index alone
/// (e.g. `EVD.003`).
class CardSection extends InheritedWidget {
  const CardSection({
    required this.prefix,
    required super.child,
    super.key,
  });

  /// A short uppercase abbreviation, e.g. `'CNT'`, `'EVD'`, `'CMP'`, `'GST'`.
  final String prefix;

  static CardSection? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CardSection>();

  /// Formats a badge label like `EVD.003` from the [prefix] and a 0-based
  /// [index].
  String labelFor(int index) =>
      '$prefix.${(index + 1).toString().padLeft(3, '0')}';

  @override
  bool updateShouldNotify(CardSection oldWidget) => prefix != oldWidget.prefix;
}

/// A tappable example card with a tall preview, a neutral pill badge, and a
/// title + description with an optional mono code hint.
///
/// Each card rests at a subtle random rotation that straightens on press,
/// giving the overview a playful, scattered, tactile feel.
class ExampleCard extends StatefulWidget {
  const ExampleCard({
    required this.preview,
    required this.title,
    required this.description,
    required this.onTap,
    this.pillLabel,
    this.pillIcon,
    this.pillColor,
    this.codeHint,
    this.index,
    this.categoryId,
    super.key,
  });

  final Widget preview;
  final String title;
  final String description;
  final VoidCallback onTap;
  final String? pillLabel;
  final IconData? pillIcon;

  /// Deprecated: the Dia system is monochrome, so the pill is always neutral.
  /// Retained for source compatibility with older example apps.
  final Color? pillColor;
  final String? codeHint;
  final int? index;
  final String? categoryId;

  @override
  State<ExampleCard> createState() => _ExampleCardState();
}

final _cardRandom = math.Random();

class _ExampleCardState extends State<ExampleCard> {
  late final double _restingRotation =
      (_cardRandom.nextDouble() * 2 - 1) * math.pi / 180;

  bool _isPressed = false;

  void _onTapDown(TapDownDetails _) => setState(() => _isPressed = true);

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _onTapCancel() => setState(() => _isPressed = false);

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);

    return MotionBuilder<(double, double)>(
      value: _isPressed ? (.97, 0) : (1, _restingRotation),
      motion: const CupertinoMotion.snappy(
        duration: Duration(milliseconds: 250),
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.surfaceSolid,
            borderRadius: BorderRadius.circular(ExampleTheme.cardRadius),
            border: Border.all(color: t.border),
            boxShadow: t.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPreview(t),
                const SizedBox(height: 20),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(ExampleTheme.previewRadius),
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: t.fog,
              borderRadius: BorderRadius.circular(ExampleTheme.previewRadius),
              border: Border.all(color: t.border),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: widget.preview),
                if (categoryLabel != null)
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Text(
                      categoryLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: t.textTertiary,
                        fontFamily: 'JetBrains Mono',
                        fontFamilyFallback: const ['monospace', 'Menlo'],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (widget.pillLabel != null)
          Positioned(
            bottom: -13,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  widget.pillIcon != null ? 10 : 14,
                  6,
                  14,
                  6,
                ),
                decoration: BoxDecoration(
                  color: t.surfaceSolid,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: t.border),
                  boxShadow: t.hairlineShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.pillIcon != null) ...[
                      Icon(
                        widget.pillIcon,
                        size: 13,
                        color: t.textSecondary,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      widget.pillLabel!,
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
              fontWeight: FontWeight.w500,
              letterSpacing: -0.3,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            widget.description,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: t.textSecondary,
            ),
          ),
          if (widget.codeHint != null) ...[
            const SizedBox(height: 8),
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
