import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';

/// The type roles from DESIGN.md §3.1.
///
/// coil's [CoilMetrics] only carries the roles its built components use
/// (body, field, caption), so the catalog keeps the full table here for its
/// own headings and for the type scale page.
enum TypeRole {
  display(
    'display',
    CoilWeight.bold,
    CoilTypeStep(28, 34),
    CoilTypeStep(24, 30),
    CoilTypeStep(28, 34),
    CoilTypeStep(28, 34),
  ),
  title(
    'title',
    CoilWeight.semibold,
    CoilTypeStep(16, 22),
    CoilTypeStep(14, 20),
    CoilTypeStep(17, 22),
    CoilTypeStep(16, 22),
  ),
  subtitle(
    'subtitle',
    CoilWeight.normal,
    CoilTypeStep(14, 20),
    CoilTypeStep(13, 18),
    CoilTypeStep(16, 22),
    CoilTypeStep(15, 20),
  ),
  body(
    'body',
    CoilWeight.normal,
    CoilTypeStep(13, 20),
    CoilTypeStep(12, 18),
    CoilTypeStep(16, 22),
    CoilTypeStep(14, 20),
  ),
  field(
    'field',
    CoilWeight.normal,
    CoilTypeStep(13, 20),
    CoilTypeStep(12, 18),
    CoilTypeStep(16, 22),
    CoilTypeStep(16, 20),
  ),
  caption(
    'caption',
    CoilWeight.normal,
    CoilTypeStep(12, 16),
    CoilTypeStep(11, 14),
    CoilTypeStep(13, 18),
    CoilTypeStep(12, 16),
  ),
  micro(
    'micro',
    CoilWeight.normal,
    CoilTypeStep(11, 14),
    CoilTypeStep(11, 14),
    CoilTypeStep(11, 14),
    CoilTypeStep(11, 14),
  );

  const TypeRole(
    this.label,
    this.weight,
    this.pointer,
    this.pointerCompact,
    this.touch,
    this.touchCompact,
  );

  final String label;
  final CoilWeight weight;
  final CoilTypeStep pointer;
  final CoilTypeStep pointerCompact;
  final CoilTypeStep touch;
  final CoilTypeStep touchCompact;

  CoilTypeStep step(CoilTier tier, CoilSize size) => switch ((tier, size)) {
    (CoilTier.pointer, CoilSize.regular) => pointer,
    (CoilTier.pointer, CoilSize.compact) => pointerCompact,
    (CoilTier.touch, CoilSize.regular) => touch,
    (CoilTier.touch, CoilSize.compact) => touchCompact,
  };

  /// This role's style at [context], in [color] (foreground by default).
  TextStyle styleOf(
    BuildContext context, {
    Color? color,
    CoilWeight? weight,
    CoilSize size = CoilSize.regular,
  }) {
    final theme = CoilTheme.of(context);
    return theme.typography.style(
      step(CoilTheme.tierOf(context), size),
      weight: weight ?? this.weight,
      color: color ?? theme.colors.foreground,
    );
  }
}

/// Text in a [TypeRole].
class RoleText extends StatelessWidget {
  const RoleText(
    this.text, {
    required this.role,
    super.key,
    this.muted = false,
    this.weight,
    this.textAlign,
  });

  final String text;
  final TypeRole role;
  final bool muted;
  final CoilWeight? weight;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return Text(
      text,
      textAlign: textAlign,
      style: role.styleOf(
        context,
        weight: weight,
        color: muted ? colors.mutedForeground : colors.foreground,
      ),
    );
  }
}
