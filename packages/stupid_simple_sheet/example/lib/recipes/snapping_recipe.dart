import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_previews.dart';

/// Preview for the home page card — "Multi-Snap Points" mockup.
///
/// Shows dashed lines at snap positions with a sheet at the 70% mark.
class SnappingPreview extends StatelessWidget {
  const SnappingPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CustomPaint(
      painter: DashedLinePainter(
        fractions: const [0.30, 0.60],
        lineColor: t.textTertiary.withValues(alpha: .4),
      ),
      child: Stack(
        children: [
          // Snap position labels
          for (final (frac, label) in [
            (0.33, '33%'),
            (0.66, '66%'),
            (1.0, '100%'),
          ])
            Positioned(
              bottom: 220 * frac - 1,
              left: 16,
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.accentGold.withValues(alpha: .6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 8,
                      color: t.accentGold.withValues(alpha: .6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Sheet at ~70% height
          Positioned(
            bottom: 0,
            left: 40,
            right: 40,
            child: Container(
              height: 220 * 0.7,
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
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: t.previewHandle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a sheet with multiple snap detents directly.
void showSnappingSheet(BuildContext context) {
  final snaps = [1 / 3, 2 / 3, 1.0];
  Navigator.of(context).push(
    StupidSimpleSheetRoute(
      snappingConfig: SheetSnappingConfig(snaps),
      child: SheetBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final stop in snaps)
              Expanded(
                child: Container(
                  color: _colorForStop(stop),
                  alignment: Alignment.center,
                  child: Text(
                    '${(stop * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Color _colorForStop(double stop) {
  return switch (stop) {
    < .4 => const Color(0xFF007AFF),
    < .7 => const Color(0xFF34C759),
    _ => const Color(0xFFFF9500),
  };
}
