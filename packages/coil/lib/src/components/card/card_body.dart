import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/card/card_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// Where a `CoilCard` puts its media.
enum CoilCardVariant {
  /// Media on top, full-bleed at 16:9; the text below.
  stacked,

  /// Media at the leading edge in a square; the text beside it and the
  /// actions at the trailing edge.
  inline,
}

/// A card's slots, laid out for its variant.
class CardBody extends StatelessWidget {
  /// Lays out a card's slots.
  const CardBody({
    required this.variant,
    required this.title,
    required this.description,
    required this.content,
    required this.media,
    required this.icon,
    required this.actions,
    required this.style,
    required this.metrics,
    required this.reserveEnd,
    super.key,
  });

  /// Where the media goes.
  final CoilCardVariant variant;

  /// The title.
  final Widget? title;

  /// The description.
  final Widget? description;

  /// The content under the header.
  final Widget? content;

  /// The media.
  final Widget? media;

  /// The icon, in a tinted tile.
  final Widget? icon;

  /// The card's buttons.
  final List<Widget> actions;

  /// The resolved style.
  final CoilCardStyle style;

  /// The card's metrics.
  final CoilMetrics metrics;

  /// Room at the header's end for the dismiss button.
  final double reserveEnd;

  @override
  Widget build(BuildContext context) {
    final pad = style.padding!;
    final gap = style.gap!;
    final header = _header();
    final actions = _actions();
    final content = this.content == null
        ? null
        : DefaultTextStyle(style: style.contentStyle!, child: this.content!);

    if (variant == CoilCardVariant.inline) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: media == null ? 0 : style.mediaExtent!,
        ),
        child: Row(
          children: [
            if (media case final media?)
              SizedBox.square(dimension: style.mediaExtent, child: media),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: Row(
                  spacing: gap,
                  children: [
                    if (icon case final icon? when media == null)
                      _Tile(style: style, metrics: metrics, child: icon),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: gap,
                        children: [?header, ?content],
                      ),
                    ),
                    ?actions,
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final text = EdgeInsets.symmetric(horizontal: pad);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (media case final media?)
          AspectRatio(aspectRatio: 16 / 9, child: media),
        SizedBox(height: pad),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: gap,
          children: [
            if (icon case final icon?)
              Padding(
                padding: text,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _Tile(style: style, metrics: metrics, child: icon),
                ),
              ),
            if (header != null) Padding(padding: text, child: header),
            if (content != null) Padding(padding: text, child: content),
            if (actions != null)
              Padding(
                padding: text,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: actions,
                ),
              ),
          ],
        ),
        SizedBox(height: pad),
      ],
    );
  }

  Widget? _header() {
    if (title == null && description == null) return null;
    return Padding(
      padding: EdgeInsetsDirectional.only(end: reserveEnd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: style.headerGap!,
        children: [
          if (title case final title?)
            DefaultTextStyle(style: style.titleStyle!, child: title),
          if (description case final description?)
            DefaultTextStyle(
              style: style.descriptionStyle!,
              child: description,
            ),
        ],
      ),
    );
  }

  Widget? _actions() {
    if (actions.isEmpty) return null;
    return CoilAdaptiveScope(
      size: CoilSize.compact,
      child: Wrap(
        spacing: style.actionSpacing!,
        runSpacing: style.actionSpacing!,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: actions,
      ),
    );
  }
}

/// The tinted tile behind a card's icon.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.style,
    required this.metrics,
    required this.child,
  });

  final CoilCardStyle style;
  final CoilMetrics metrics;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: style.tileExtent!,
        minHeight: style.tileExtent!,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: style.tile,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(
              CoilTheme.radiiOf(context).item,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(style.tilePadding!),
          child: IconTheme(
            data: IconThemeData(
              size: metrics.iconSize,
              applyTextScaling: true,
              color: style.titleStyle!.color,
            ),
            child: Center(widthFactor: 1, heightFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}

/// The dismiss ✕: a compact ghost icon button that fades in and out.
class CardDismissButton extends StatelessWidget {
  /// Creates the dismiss button.
  const CardDismissButton({
    required this.visible,
    required this.icon,
    required this.semanticLabel,
    required this.showMotion,
    required this.hideMotion,
    required this.onPressed,
    super.key,
  });

  /// Whether it shows.
  final bool visible;

  /// Replaces the drawn ✕.
  final Widget? icon;

  /// The name for assistive technology.
  final String semanticLabel;

  /// The fade in.
  final Motion showMotion;

  /// The fade out.
  final Motion hideMotion;

  /// Dismisses the card.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return MotionOpacity(
      opacity: visible ? 1 : 0,
      motion: visible ? showMotion : hideMotion,
      debugLabel: 'CoilCard dismiss',
      // Screen readers always reach it.
      alwaysIncludeSemantics: true,
      // Hidden, it stays focusable (focus reveals it) but never takes a
      // tap meant for the card.
      child: IgnorePointer(
        ignoring: !visible,
        child: CoilButton.icon(
          onPressed: onPressed,
          variant: CoilButtonVariant.ghost,
          size: CoilSize.compact,
          semanticLabel: semanticLabel,
          icon: icon ?? const CoilDrawnGlyph(CoilGlyph.cross),
        ),
      ),
    );
  }
}
