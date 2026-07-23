import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';

/// A compact phone-shaped stage for demonstrations that need visible
/// offscreen space.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({required this.child, this.width, super.key});

  /// Content rendered inside the clipped device screen.
  final Widget child;

  /// The device width. Its height follows a 9:19.5 phone aspect ratio.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final frameWidth = width ?? 200;
    return SizedBox(
      width: frameWidth,
      height: frameWidth * 19.5 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surfaceSolid,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: t.border),
          boxShadow: t.hairlineShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(29),
          child: Stack(
            children: [
              Positioned.fill(child: child),
              Positioned(
                top: 10,
                left: frameWidth * .34,
                right: frameWidth * .34,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A presentation-only bottom sheet driven by a normalized external value.
///
/// A value of zero places the sheet below its frame and one opens it to 70%
/// of the frame height. Values are deliberately not clamped so spring
/// overshoot remains visible.
class DemoSheet extends StatelessWidget {
  const DemoSheet({
    required this.value,
    this.grabber = false,
    this.child,
    super.key,
  });

  final double value;
  final bool grabber;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final sheetHeight = constraints.maxHeight * .7;
        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: CupertinoColors.black.withValues(
                  alpha: .24 * value.clamp(0, 1),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: -sheetHeight * (1 - value),
              height: sheetHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.surfaceSolid,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border(top: BorderSide(color: t.border)),
                  boxShadow: t.softShadow,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 24,
                      child: grabber
                          ? Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: t.borderStrong,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            )
                          : null,
                    ),
                    Expanded(
                      child:
                          child ??
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 72,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: t.textPrimary,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                for (final width in [120.0, 96.0, 132.0])
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      width: width,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: t.border,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
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
          ],
        );
      },
    );
  }
}
