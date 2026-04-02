import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_previews.dart';

/// Preview for the home page card — content-sized floating card.
class ContentSizedPreview extends StatelessWidget {
  const ContentSizedPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CustomPaint(
      painter: DotGridPainter(
        dotColor: t.textTertiary.withValues(alpha: .2),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 48),
          child: MiniModal(
            width: 120,
            height: 60,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 14,
                    decoration: BoxDecoration(
                      color: t.accentIndigo,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 80,
                    height: 14,
                    decoration: BoxDecoration(
                      color: t.accentBlue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a content-sized sheet directly.
void showContentSizedSheet(BuildContext context) {
  Navigator.of(context).push(
    StupidSimpleSheetRoute(
      child: SheetBackground.withTopMargin(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 60,
                  color: const Color(0xFF5856D6),
                  alignment: Alignment.center,
                  child: const Text(
                    'Small content',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 60,
                  color: const Color(0xFF007AFF),
                  alignment: Alignment.center,
                  child: const Text(
                    'Just two boxes',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoButton.filled(
                  child: const Text('Close'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
