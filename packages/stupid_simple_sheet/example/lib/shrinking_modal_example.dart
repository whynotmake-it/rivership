import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
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
  Motion get motion => CupertinoMotion.snappy(snapToEnd: true);

  @override
  DismissalMode get dismissalMode => DismissalMode.shrink;

  @override
  Widget buildContent(BuildContext context) {
    return child;
  }
}

class ShrinkingModalExample extends StatefulWidget {
  const ShrinkingModalExample({super.key});

  @override
  State<ShrinkingModalExample> createState() => _ShrinkingModalExampleState();
}

class _ShrinkingModalExampleState extends State<ShrinkingModalExample> {
  List<String> items = List.generate(
    5,
    (index) => 'Item ${index + 1}',
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        minimum: EdgeInsets.only(bottom: 8),
        child: LiquidStretch(
          interactionScale: 1,
          child: Container(
            margin: const EdgeInsets.all(8),
            constraints: BoxConstraints(minHeight: 0, maxHeight: 420),
            child: LiquidGlass.withOwnLayer(
              settings: LiquidGlassSettings(
                thickness: 30,
                glassColor: CupertinoColors.secondarySystemBackground
                    .resolveFrom(context)
                    .withValues(alpha: .7),
              ),
              child: GlassGlow(
                glowColor: CupertinoColors.white.withValues(alpha: .1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: AnimatedSize(
                        alignment: Alignment.topCenter,
                        duration: CupertinoMotion.smooth().duration,
                        curve: CupertinoMotion.smooth().toCurve,
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (var i = 0; i < items.length; i++)
                              CupertinoListTile(
                                title: Text(items[i]),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            foregroundColor: CupertinoColors.destructiveRed,
                            child: Text('Close'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                        Expanded(
                          child: CupertinoButton(
                            child: Text('Add Item'),
                            onPressed: () => _addItem(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              shape: LiquidRoundedSuperellipse(borderRadius: 32),
            ),
          ),
        ));
  }

  void _addItem() {
    setState(() {
      final text = 'Item ${items.length + 1}';
      items.add(text);
    });
  }
}
