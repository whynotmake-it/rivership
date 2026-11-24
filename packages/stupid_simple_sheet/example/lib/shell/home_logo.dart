import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_logo.dart';

/// The package logo at the top of the home page.
///
/// With [onPressed] it is a link back to the gallery's landing page: lit by
/// hover and press, with coil's focus ring for the keyboard, and Enter and
/// Space activate it. Without it the logo is decorative: not focusable, no
/// hover, hidden from screen readers.
class HomeLogo extends StatelessWidget {
  /// Creates the logo.
  const HomeLogo({super.key, this.onPressed});

  /// The logo's side, in logical pixels.
  static const size = 40.0;

  /// Space between the logo and the title under it.
  static const gap = 16.0;

  /// Called when the logo is activated. Null leaves it inert.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    // The logo's palette follows the platform brightness; follow coil's.
    final media = MediaQuery.of(context);
    final logo = MediaQuery(
      data: media.copyWith(platformBrightness: theme.brightness),
      child: const SheetLogo(size: size),
    );
    if (onPressed == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ExcludeSemantics(child: logo),
      );
    }

    final colors = theme.colors;
    final radii = CoilTheme.radiiOf(context);
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radii.item),
    );
    final hitTarget = math.max(size, CoilTheme.metricsOf(context).minHitTarget);
    // A larger hit target centers the logo in it; pull it back so the logo's
    // box keeps the title's left edge.
    final extra = (hitTarget - size) / 2;
    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.translate(
        offset: Offset(-extra, 0),
        child: Semantics(
          link: true,
          label: 'Back to all packages',
          excludeSemantics: true,
          child: CoilInteraction(
            onPressed: onPressed,
            minHitTarget: hitTarget,
            excludeFromSemantics: true,
            builder: (context, states, _) => CoilFocusRing(
              visible: states.contains(WidgetState.focused),
              borderRadius: BorderRadius.circular(radii.item),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: shape,
                  color: states.contains(WidgetState.pressed)
                      ? colors.active
                      : states.contains(WidgetState.hovered)
                      ? colors.hover
                      : const Color(0x00000000),
                ),
                child: logo,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
