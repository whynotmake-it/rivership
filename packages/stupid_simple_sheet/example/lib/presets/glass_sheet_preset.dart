import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_previews.dart';

/// Preview for the home page card — glass sheet with blur gradient hint.
class GlassSheetPreview extends StatelessWidget {
  const GlassSheetPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Blurred background hint (gradient)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  t.accentPurple.withValues(alpha: .03),
                  t.accentPurple.withValues(alpha: .1),
                ],
              ),
            ),
          ),
        ),
        // Glass sheet with translucent surface
        Positioned(
          bottom: 0,
          left: 50,
          right: 50,
          child: Container(
            height: 130,
            decoration: BoxDecoration(
              color: t.surface.withValues(alpha: .7),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border.all(
                color: t.previewMiniBorder,
              ),
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
    );
  }
}

/// Demonstrates [StupidSimpleGlassSheetRoute], a bundled preset built
/// with [StupidSimpleSheetTransitionMixin].
///
/// This route recreates the iOS 26 liquid-glass sheet: the first sheet blurs
/// the backdrop, and subsequent sheets stack seamlessly without re-blurring.
///
/// Open the sheet and tap "Push Another" to see glass sheets stack.
class GlassSheetPreset extends StatelessWidget {
  const GlassSheetPreset({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 16,
                children: [
                  const Text(
                    'iOS 26 liquid glass style.\nOnly the first sheet blurs.',
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
      StupidSimpleGlassSheetRoute(
        backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
        child: const GlassSheetPreset(),
      ),
    );
  }
}
