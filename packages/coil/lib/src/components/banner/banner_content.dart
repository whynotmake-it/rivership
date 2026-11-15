import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/banner/banner_style.dart';
import 'package:flutter/widgets.dart';

/// A banner's layout: [icon] text [actions] [✕]. With a description, the
/// actions move under the text.
class BannerContent extends StatelessWidget {
  /// Lays out a banner's parts.
  const BannerContent({
    required this.style,
    required this.title,
    required this.description,
    required this.icon,
    required this.actions,
    required this.onDismissRequested,
    required this.dismissIcon,
    required this.dismissLabel,
    super.key,
  });

  /// The resolved style.
  final CoilBannerStyle style;

  /// The message.
  final Widget title;

  /// More detail under the title.
  final Widget? description;

  /// The status glyph.
  final Widget? icon;

  /// The banner's buttons.
  final List<Widget> actions;

  /// Shows the dismiss button when not null.
  final VoidCallback? onDismissRequested;

  /// Replaces the dismiss button's drawn ✕.
  final Widget? dismissIcon;

  /// The dismiss button's name for assistive technology.
  final String dismissLabel;

  @override
  Widget build(BuildContext context) {
    final gap = style.gap!;
    final spacing = style.actionSpacing!;
    final stacked = description != null;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DefaultTextStyle(style: style.titleStyle!, child: title),
        if (description case final description?)
          DefaultTextStyle(style: style.descriptionStyle!, child: description),
      ],
    );
    final buttons = actions.isEmpty
        ? null
        : CoilAdaptiveScope(
            size: CoilSize.compact,
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: actions,
            ),
          );

    return Padding(
      padding: EdgeInsets.all(style.padding!),
      child: Row(
        // Without a description the title is usually one line, and
        // everything centers on it.
        crossAxisAlignment: stacked
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        spacing: gap,
        children: [
          if (icon case final icon?)
            CoilLineBox(
              style: style.titleStyle!,
              child: ExcludeSemantics(
                child: IconTheme(
                  data: IconThemeData(
                    size: style.iconSize,
                    color: style.statusColor,
                    applyTextScaling: true,
                  ),
                  child: icon,
                ),
              ),
            ),
          Expanded(
            child: stacked && buttons != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: spacing,
                    children: [text, buttons],
                  )
                : text,
          ),
          if (!stacked) ?buttons,
          if (onDismissRequested case final dismiss?)
            CoilLineBox(
              style: style.titleStyle!,
              child: CoilButton.icon(
                onPressed: dismiss,
                variant: CoilButtonVariant.ghost,
                size: CoilSize.compact,
                semanticLabel: dismissLabel,
                icon: dismissIcon ?? const CoilDrawnGlyph(CoilGlyph.cross),
              ),
            ),
        ],
      ),
    );
  }
}
