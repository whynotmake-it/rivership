/// @docImport 'package:coil/button.dart';
/// @docImport 'package:coil/foundation.dart';
library;

/// Visual emphasis variant for a [CoilButton].
enum CoilButtonVariant {
  /// Solid foreground fill for the primary action.
  primary,

  /// Solid brand fill ([CoilColors.brandFill] under [CoilColors.onBrandFill])
  /// for a colored primary action.
  ///
  /// Lit like [primary], in the brand's own hue.
  brand,

  /// A translucent tint that blends with the surface beneath it.
  secondary,

  /// Transparent fill with a hairline border.
  tertiary,

  /// No fill until hovered, with a muted label.
  ghost,

  /// A red wash under a red label for destructive actions.
  destructive,
}
