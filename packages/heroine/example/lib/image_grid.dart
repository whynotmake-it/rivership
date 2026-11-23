import 'dart:math' as math;
import 'dart:ui';

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:heroine/heroine.dart';
import 'package:heroine_example/src/chrome.dart';
import 'package:heroine_example/src/icons.dart';
import 'package:heroine_example/src/network_photo.dart';
import 'package:heroine_example/src/photos.dart';
import 'package:heroine_example/src/settings_menus.dart';
import 'package:heroine_example/src/state_overlay.dart';

/// Every photo in a grid. A tapped photo flies into a card on top of the
/// grid, and flies back as fast as you drag it away.
class ImageGridExample extends StatelessWidget {
  const ImageGridExample({super.key});

  static const name = 'Photo grid';
  static const path = 'image-grid';

  @override
  Widget build(BuildContext context) {
    final gutter = DemoLayout.gutterOf(context);
    final padding = MediaQuery.paddingOf(context);
    return DemoPage(
      title: name,
      trailing: const TransitionSettingsButton(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // The grid uses the whole window: its edges line up with the
          // header's glyphs at any width.
          final sides = gutter + math.max(padding.left, padding.right);
          final usable = width - 2 * sides;
          return ListenableBuilder(
            listenable: demoSpring,
            builder: (context, _) => CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    sides,
                    8,
                    sides,
                    gutter + padding.bottom,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      // Three columns on a phone, tiles of at most 200
                      // otherwise.
                      maxCrossAxisExtent: width < 600 ? (usable - 16) / 3 : 200,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final photo = photos[index];
                      return Heroine(
                        tag: photo.id,
                        motion: demoSpring.value.motion,
                        child: PhotoTile(
                          photo: photo,
                          onPressed: () => Navigator.of(context).push(
                            PhotoRoute<void>(
                              builder: (context) => PhotoPage(photo: photo),
                            ),
                          ),
                        ),
                      );
                    }, childCount: photos.length),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A square photo in the grid, lit by hover and press like any coil control.
class PhotoTile extends StatelessWidget {
  const PhotoTile({required this.photo, super.key, this.onPressed});

  final Photo photo;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).container);
    return Semantics(
      button: true,
      label: 'Photo by ${photo.author}',
      child: CoilInteraction(
        onPressed: onPressed,
        builder: (context, states, child) => CoilFocusRing(
          visible: states.contains(WidgetState.focused),
          borderRadius: radius,
          child: ClipRSuperellipse(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child!,
                StateOverlay(states: states),
              ],
            ),
          ),
        ),
        child: NetworkPhoto(
          photo.square(400),
          background: colors.muted,
          motion: CoilTheme.motionOf(context).fade,
        ),
      ),
    );
  }
}

/// The page a photo opens on: the photo's card over the grid, which blurs
/// and fades away as the card is dragged off.
class PhotoPage extends StatelessWidget {
  const PhotoPage({required this.photo, super.key});

  final Photo photo;

  /// The widest the card gets.
  static const _maxCardWidth = 720.0;

  /// How much of the page's height the card may fill.
  static const _maxCardHeightFactor = 0.75;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final gutter = DemoLayout.gutterOf(context);
    final padding = MediaQuery.paddingOf(context);
    return ReactToHeroineDismiss(
      builder: (context, progress, offset, child) {
        final remaining = 1 - progress;
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: remaining * 20,
              sigmaY: remaining * 20,
            ),
            child: ColoredBox(
              color: colors.background.withValues(alpha: remaining),
              child: child,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReactToHeroineDismiss(
            builder: (context, progress, offset, child) =>
                Opacity(opacity: 1 - progress, child: child),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                gutter - 8 + padding.left,
                padding.top + 8,
                gutter - 8 + padding.right,
                8,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: CoilButton.icon(
                  variant: CoilButtonVariant.ghost,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const DemoIcon(Glyph.close),
                  semanticLabel: 'Close',
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final available = Size(
                  constraints.maxWidth - 2 * gutter - padding.horizontal,
                  constraints.maxHeight - padding.bottom,
                );
                // The photo sets the card's width, and the page's height
                // caps it: a card too tall for the page gets narrower, so
                // its photo keeps its shape.
                final captionHeight = PhotoCard.captionHeightOf(context);
                final width = math.max(
                  0.0,
                  math.min(
                    math.min(available.width, _maxCardWidth),
                    (available.height * _maxCardHeightFactor - captionHeight) *
                        photo.aspectRatio,
                  ),
                );
                return Center(
                  child: ListenableBuilder(
                    listenable: Listenable.merge([demoSpring, demoShuttle]),
                    builder: (context, _) => DragDismissable(
                      child: SizedBox(
                        width: width,
                        child: Heroine(
                          tag: photo.id,
                          motion: demoSpring.value.motion,
                          flightShuttleBuilder: demoShuttle.value.build(
                            context,
                          ),
                          child: PhotoCard(photo: photo),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A photo with its photographer and size underneath, on a raised surface.
///
/// With loose height it is as tall as the photo and its caption. With tight
/// constraints (a heroine flight builds it at every size from a small tile
/// up) it fills them: the caption keeps its height unless there is less room
/// than that, and the photo takes the rest.
class PhotoCard extends StatelessWidget {
  const PhotoCard({required this.photo, super.key});

  final Photo photo;

  /// The space around the caption's text.
  static const _captionPadding = 16.0;

  /// The gap between the photographer and the size.
  static const _captionGap = 2.0;

  /// What the caption strip needs at [context]'s text size.
  static double captionHeightOf(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle style) =>
        scaler.scale(style.fontSize ?? 14) * (style.height ?? 1.25);
    return 2 * _captionPadding +
        line(text.title) +
        _captionGap +
        line(text.muted.caption);
  }

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).container);
    final motion = CoilTheme.motionOf(context);
    final image = NetworkPhoto(
      photo.fit(1600),
      background: colors.muted,
      motion: motion.fade,
    );
    final caption = _Caption(photo: photo);
    return CoilSurface(
      offset: CoilSurface.popoverOffset,
      borderRadius: radius,
      child: ClipRSuperellipse(
        borderRadius: radius,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (!constraints.hasTightHeight) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(aspectRatio: photo.aspectRatio, child: image),
                  caption,
                ],
              );
            }
            return CustomMultiChildLayout(
              delegate: _CardLayout(),
              children: [
                LayoutId(id: _CardPart.photo, child: image),
                LayoutId(
                  id: _CardPart.caption,
                  child: Align(alignment: Alignment.topLeft, child: caption),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _CardPart { photo, caption }

/// Gives the caption its natural height, or what is left of the card if
/// that is less, and the photo the rest. A caption that doesn't fit is
/// clipped by the card.
class _CardLayout extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    final natural = layoutChild(
      _CardPart.caption,
      BoxConstraints.tightFor(width: size.width),
    );
    // Laid out unbounded in height above; the child is top-aligned, so the
    // clip at the card's edge shows its top.
    final captionHeight = math.min(natural.height, size.height);
    final photoHeight = size.height - captionHeight;
    layoutChild(
      _CardPart.photo,
      BoxConstraints.tight(Size(size.width, photoHeight)),
    );
    positionChild(_CardPart.photo, Offset.zero);
    positionChild(_CardPart.caption, Offset(0, photoHeight));
  }

  @override
  bool shouldRelayout(_CardLayout oldDelegate) => false;
}

class _Caption extends StatelessWidget {
  const _Caption({required this.photo});

  final Photo photo;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Padding(
      padding: const EdgeInsets.all(PhotoCard._captionPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: PhotoCard._captionGap,
        children: [
          Text(
            photo.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.title,
          ),
          Text(
            '${photo.width} × ${photo.height}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.muted.caption.tabular,
          ),
        ],
      ),
    );
  }
}

/// A route that fades in over the page below, which stays visible and is
/// told when its [Heroine] is dragged away.
class PhotoRoute<T> extends PageRoute<T> with HeroinePageRouteMixin<T> {
  PhotoRoute({required this.builder, super.settings});

  final WidgetBuilder builder;

  @override
  bool get maintainState => false;

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(opacity: animation, child: child);
}
