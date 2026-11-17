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

/// Opens a content-sized glass sheet.
///
/// Glass sheets default to [PresentationSizing.automatic], so the sheet hugs
/// its content. From inside, you can stack more sheets to see how each
/// [PresentationSizing] stacks: short sheets leave the one behind in place,
/// full height ones push it back.
void showContentSizedSheet(BuildContext context) {
  Navigator.of(context).push(
    StupidSimpleGlassSheetRoute<void>(
      child: const _ContentSizedSheet(),
    ),
  );
}

class _ContentSizedSheet extends StatelessWidget {
  const _ContentSizedSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // size to content
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
            CupertinoButton.tinted(
              child: const Text('Stack another short sheet'),
              onPressed: () => showContentSizedSheet(context),
            ),
            CupertinoButton.tinted(
              child: const Text('Stack a page sheet'),
              onPressed: () => Navigator.of(context).push(
                StupidSimpleGlassSheetRoute<void>(
                  presentationSizing: PresentationSizing.page,
                  child: const _ContentSizedSheet(),
                ),
              ),
            ),
            CupertinoButton.tinted(
              child: const Text('Stack a scrolling sheet'),
              onPressed: () => Navigator.of(context).push(
                StupidSimpleGlassSheetRoute<void>(
                  // A scroll view takes all the height it gets, so this
                  // fitted sheet grows to full height.
                  child: ListView.builder(
                    itemCount: 50,
                    itemBuilder: (context, index) => CupertinoListTile(
                      title: Text('Item #$index'),
                    ),
                  ),
                ),
              ),
            ),
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
