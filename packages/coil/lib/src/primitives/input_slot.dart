/// @docImport 'package:coil/src/components/button/button.dart';
/// @docImport 'package:coil/src/components/input/input.dart';
library;

import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Where a text field puts a leading or trailing slot.
///
/// The default, [auto], decides by measuring the slot in the same layout
/// pass as the text: a slot no taller than a line of text is [inline], a
/// taller one (a button) is [inset].
enum CoilInputSlotPlacement {
  /// Measures the slot: [inline] if it fits a line of text, [inset] if it
  /// is taller.
  auto,

  /// Beside the text, inside the field's padding and centered on the text
  /// (on the first line of a multi-line field).
  ///
  /// A slot taller than the line makes the field taller.
  inline,

  /// Into the field's padding: centered in the field and as far from its
  /// side as from its top and bottom, so its corners sit concentric with
  /// the field's.
  ///
  /// On a multi-line field it sits in the bottom corner. The field grows
  /// only when the slot and its minimum inset don't fit.
  inset,
}

/// Tells a control in a text field's slot how to fit the field.
///
/// [CoilInput] puts one around its [CoilInputSlotPlacement.auto] and
/// [CoilInputSlotPlacement.inset] slots. A [CoilButton] inside defaults to
/// [size], at most [maxExtent] tall so it fits the field without growing
/// it, and to [radiusFor] its height, so its corners are concentric with
/// the field's, and drops its own touch hit padding: the field takes taps
/// around an inset slot instead. An explicit `size:` or `style:` on the
/// button still wins.
///
/// A custom control can read it with [maybeOf] the same way.
class CoilInputSlotScope extends InheritedWidget {
  /// Creates a slot scope.
  const CoilInputSlotScope({
    required this.size,
    required this.radii,
    required this.fieldRadius,
    required this.fieldHeight,
    required this.minInset,
    required super.child,
    super.key,
  });

  /// The size step a control in the slot defaults to.
  final CoilSize size;

  /// The theme's radii at the field's tier.
  ///
  /// A family that nests square (`sharp`) keeps a control's own radius.
  final CoilRadii radii;

  /// The field's corner radius.
  final double fieldRadius;

  /// The field's minimum height.
  final double fieldHeight;

  /// The least space between an inset slot and the field's edge.
  final double minInset;

  /// The tallest a control can be and still sit inset without growing the
  /// field: its minimum height less [minInset] on each side, 28 in a 36
  /// field and 24 in a 28 compact one.
  ///
  /// A control at [size] that is taller (a compact button is 28, as tall as
  /// a compact field) takes this height instead, so a compact field keeps
  /// its height as a regular one does.
  double get maxExtent => fieldHeight - 2 * minInset;

  /// The corner radius that keeps a control [extent] tall concentric with
  /// the field's corner when it sits inset, or null where the control
  /// keeps its own (`sharp`).
  ///
  /// The control sits `(height − extent) / 2` from the field's edges,
  /// where the height is the field's, grown to fit the control and its
  /// [minInset] when it doesn't. The field's corner is counted as drawn: a
  /// superellipse caps it at half the height.
  double? radiusFor(double extent) {
    if (radii.container <= radii.item) return null;
    final height = math.max(fieldHeight, extent + 2 * minInset);
    final inset = (height - extent) / 2;
    return CoilShape.nested(math.min(fieldRadius, height / 2), inset);
  }

  /// The scope above [context], if it is in a text field's slot.
  static CoilInputSlotScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoilInputSlotScope>();

  @override
  bool updateShouldNotify(CoilInputSlotScope oldWidget) =>
      oldWidget.size != size ||
      oldWidget.radii != radii ||
      oldWidget.fieldRadius != fieldRadius ||
      oldWidget.fieldHeight != fieldHeight ||
      oldWidget.minInset != minInset;
}
