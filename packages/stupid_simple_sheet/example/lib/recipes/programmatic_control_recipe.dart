import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_previews.dart';

/// Preview for the home page card — shows a sheet with control buttons.
class ProgrammaticControlPreview extends StatelessWidget {
  const ProgrammaticControlPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CustomPaint(
      painter: DotGridPainter(
        dotColor: t.textTertiary.withValues(alpha: .2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            left: 40,
            right: 40,
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                color: t.previewMiniSurface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: t.previewMiniShadow,
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const MiniHandle(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 4,
                    children: [
                      for (final pct in ['40%', '70%', '100%'])
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: t.previewLine,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            pct,
                            style: TextStyle(
                              fontSize: 8,
                              color: t.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a sheet with programmatic control directly.
void showProgrammaticControlSheet(BuildContext context) {
  Navigator.of(context).push(
    StupidSimpleSheetRoute(
      snappingConfig: SheetSnappingConfig(
        [0.4, 0.7, 1.0],
        initialSnap: 0.4,
      ),
      child: const SheetBackground(
        child: _ControlPanel(),
      ),
    ),
  );
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            const Text(
              'animateToRelative()',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              spacing: 8,
              children: [
                for (final target in [0.4, 0.7, 1.0])
                  Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      color: CupertinoColors.systemGrey5.resolveFrom(context),
                      child: Text('${(target * 100).toInt()}%'),
                      onPressed: () {
                        StupidSimpleSheetController.maybeOf(context)
                            ?.animateToRelative(target);
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'overrideSnappingConfig()',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            CupertinoButton(
              color: CupertinoColors.systemGrey5.resolveFrom(context),
              child: const Text('Set to 50% / 100%'),
              onPressed: () {
                StupidSimpleSheetController.maybeOf(context)
                    ?.overrideSnappingConfig(
                  SheetSnappingConfig([0.5, 1.0]),
                  animateToComply: true,
                );
              },
            ),
            CupertinoButton(
              color: CupertinoColors.systemGrey5.resolveFrom(context),
              child: const Text('Reset to original'),
              onPressed: () {
                StupidSimpleSheetController.maybeOf(context)
                    ?.overrideSnappingConfig(
                  null,
                  animateToComply: true,
                );
              },
            ),
            const Spacer(),
            CupertinoButton.filled(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
