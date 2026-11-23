import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:heroine/heroine.dart';
import 'package:heroine_example/src/network_photo.dart';
import 'package:heroine_example/src/photos.dart';

/// The iOS zoom transition, in iOS clothes: a Photos-like grid whose photos
/// grow into their page and shrink back when the page is dragged down.
///
/// Every level of the stack has its own heroine tags. A zoom route wraps its
/// whole page in a [Heroine], and a heroine can't fly while another one
/// inside it does, so two adjacent routes never share a tag where one of
/// them sits inside the other:
///
/// * a photo's tile in a grid and the root of its page share
///   `(scope, photo.id)`, where the scope is `'zoom'` for the grid of all
///   photos and one new object for every photographer page;
/// * a photo page's photographer row and the root of the photographer's page
///   share one new object per photo page.
class ZoomTransitionExample extends StatelessWidget {
  const ZoomTransitionExample({super.key});

  static const name = 'Zoom transition';
  static const path = 'zoom';

  static const _scope = 'zoom';

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    child: CustomScrollView(
      slivers: [
        const CupertinoSliverNavigationBar(largeTitle: Text('Photos')),
        PhotoGrid(photos: photos, scope: _scope),
      ],
    ),
  );
}

/// The zoom's spring.
const _zoomMotion = CupertinoMotion.smooth();

/// Opens [photo]'s page with a zoom from its tile, which has [tag].
void _openPhoto(BuildContext context, Photo photo, Object tag) =>
    Navigator.of(context).push(
      HeroineZoomRoute<void>(
        title: photo.author,
        tag: tag,
        builder: (context) => PhotoDetailPage(photo: photo),
      ),
    );

/// Photos as square crops with thin gaps, like the Photos app, as slivers.
/// Tapping one zooms into its page.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({required this.photos, required this.scope, super.key});

  final List<Photo> photos;

  /// Makes the tiles' heroine tags, `(scope, photo.id)`, unique to this grid.
  final Object scope;

  static const _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    final placeholder = CupertinoColors.systemFill.resolveFrom(context);
    return SliverSafeArea(
      top: false,
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) => SliverGrid(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            // Three columns on a phone, tiles of at most 160 otherwise.
            maxCrossAxisExtent: constraints.crossAxisExtent < 600
                ? (constraints.crossAxisExtent - 2 * _gap) / 3
                : 160,
            mainAxisSpacing: _gap,
            crossAxisSpacing: _gap,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final photo = photos[index];
            final tag = (scope, photo.id);
            return Heroine(
              tag: tag,
              motion: _zoomMotion,
              child: Semantics(
                button: true,
                label: 'Photo by ${photo.author}',
                child: GestureDetector(
                  onTap: () => _openPhoto(context, photo, tag),
                  child: NetworkPhoto(
                    photo.square(400),
                    background: placeholder,
                  ),
                ),
              ),
            );
          }, childCount: photos.length),
        ),
      ),
    );
  }
}

/// A photo with its photographer and size, like a photo's info in Photos.
class PhotoDetailPage extends StatefulWidget {
  const PhotoDetailPage({required this.photo, super.key});

  final Photo photo;

  @override
  State<PhotoDetailPage> createState() => _PhotoDetailPageState();
}

/// The width of the detail page's column on windows wider than a phone.
const _wideColumn = 640.0;

class _PhotoDetailPageState extends State<PhotoDetailPage> {
  /// Shared by the photographer row and the root of the photographer's page.
  final _photographerTag = Object();

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 600;
    return CupertinoPageScaffold(
      // Grouped lists sit on the grouped background, down to the bottom.
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(middle: Text(photo.author)),
      // Read the insets the scaffold gives its child, below the bar.
      child: Builder(
        builder: (inner) => ListView(
          // On a phone the photo runs edge to edge. On wider windows the page
          // is a centered column, the photo inset and rounded like the list
          // section below it, so the details stay on screen.
          // An explicit padding replaces the list's automatic one, so it adds
          // the insets (the translucent bar on top, the home indicator)
          // itself.
          padding: wide
              ? MediaQuery.paddingOf(inner) +
                    EdgeInsets.symmetric(
                      horizontal: math.max(0, (width - _wideColumn) / 2),
                      vertical: 20,
                    )
              : null,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: wide ? 20 : 0),
              child: ClipRSuperellipse(
                borderRadius: BorderRadius.circular(wide ? 10 : 0),
                child: AspectRatio(
                  aspectRatio: photo.aspectRatio,
                  child: NetworkPhoto(
                    photo.fit(1600),
                    background: CupertinoColors.systemFill.resolveFrom(context),
                  ),
                ),
              ),
            ),
            CupertinoListSection.insetGrouped(
              children: [
                Heroine(
                  tag: _photographerTag,
                  motion: _zoomMotion,
                  // A flight builds the row at every size between it and the
                  // page. At rest it is as wide as the window less the
                  // section's margins.
                  child: _KeepSize(
                    minWidth: math.min(320, math.min(width, _wideColumn) - 40),
                    minHeight: 44,
                    child: CupertinoListTile(
                      title: const Text('Photographer'),
                      additionalInfo: Text(photo.author),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => Navigator.of(context).push(
                        HeroineZoomRoute<void>(
                          title: photo.author,
                          tag: _photographerTag,
                          builder: (context) =>
                              PhotographerPage(author: photo.author),
                        ),
                      ),
                    ),
                  ),
                ),
                CupertinoListTile(
                  title: const Text('Size'),
                  additionalInfo: Text('${photo.width} × ${photo.height}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// All the photos by one photographer.
class PhotographerPage extends StatefulWidget {
  const PhotographerPage({required this.author, super.key});

  final String author;

  @override
  State<PhotographerPage> createState() => _PhotographerPageState();
}

class _PhotographerPageState extends State<PhotographerPage> {
  /// Makes this page's tile tags differ from every other photographer
  /// page's, so photo pages that are open at once never share one.
  final _scope = Object();

  @override
  Widget build(BuildContext context) {
    final byAuthor = [
      for (final photo in photos)
        if (photo.author == widget.author) photo,
    ];
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(largeTitle: Text(widget.author)),
          PhotoGrid(photos: byAuthor, scope: _scope),
        ],
      ),
    );
  }
}

/// A route that zooms into its page from the [Heroine] with the same [tag]
/// and back when the page is dragged down.
class HeroineZoomRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin<T>, HeroinePageRouteMixin<T> {
  HeroineZoomRoute({
    required this.title,
    required this.tag,
    required this.builder,
    super.settings,
  });

  @override
  final String title;

  final Object tag;

  final WidgetBuilder builder;

  @override
  bool get maintainState => false;

  @override
  bool get opaque => false;

  @override
  Widget buildContent(BuildContext context) => HeroMode(
    // Flutter heroes begone
    enabled: false,
    child: DragDismissable(
      child: ReactToHeroineDismiss(
        builder: (context, progress, offset, child) => Transform.scale(
          scale: 1 - progress * 0.2,
          child: Heroine(
            tag: tag,
            motion: _zoomMotion,
            flightShuttleBuilder: const FadeShuttleBuilder(),
            child: _ZoomSurface(
              dragging: progress > 0,
              // A flight builds the page at every size from a tile up. At
              // rest it fills the window, whatever its size.
              child: _KeepSize(
                minWidth: math.min(360, MediaQuery.sizeOf(context).width),
                minHeight: math.min(480, MediaQuery.sizeOf(context).height),
                child: child!,
              ),
            ),
          ),
        ),
        child: builder(context),
      ),
    ),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) =>
          ValueListenableBuilder<double>(
            valueListenable: this.animation!,
            // The page below stays put, on the scaffold's background, while
            // this route moves.
            builder: (context, value, child) => ColoredBox(
              color: value > 0
                  ? CupertinoTheme.of(context).scaffoldBackgroundColor
                  : const Color(0x00000000),
              child: child,
            ),
            child: child,
          );
}

/// The page's corners and shadow: square at rest, rounded and lifted while
/// it is dragged.
class _ZoomSurface extends StatelessWidget {
  const _ZoomSurface({required this.dragging, required this.child});

  final bool dragging;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(dragging ? 32 : 0);
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(borderRadius: radius),
        shadows: dragging
            ? [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: ClipRSuperellipse(borderRadius: radius, child: child),
    );
  }
}

/// Lays [child] out at least [minWidth] by [minHeight] and clips it to the
/// room it is given, so a heroine flight, which builds [child] at every size
/// between its two ends, never overflows it.
class _KeepSize extends StatelessWidget {
  const _KeepSize({
    required this.minWidth,
    required this.minHeight,
    required this.child,
  });

  final double minWidth;

  final double minHeight;

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final bounded = constraints.hasBoundedHeight;
      if (constraints.maxWidth >= minWidth &&
          (!bounded || constraints.maxHeight >= minHeight)) {
        return child;
      }
      final width = math.max(constraints.maxWidth, minWidth);
      final height = bounded
          ? math.max(constraints.maxHeight, minHeight)
          : double.infinity;
      return ClipRect(
        child: OverflowBox(
          alignment: AlignmentDirectional.topStart,
          minWidth: width,
          maxWidth: width,
          minHeight: bounded ? height : 0,
          maxHeight: height,
          child: child,
        ),
      );
    },
  );
}
