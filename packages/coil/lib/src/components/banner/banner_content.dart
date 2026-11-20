import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/banner/banner_layout.dart';
import 'package:coil/src/components/banner/banner_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A banner's parts: [icon] text [actions] [✕]. The actions follow the
/// title when they fit beside it and move under the text when they don't,
/// or when there is a description.
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
    required this.stacked,
    required this.motion,
    required this.sizeMotion,
    required this.sizeExitMotion,
    required this.onDescriptionEnd,
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

  /// Replaces the dismiss button's ✕: the theme's [CoilIcons.close], or
  /// coil's drawn one.
  final Widget? dismissIcon;

  /// The dismiss button's name for assistive technology.
  final String dismissLabel;

  /// Whether the actions go under the text: while there is a description,
  /// and until a leaving one has closed.
  final bool stacked;

  /// The motion tokens the description's fade follows.
  final CoilMotion? motion;

  /// The room's and the size's motion growing.
  final Motion sizeMotion;

  /// The room's motion shrinking.
  final Motion sizeExitMotion;

  /// Called when a description that came or went has settled.
  final VoidCallback onDescriptionEnd;

  @override
  Widget build(BuildContext context) {
    final spacing = style.actionSpacing!;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DefaultTextStyle(style: style.titleStyle!, child: title),
        // Always there, so the text keeps its place in the tree.
        CoilPresentSlot(
          motion: motion,
          presenceMotion: sizeMotion,
          presenceExitMotion: sizeExitMotion,
          onEnd: onDescriptionEnd,
          child: switch (description) {
            final description? => CoilSizeSwitcher(
              sizeMotion: sizeMotion,
              motion: motion,
              contentKey: CoilSizeSwitcher.contentKeyOf(description),
              debugLabel: 'CoilBanner.description',
              child: DefaultTextStyle(
                style: style.descriptionStyle!,
                child: description,
              ),
            ),
            null => null,
          },
        ),
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

    final line = style.titleStyle!;
    return Padding(
      padding: EdgeInsets.all(style.padding!),
      child: BannerLayout(
        gap: style.gap!,
        actionSpacing: spacing,
        // A description makes the banner a block: the actions go under it.
        flow: stacked ? BannerFlow.stacked : BannerFlow.auto,
        icon: switch (icon) {
          final icon? => CoilLineBox(
            style: line,
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
          null => null,
        },
        line: CoilLineBox(style: line, child: const SizedBox.shrink()),
        text: text,
        actions: buttons,
        dismiss: switch (onDismissRequested) {
          final dismiss? => CoilLineBox(
            style: line,
            child: CoilButton.icon(
              onPressed: dismiss,
              variant: CoilButtonVariant.ghost,
              size: CoilSize.compact,
              semanticLabel: dismissLabel,
              icon: dismissIcon ?? const CoilIcon(CoilIconRole.close),
            ),
          ),
          null => null,
        },
      ),
    );
  }
}
