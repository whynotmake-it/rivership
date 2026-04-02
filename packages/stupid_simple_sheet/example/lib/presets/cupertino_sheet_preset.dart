import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_previews.dart';

/// Preview for the home page card — "Side Drawer" inspired stacked sheets.
///
/// Shows a background page scaled down with the front sheet overlapping,
/// matching the iOS 18 push-back pattern.
class CupertinoSheetPreview extends StatelessWidget {
  const CupertinoSheetPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CustomPaint(
      painter: DotGridPainter(
        dotColor: t.textTertiary.withValues(alpha: .2),
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Background "page" scaled down
          Positioned(
            bottom: 16,
            child: Transform.scale(
              scale: 0.85,
              child: Container(
                width: 130,
                height: 120,
                decoration: BoxDecoration(
                  color: t.previewLine,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Front sheet
          Positioned(
            bottom: 0,
            left: 50,
            right: 50,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: t.previewMiniSurface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: t.previewMiniShadow,
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  MiniHandle(),
                  SizedBox(height: 8),
                  MiniListLine(widthFraction: 0.6),
                  MiniListLine(widthFraction: 0.4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Demonstrates [StupidSimpleCupertinoSheetRoute], a bundled preset built
/// with [StupidSimpleSheetTransitionMixin].
///
/// This route recreates the iOS 18 modal sheet: the previous route scales down
/// and slides away, the sheet clips with the device corner radius, and
/// stacking multiple sheets produces the native cascading effect.
///
/// Open the sheet and tap "Push Another" to see sheets stack.
class CupertinoSheetPreset extends StatelessWidget {
  const CupertinoSheetPreset({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('Cupertino Sheet'),
          ),
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 16,
                children: [
                  const Text(
                    'iOS 18 style sheet.\nThe route behind scales down.',
                    textAlign: TextAlign.center,
                  ),
                  CupertinoButton.filled(
                    child: const Text('Push Another'),
                    onPressed: () => _push(context),
                  ),
                  CupertinoButton(
                    child: const Text('Close'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _push(BuildContext context) {
    Navigator.of(context).push(
      StupidSimpleCupertinoSheetRoute(
        backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
        child: const CupertinoSheetPreset(),
      ),
    );
  }
}
