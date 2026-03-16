import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// A share-sheet style example that uses [DismissalMode.shrink] so the sheet
/// collapses from the top while keeping footer buttons pinned at the bottom.
/// Combined with snap points at 50% and 100%, this creates a two-stop sheet
/// with a persistent footer that stays visible even when the sheet is half-open.
///
/// See also: [DismissalMode.shrink], [SheetSnappingConfig]
void showShrinkingModal(BuildContext context) {
  Navigator.of(context).push(
    ShrinkingModalRoute(
      snappingConfig: SheetSnappingConfig([0.5, 1]),
      child: const ShrinkingModalExample(),
    ),
  );
}

class ShrinkingModalRoute<T> extends PopupRoute<T>
    with StupidSimpleSheetTransitionMixin, StupidSimpleSheetController<T> {
  ShrinkingModalRoute({
    required this.child,
    this.snappingConfig = SheetSnappingConfig.full,
    super.settings,
  });

  final Widget child;

  @override
  final SheetSnappingConfig snappingConfig;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => CupertinoColors.black.withValues(alpha: .15);

  @override
  String? get barrierLabel => null;

  @override
  Motion get motion => CupertinoMotion.snappy();

  @override
  DismissalMode get dismissalMode => DismissalMode.shrink;

  @override
  Widget buildContent(BuildContext context) {
    return child;
  }
}

class ShrinkingModalExample extends StatelessWidget {
  const ShrinkingModalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Container(
      margin: const EdgeInsets.all(16),
      constraints: BoxConstraints(minHeight: 50, maxHeight: 400),
      color: CupertinoColors.systemGrey2,
    ));
  }
}
