import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// A [CoilSheetRoute] that also takes the sheet's behavior settings.
///
/// `CoilSheetRoute` hides [snappingConfig], [dragHandoff] and
/// [dismissalMode] behind the defaults of `StupidSimpleSheetRoute`. The
/// sheet reads them through getters, so overriding the getters is enough.
/// The content sits in a touch-tier scope, as a sheet always is.
class DemoSheetRoute<T> extends CoilSheetRoute<T> {
  /// Creates a coil sheet that opens and snaps to [snappingConfig].
  DemoSheetRoute({
    required BuildContext context,
    required Widget child,
    super.barrierDismissible,
    super.barrierLabel,
    super.motion,
    super.settings,
    SheetSnappingConfig snappingConfig = SheetSnappingConfig.full,
    SheetDragHandoff dragHandoff = SheetDragHandoff.gestureStart,
    DismissalMode dismissalMode = DismissalMode.slide,
  }) : _snappingConfig = snappingConfig,
       _dragHandoff = dragHandoff,
       _dismissalMode = dismissalMode,
       super(
         context: context,
         // A sheet is a touch surface whatever the tier: its buttons, fields
         // and text take the touch sizes, like its rows.
         child: CoilAdaptiveScope(
           tier: CoilTier.touch,
           size: CoilSize.regular,
           child: child,
         ),
       );

  final SheetSnappingConfig _snappingConfig;
  final SheetDragHandoff _dragHandoff;
  final DismissalMode _dismissalMode;

  @override
  SheetSnappingConfig get snappingConfig => _snappingConfig;

  @override
  SheetDragHandoff get dragHandoff => _dragHandoff;

  @override
  DismissalMode get dismissalMode => _dismissalMode;
}
