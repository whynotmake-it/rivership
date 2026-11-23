import 'dart:ui';

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:heroine/heroine.dart';
import 'package:heroine_example/src/chrome.dart';
import 'package:heroine_example/src/network_photo.dart';
import 'package:heroine_example/src/photos.dart';
import 'package:heroine_example/src/state_overlay.dart';

/// The caption both cards edit.
final captionController = TextEditingController();

/// A photo with a caption field on it. The field flies to the middle of the
/// page and keeps following its target while the keyboard opens.
class KeyboardCardExample extends StatelessWidget {
  const KeyboardCardExample({super.key});

  static const name = 'Keyboard';
  static const path = 'keyboard';

  /// The widest the caption gets.
  static const _maxCaptionWidth = 560.0;

  static final _photo = photos.firstWhere((photo) => photo.id == 29);

  @override
  Widget build(BuildContext context) {
    final gutter = DemoLayout.gutterOf(context);
    final padding = MediaQuery.paddingOf(context);
    return DemoPage(
      title: name,
      // The header sits on the page, above the photo, so its glyph and title
      // stay legible whatever the photo is.
      child: Stack(
        fit: StackFit.expand,
        children: [
          NetworkPhoto(
            _photo.fit(1600),
            background: CoilTheme.of(context).colors.muted,
            motion: CoilTheme.motionOf(context).fade,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                gutter + padding.left,
                gutter,
                gutter + padding.right,
                gutter + padding.bottom,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxCaptionWidth),
                child: Heroine(
                  tag: 'caption',
                  continuouslyTrackTarget: true,
                  child: CaptionCard(
                    onPressed: () => Navigator.of(context).push(
                      CardRoute<void>(
                        barrierColor: CoilTheme.of(context).colors.scrim,
                        builder: (context) => const CaptionPage(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The caption on a raised surface: collapsed it is one line that opens the
/// editor when pressed, expanded it is the editor.
///
/// With loose height it is as tall as its content. With tight constraints
/// (a heroine flight builds it at every size between the two) it fills
/// them, and shows as much of its content as fits.
class CaptionCard extends StatelessWidget {
  const CaptionCard({super.key, this.expanded = false, this.onPressed});

  final bool expanded;

  /// Called when the collapsed card is pressed.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).container);
    final content = expanded ? const _CaptionEditor() : const _CaptionLine();
    Widget card = CoilSurface(
      offset: CoilSurface.popoverOffset,
      borderRadius: radius,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.hasTightHeight
            ? ClipRSuperellipse(
                borderRadius: radius,
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: content,
                ),
              )
            : SizedBox(width: double.infinity, child: content),
      ),
    );
    if (!expanded) {
      card = Semantics(
        button: true,
        child: CoilInteraction(
          onPressed: onPressed,
          child: card,
          builder: (context, states, child) => CoilFocusRing(
            visible: states.contains(WidgetState.focused),
            borderRadius: radius,
            child: Stack(
              children: [
                child!,
                Positioned.fill(
                  child: ClipRSuperellipse(
                    borderRadius: radius,
                    child: StateOverlay(states: states),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return card;
  }
}

/// The caption, or a hint to add one, on one line.
class _CaptionLine extends StatelessWidget {
  const _CaptionLine();

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListenableBuilder(
        listenable: captionController,
        builder: (context, _) {
          final caption = captionController.text.replaceAll('\n', ' ').trim();
          return caption.isEmpty
              ? Text(
                  'Add a caption',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.muted.body,
                )
              : Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.body,
                );
        },
      ),
    );
  }
}

/// The caption field with its Done button.
class _CaptionEditor extends StatelessWidget {
  const _CaptionEditor();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        CoilInput.multiline(
          controller: captionController,
          autofocus: true,
          placeholder: const Text('Add a caption'),
          semanticLabel: 'Caption',
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: CoilButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ),
      ],
    ),
  );
}

/// The page the caption opens on: the editor over the photo, blurred
/// behind it, above the keyboard.
class CaptionPage extends StatelessWidget {
  const CaptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final gutter = DemoLayout.gutterOf(context);
    return ReactToHeroineDismiss(
      builder: (context, progress, offset, child) => BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: (1 - progress) * 20,
          sigmaY: (1 - progress) * 20,
        ),
        child: child,
      ),
      child: Padding(
        padding: MediaQuery.viewInsetsOf(context),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(gutter),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: KeyboardCardExample._maxCaptionWidth,
                ),
                child: DragDismissable(
                  child: Heroine(
                    tag: 'caption',
                    continuouslyTrackTarget: true,
                    motion: const CupertinoMotion.bouncy(),
                    child: const CaptionCard(expanded: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A route that fades in over the page below, which a tap outside the
/// content dismisses.
class CardRoute<T> extends PageRoute<T> with HeroinePageRouteMixin<T> {
  CardRoute({required this.builder, this.barrierColor, super.settings});

  final WidgetBuilder builder;

  @override
  final Color? barrierColor;

  @override
  bool get maintainState => false;

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  String? get barrierLabel => null;

  @override
  bool get barrierDismissible => true;

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
