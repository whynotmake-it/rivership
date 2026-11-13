// Internal to CoilSlider; not exported.
// ignore_for_file: public_member_api_docs, use_key_in_widget_constructors

import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A label or value that turns foreground and semibold; a hidden semibold
/// copy reserves the width, so nothing shifts.
class CoilSliderText extends StatelessWidget {
  const CoilSliderText({
    required this.color,
    required this.bold,
    required this.style,
    required this.motion,
    required this.ghosts,
    this.text,
    this.child,
  });

  final Color color;
  final bool bold;
  final TextStyle style;
  final CoilMotion motion;

  /// Strings whose semibold widths the slot must fit; null reserves the
  /// semibold width of [child] itself.
  final Set<String>? ghosts;
  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final semibold = style.copyWith(
      fontVariations: CoilWeight.semibold.variations,
    );
    Widget content(TextStyle s) => child == null
        ? Text(text!, style: s, maxLines: 1, softWrap: false)
        : DefaultTextStyle(
            style: s,
            maxLines: 1,
            softWrap: false,
            child: child!,
          );
    return MotionBuilder<Color>(
      value: color,
      motion: motion.fade,
      converter: .colorRgb,
      debugLabel: 'Slider text color',
      builder: (context, color, _) => SingleMotionBuilder(
        value: bold ? CoilWeight.semibold.wght : 400,
        motion: motion.fade,
        debugLabel: 'Slider text weight',
        builder: (context, wght, _) => Stack(
          alignment: AlignmentDirectional.centerEnd,
          children: [
            if (ghosts != null)
              for (final g in ghosts!)
                ExcludeSemantics(
                  child: Opacity(
                    opacity: 0,
                    child: Text(g, style: semibold, maxLines: 1),
                  ),
                )
            else
              ExcludeSemantics(
                child: Opacity(opacity: 0, child: content(semibold)),
              ),
            content(
              style.copyWith(
                color: color,
                fontVariations: [
                  FontVariation('wght', wght),
                  FontVariation('opsz', 14 + (wght - 400) / 150 * 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
