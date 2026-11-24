import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';

/// coil's sheet as the example opens it: a [CoilSheetRoute] whose content
/// takes coil's touch sizes on every tier.
///
/// A sheet is a touch surface whatever the tier, like its rows, so its
/// buttons, fields and text take the touch sizes too. Everything else is
/// passed straight to [CoilSheetRoute].
CoilSheetRoute<T> exampleSheetRoute<T>({
  required BuildContext context,
  required Widget child,
  bool barrierDismissible = true,
  String? barrierLabel,
  CoilMotion? motion,
  RouteSettings? settings,
  SheetSnappingConfig snappingConfig = SheetSnappingConfig.full,
  SheetDragHandoff dragHandoff = SheetDragHandoff.gestureStart,
  DismissalMode dismissalMode = DismissalMode.slide,
  bool draggable = true,
  RouteSnapshotMode backgroundSnapshotMode = RouteSnapshotMode.never,
}) => CoilSheetRoute<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  barrierLabel: barrierLabel,
  motion: motion,
  settings: settings,
  snappingConfig: snappingConfig,
  dragHandoff: dragHandoff,
  dismissalMode: dismissalMode,
  draggable: draggable,
  backgroundSnapshotMode: backgroundSnapshotMode,
  child: CoilAdaptiveScope(
    tier: CoilTier.touch,
    size: CoilSize.regular,
    child: child,
  ),
);
