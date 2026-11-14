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
/// phone. Bind it to a shortcut such as ⌘K with a `CallbackShortcuts` near
/// the app's root.
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
}) {
  final sheet =
      CoilTheme.tierOf(context) == CoilTier.touch &&
      MediaQuery.sizeOf(context).width < CoilAdaptivePopup.compactWidth;
  return showCoilModal<void>(
    context: context,
    presentation: sheet
        ? CoilModalPresentation.sheet
        : CoilModalPresentation.centered,
    motion: motion,
    builder: (context) => _CommandMenu(
      entries: entries,
      search: CoilMenuSearch(
        placeholder: placeholder,
        semanticLabel: semanticLabel,
        empty: empty,
      ),
      sheet: sheet,
      motion: motion,
    ),
  );
}

class _CommandMenu extends StatelessWidget {
  const _CommandMenu({
    required this.entries,
    required this.search,
    required this.sheet,
    required this.motion,
  });

  final List<CoilMenuEntry> entries;
  final CoilMenuSearch search;
  final bool sheet;
  final CoilMotion? motion;

  /// The widest the panel gets.
  static const maxWidth = 560.0;

  /// The tallest the list gets in a window.
  static const maxListHeight = 360.0;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = sheet
        ? theme.metrics.resolve(CoilTier.touch, CoilSize.regular)
        : CoilTheme.metricsOf(context);
    final scroll = CoilScrollAreaStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilScrollAreaStyle>(context));
    Widget list(Color surface) => CoilActionList(
      entries: entries,
      search: search,
      metrics: metrics,
      surface: surface,
      scrollbar: scroll.scrollbarLook,
      fadeExtent: scroll.fadeExtent!,
      motion: motion,
      onClose: (_) => Navigator.pop(context),
    );

    if (sheet) {
      return CoilSheetPanel(child: list(theme.colors.surface(3)));
    }

    final window = MediaQuery.sizeOf(context);
    final radius = BorderRadius.circular(
      theme.shape.radii(metrics.tier).container,
    );
    final level = CoilSurface.levelOf(context) + CoilSurface.dialogOffset;
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
                  child: list(theme.colors.surface(level)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
