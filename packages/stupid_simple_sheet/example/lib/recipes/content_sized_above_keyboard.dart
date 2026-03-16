import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_previews.dart';

/// Preview for the home page card — "Toast Alert" style top-anchored mockup.
///
/// Shows a dark notification bar floating at the top of the preview,
/// suggesting a non-blocking sheet that avoids the keyboard.
class ContentSizedKeyboardPreview extends StatelessWidget {
  const ContentSizedKeyboardPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Stack(
      children: [
        // Keyboard placeholder at bottom
        Positioned(
          bottom: 0,
          left: 20,
          right: 20,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: t.textTertiary.withValues(alpha: .08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 3,
              children: [
                for (var i = 0; i < 7; i++)
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: t.textTertiary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Floating card above keyboard
        Positioned(
          bottom: 68,
          left: 30,
          right: 30,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: t.previewMiniSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.previewMiniBorder),
              boxShadow: [
                BoxShadow(
                  color: t.previewMiniShadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: t.previewLine,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                const MiniListLine(widthFraction: 0.5),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Opens a content-sized sheet with keyboard avoidance directly.
void showContentSizedKeyboardSheet(BuildContext context) {
  Navigator.of(context).push(
    StupidSimpleSheetRoute(
      originateAboveBottomViewInset: true,
      motion: CupertinoMotion.smooth(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SheetBackground.withTopMargin(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          extensionAtBottom: 0,
          child: _Content(),
        ),
      ),
    ),
  );
}

class _Content extends StatelessWidget {
  const _Content();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 80,
              color: const Color(0xFF007AFF),
              alignment: Alignment.center,
              child: const Text(
                'Content-sized sheet',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const CupertinoTextField(
              placeholder: 'Tap to open keyboard...',
              autofocus: true,
            ),
            const SizedBox(height: 12),
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
