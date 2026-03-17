import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_previews.dart';

/// Preview for the home page card — shows a sheet with scrollable
/// content and a pinned footer.
class StickyFooterPreview extends StatelessWidget {
  const StickyFooterPreview({super.key});

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
              height: 150,
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
                  const SizedBox(height: 6),
                  const MiniListLine(widthFraction: 0.7),
                  const MiniListLine(widthFraction: 0.5),
                  const MiniListLine(widthFraction: 0.6),
                  const Spacer(),
                  Container(
                    height: 0.5,
                    color: t.previewHandle,
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      spacing: 6,
                      children: [
                        Expanded(
                          child: Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: t.previewHandle.withValues(alpha: .3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: t.accentGreen,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
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

/// Opens a scrollable sheet with a sticky footer directly.
void showStickyFooterSheet(BuildContext context) {
  Navigator.of(context).push(
    StupidSimpleSheetRoute(
      child: SheetBackground.withTopMargin(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: 30,
                  itemBuilder: (context, index) => Container(
                    height: 56,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey5.resolveFrom(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Item ${index + 1}'),
                  ),
                ),
              ),
              Builder(
                builder: (context) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: CupertinoColors.opaqueSeparator
                            .resolveFrom(context),
                      ),
                    ),
                  ),
                  child: Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          color:
                              CupertinoColors.systemGrey5.resolveFrom(context),
                          child: const Text('Cancel'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Expanded(
                        child: CupertinoButton.filled(
                          child: const Text('Done'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
