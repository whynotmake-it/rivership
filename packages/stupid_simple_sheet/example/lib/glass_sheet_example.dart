import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// An iOS 26 liquid-glass styled sheet. Glass sheets stack seamlessly — only
/// the first sheet blurs the backdrop.
///
/// See also: [StupidSimpleGlassSheetRoute]
void showGlassSheet(BuildContext context) {
  Navigator.of(context).push(
    StupidSimpleGlassSheetRoute(
      backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
      child: const GlassSheetExample(),
    ),
  );
}

class GlassSheetExample extends StatelessWidget {
  const GlassSheetExample({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          PinnedHeaderSliver(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: _GlassSurface(
                          inLayer: false,
                          borderRadius: BorderRadius.circular(200),
                          child: Padding(
                            padding: EdgeInsetsGeometry.all(10),
                            child: Icon(CupertinoIcons.xmark),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => showGlassSheet(context),
                        child: _GlassSurface(
                          color: CupertinoColors.activeBlue,
                          inLayer: false,
                          borderRadius: BorderRadius.circular(200),
                          child: Padding(
                            padding: EdgeInsetsGeometry.symmetric(
                              vertical: 10,
                              horizontal: 16,
                            ),
                            child: Center(
                              child: Text(
                                'Another',
                                style: CupertinoTheme.of(context)
                                    .textTheme
                                    .actionTextStyle
                                    .copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.white.withValues(),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverSafeArea(
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: CupertinoTextField(
                    placeholder: 'Type something...',
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => CupertinoListTile(
                      title: Text('Item #$index'),
                    ),
                    childCount: 50,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.borderRadius,
    required this.inLayer,
    required this.child,
    this.color,
  });

  final BorderRadius borderRadius;
  final bool inLayer;
  final Color? color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LiquidStretch(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(borderRadius: borderRadius),
          shadows: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.1),
              blurStyle: BlurStyle.outer,
              blurRadius: 8,
            ),
          ],
        ),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (inLayer) {
      return LiquidGlass(
        shape: LiquidRoundedSuperellipse(
          borderRadius: borderRadius.topLeft.x,
        ),
        child: GlassGlow(child: child),
      );
    }
    return LiquidGlass.withOwnLayer(
      fake: true,
      settings: LiquidGlassSettings(
        glassColor: color ??
            CupertinoTheme.of(context).barBackgroundColor.withValues(alpha: .7),
        thickness: 30,
        ambientStrength: .1,
        saturation: 4,
        lightIntensity: .4,
        blur: 4,
      ),
      shape: LiquidRoundedSuperellipse(
        borderRadius: borderRadius.topLeft.x,
      ),
      child: GlassGlow(
        child: IconTheme(
          data: IconThemeData(
            color: CupertinoTheme.of(context).textTheme.textStyle.color,
          ),
          child: child,
        ),
      ),
    );
  }
}
