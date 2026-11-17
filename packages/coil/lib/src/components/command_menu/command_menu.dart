import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/scroll_area.dart';
import 'package:flutter/widgets.dart';

/// Opens a command menu over the current route: a search field over
/// [entries], filtered as the user types. The filter matches each row's
/// `searchText`, so give every row one.
///
/// The arrows move through the matching rows and Enter runs one; picking a
/// row closes the menu, then runs its action. Escape or a tap outside
/// closes it. It opens near the top of a large window and as a sheet on a
/// phone.
///
/// Bind it to ⌘K (Ctrl+K off Apple platforms) the Flutter way: an intent of
/// the app's own, mapped in `Shortcuts` near the app's root (or registered
/// with `ShortcutRegistry` from any screen) and handled by `Actions` below
/// it, so a screen can bind the intent to something else:
///
/// ```dart
/// class OpenCommandMenuIntent extends Intent {
///   const OpenCommandMenuIntent();
/// }
///
/// final apple = switch (defaultTargetPlatform) {
///   TargetPlatform.iOS || TargetPlatform.macOS => true,
///   _ => false,
/// };
/// Shortcuts(
///   shortcuts: {
///     CharacterActivator('k', meta: apple, control: !apple):
///         const OpenCommandMenuIntent(),
///   },
///   child: Actions(
///     actions: {
///       OpenCommandMenuIntent: CallbackAction<OpenCommandMenuIntent>(
///         onInvoke: (_) =>
///             showCoilCommandMenu(context: context, entries: entries),
///       ),
///     },
///     child: home,
///   ),
/// )
/// ```
///
/// `CharacterActivator` matches the character the key types, so it follows
/// the keyboard layout.
///
/// ```dart
/// showCoilCommandMenu(
///   context: context,
///   entries: [
///     const CoilMenuLabel(Text('Navigation')),
///     CoilAction(
///       label: const Text('Go to inbox'),
///       searchText: 'Go to inbox',
///       onPressed: openInbox,
///     ),
///     CoilAction(
///       label: const Text('Go to settings'),
///       searchText: 'Go to settings',
///       onPressed: openSettings,
///     ),
///   ],
/// );
/// ```
Future<void> showCoilCommandMenu({
  required BuildContext context,
  required List<CoilMenuEntry> entries,
  Widget placeholder = const Text('Type a command or search…'),
  String semanticLabel = 'Type a command or search…',
  Widget empty = const Text('No results'),
  CoilMotion? motion,
}) => showCoilModal<void>(
  context: context,
  presentation: null,
  motion: motion,
  builder: (context) => CoilCommandMenu(
    entries: entries,
    placeholder: placeholder,
    semanticLabel: semanticLabel,
    empty: empty,
    motion: motion,
  ),
);

/// The panel [showCoilCommandMenu] opens: a search field over [entries].
///
/// Show it in a [CoilModalRoute] or [CoilModalPage] with no presentation,
/// so it's a sheet on a phone and centered elsewhere. In a sheet it uses
/// touch rows; centered, it sits a fifth of the way down the window.
class CoilCommandMenu extends StatelessWidget {
  /// Creates a command menu panel.
  const CoilCommandMenu({
    required this.entries,
    super.key,
    this.placeholder = const Text('Type a command or search…'),
    this.semanticLabel = 'Type a command or search…',
    this.empty = const Text('No results'),
    this.motion,
  });

  /// The rows and labels. The filter matches each row's `searchText`.
  final List<CoilMenuEntry> entries;

  /// The search field's hint, shown while it's empty.
  final Widget placeholder;

  /// The search field's name for screen readers.
  final String semanticLabel;

  /// What the list shows when nothing matches.
  final Widget empty;

  /// Motion tokens for the list, instead of the theme's.
  final CoilMotion? motion;

  /// The widest the panel gets.
  static const maxWidth = 560.0;

  /// The tallest the list gets in a window.
  static const maxListHeight = 360.0;

  @override
  Widget build(BuildContext context) {
    final sheet =
        CoilModalRoute.presentationOf(context) == CoilModalPresentation.sheet;
    final search = CoilMenuSearch(
      placeholder: placeholder,
      semanticLabel: semanticLabel,
      empty: empty,
    );
    final theme = CoilTheme.of(context);
    final metrics = sheet
        ? theme.metrics.resolve(CoilTier.touch, CoilSize.regular)
        : CoilTheme.metricsOf(context);
    final scroll = CoilScrollAreaStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilScrollAreaStyle>(context));
    // The list sits on the sheet's or the dialog's surface and fades into
    // it.
    final list = CoilActionList(
      entries: entries,
      search: search,
      metrics: metrics,
      scrollbar: scroll.scrollbarLook,
      fadeExtent: scroll.fadeExtent!,
      motion: motion,
      onClose: (_) => Navigator.pop(context),
    );

    if (sheet) {
      return CoilSheetPanel(child: list);
    }

    final window = MediaQuery.sizeOf(context);
    // Concentric with the rows, `popupInset` in.
    final radii = theme.shape.radii(metrics.tier);
    final radius = BorderRadius.circular(
      radii.concentric(
        radii.item,
        metrics.popupInset,
        innerExtent: metrics.controlHeight,
      ),
    );
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          // A fifth of the way down, where the eye rests after ⌘K.
          padding: EdgeInsets.only(
            top: window.height * 0.2,
            left: 16,
            right: 16,
          ),
          child: SizedBox(
            width: math.min(maxWidth, window.width - 32),
            child: CoilSurface(
              offset: CoilSurface.dialogOffset,
              borderRadius: radius,
              child: ClipRSuperellipse(
                borderRadius: radius,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: maxListHeight),
                  child: list,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
