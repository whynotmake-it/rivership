import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:flutter/widgets.dart';

/// A square preview of a file: [image] cropped to fill, or, until it loads
/// and for files without one, [placeholder] on a muted tile.
///
/// [name] is what screen readers announce. With [onRemove], a small remove
/// button sits on the top end corner, as for files attached to a message.
///
/// Rendering a preview (a PDF's first page, a video frame) is the app's
/// job: pass the result as [image].
class CoilFileThumbnail extends StatelessWidget {
  /// Creates a file thumbnail.
  const CoilFileThumbnail({
    required this.name,
    super.key,
    this.image,
    this.placeholder,
    this.size = 56,
    this.onRemove,
    this.removeLabel = 'Remove',
  });

  /// The file's name, for screen readers.
  final String name;

  /// The preview.
  final ImageProvider? image;

  /// Shown without a preview; the name's extension when null.
  final Widget? placeholder;

  /// The side length.
  final double size;

  /// Shows a remove button that calls this.
  final VoidCallback? onRemove;

  /// The remove button's label for screen readers.
  final String removeLabel;

  /// The extension of [name], upper-cased, like "PDF".
  String get _extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 || dot == name.length - 1
        ? ''
        : name.substring(dot + 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final colors = theme.colors;
    final radius = BorderRadius.circular(theme.shape.radii(metrics.tier).item);
    final fallback = Center(
      child: IconTheme(
        data: IconThemeData(
          size: metrics.iconSize,
          applyTextScaling: true,
          color: colors.mutedForeground,
        ),
        child: DefaultTextStyle(
          style: theme.typography.style(
            metrics.caption,
            weight: CoilWeight.semibold,
            color: colors.mutedForeground,
          ),
          maxLines: 1,
          child: placeholder ?? Text(_extension),
        ),
      ),
    );
    final tile = Semantics(
      image: image != null,
      label: name,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.muted,
            shape: RoundedSuperellipseBorder(
              borderRadius: radius,
              side: BorderSide(color: colors.border),
            ),
          ),
          child: ClipRSuperellipse(
            borderRadius: radius,
            child: switch (image) {
              null => ExcludeSemantics(child: fallback),
              final image => Image(
                image: image,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                frameBuilder: (context, child, frame, synchronous) =>
                    frame == null && !synchronous ? fallback : child,
                errorBuilder: (context, error, stack) => fallback,
              ),
            },
          ),
        ),
      ),
    );
    final onRemove = this.onRemove;
    if (onRemove == null) return tile;
    // The dot's center sits 4 inside the corner; a finger's larger target
    // grows around it.
    final target = metrics.tier == CoilTier.touch ? 44.0 : 20.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        PositionedDirectional(
          top: 4 - target / 2,
          end: 4 - target / 2,
          child: _RemoveButton(onPressed: onRemove, label: removeLabel),
        ),
      ],
    );
  }
}

/// A small round button with a cross, in the foreground color.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final touch = CoilTheme.tierOf(context) == CoilTier.touch;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: CoilInteraction(
        onPressed: onPressed,
        excludeFromSemantics: true,
        // A finger gets a 44 target around the same dot.
        minHitTarget: touch ? 44 : 0,
        builder: (context, states, _) => DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.foreground,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: colors.background, width: 2),
            ),
          ),
          child: SizedBox.square(
            dimension: 20,
            child: IconTheme(
              data: IconThemeData(size: 14, color: colors.background),
              child: const CoilDrawnGlyph(CoilGlyph.cross),
            ),
          ),
        ),
      ),
    );
  }
}
