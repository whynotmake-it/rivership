import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_previews.dart';

/// Preview for the home page card — matches the "Standard Bottom" mockup.
///
/// A dot-grid background with a white sheet sliding up from the bottom,
/// containing a drag handle and placeholder lines.
class BasicSheetPreview extends StatelessWidget {
  const BasicSheetPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CustomPaint(
      painter: DotGridPainter(
        dotColor: t.textTertiary.withValues(alpha: .3),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sheet sliding up from bottom
          Positioned(
            bottom: 0,
            left: 40,
            right: 40,
            child: Container(
              height: 140,
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
                  // Drag handle
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
                  const SizedBox(height: 16),
                  // Placeholder title line
                  FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: t.previewLine,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Placeholder content blocks
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: t.previewLine,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: t.previewLine,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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

/// Opens the most basic sheet directly — no intermediate page needed.
void showBasicSheet(BuildContext context) {
  Navigator.of(context).push(
    StupidSimpleSheetRoute(
      // You decide how to position your sheet.
      //
      // For example here we center with max width to make it look good on
      // larger screens
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SheetBackground.withTopMargin(
            child: ListView.builder(
              itemCount: 50,
              itemBuilder: (context, index) => CupertinoListTile(
                title: Text('Item ${index + 1}'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
