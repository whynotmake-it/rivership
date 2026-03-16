import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_previews.dart';

/// Preview for the home page card — shows the "Action Sheet" style mockup.
///
/// A line-grid background with floating action-sheet-style containers.
class SlideVsShrinkPreview extends StatelessWidget {
  const SlideVsShrinkPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CustomPaint(
      painter: LineGridPainter(
        lineColor: t.textTertiary.withValues(alpha: .2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Action group (two items)
            Container(
              decoration: BoxDecoration(
                color: t.previewMiniSurface.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: t.previewMiniShadow,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    height: 36,
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: t.previewLine,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  Container(height: 0.5, color: t.previewHandle),
                  Container(
                    height: 36,
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      widthFactor: 0.35,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: t.previewLine,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Cancel button
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: t.previewMiniSurface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: t.previewMiniShadow,
                    blurRadius: 8,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: FractionallySizedBox(
                widthFactor: 0.25,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: t.previewHandle,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compares [DismissalMode.slide] and [DismissalMode.shrink].
///
/// This recipe needs two buttons so it uses a custom layout rather than
/// the single-card [ExamplePage].
class SlideVsShrinkRecipe extends StatelessWidget {
  const SlideVsShrinkRecipe({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CupertinoPageScaffold(
      backgroundColor: t.canvas,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: t.canvas,
        middle: Text(
          'Slide vs Shrink',
          style: TextStyle(color: t.textPrimary),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 16,
              children: [
                CupertinoButton.filled(
                  child: const Text('Slide (default)'),
                  onPressed: () => _show(context, DismissalMode.slide),
                ),
                CupertinoButton.filled(
                  child: const Text('Shrink'),
                  onPressed: () => _show(context, DismissalMode.shrink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _show(BuildContext context, DismissalMode mode) {
    Navigator.of(context).push(
      StupidSimpleSheetRoute(
        dismissalMode: mode,
        snappingConfig: SheetSnappingConfig([0.5, 1]),
        child: SheetBackground(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(child: Placeholder()),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CupertinoButton.filled(
                    child: Text('Footer — mode: ${mode.name}'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
