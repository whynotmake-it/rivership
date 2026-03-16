import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_previews.dart';

/// Preview for the home page card — shows a centered custom modal.
class CustomRoutePreview extends StatelessWidget {
  const CustomRoutePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CustomPaint(
      painter: DotGridPainter(
        dotColor: t.textTertiary.withValues(alpha: .2),
      ),
      child: Center(
        child: MiniModal(
          width: 90,
          height: 90,
          child: Center(
            child: MiniAccent(
              widthFraction: 0.6,
              heightFraction: 0.4,
              color: t.accentGreen,
            ),
          ),
        ),
      ),
    );
  }
}

/// Demonstrates building a fully custom [PopupRoute] using
/// [StupidSimpleSheetTransitionMixin] and [StupidSimpleSheetController].
///
/// This is the escape hatch for when the bundled presets don't fit your needs.
/// You get full control over transitions, barrier, shape, and layout while
/// still benefiting from the drag-to-dismiss and snapping behaviour.
class CustomRouteExample extends StatefulWidget {
  const CustomRouteExample({super.key});

  @override
  State<CustomRouteExample> createState() => _CustomRouteExampleState();
}

class _CustomRouteExampleState extends State<CustomRouteExample> {
  List<String> items = List.generate(
    10,
    (index) => 'Item ${index + 1}',
  );

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
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
                  child: const Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
              Expanded(
                child: CupertinoButton(
                  child: const Text('Add Item'),
                  onPressed: () => _addItem(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addItem() {
    setState(() {
      final text = 'Item ${items.length + 1}';
      items.add(text);
    });
  }
}

/// A custom [PopupRoute] built with the sheet mixins.
///
/// This shows the minimum boilerplate needed to create your own sheet route.
/// Override [motion], [dismissalMode], [snappingConfig], and [buildContent]
/// to customise the behaviour.
class CustomSheetRoute<T> extends PopupRoute<T>
    with StupidSimpleSheetTransitionMixin<T>, StupidSimpleSheetController<T> {
  CustomSheetRoute({
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
  Motion get motion => CupertinoMotion.smooth(
        duration: Duration(milliseconds: 350),
        snapToEnd: true,
      );

  @override
  DismissalMode get dismissalMode => DismissalMode.shrink;

  @override
  Widget buildContent(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        heightFactor: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: LiquidStretch(
            interactionScale: 1,
            child: LiquidGlass.withOwnLayer(
              fake: !ImageFilter.isShaderFilterSupported,
              settings: LiquidGlassSettings(
                thickness: 40,
                blur: 10,
                lightIntensity: .3,
                glassColor: CupertinoColors.secondarySystemBackground
                    .resolveFrom(context)
                    .withValues(alpha: .7),
              ),
              shape: const LiquidRoundedSuperellipse(borderRadius: 32),
              child: GlassGlow(
                glowColor: CupertinoColors.white.withValues(alpha: .1),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
