import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/kbd.dart';
import 'package:coil/primitives.dart';
import 'package:coil/scroll_area.dart';
import 'package:flutter/widgets.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// Opens a command menu over the current route: a search field over [entries],
/// filtered as the user types.
///
/// The filter matches each row's `searchText`, so give every row one.
///
/// The arrows move through the matching rows and Enter runs one; picking a
/// row closes the menu, then runs its action. Escape or a tap outside
/// closes it. It opens near the top of a large window, with a [footer] of
/// key hints, and as a floating panel on a phone. Opened from a button,
/// pass the button's rect as [origin] ([CoilModalRoute.originOf] with the
/// button's context) and the floating panel shows it came from there.
///
/// [autofocus] puts the cursor in the search field as it opens (the
/// keyboard comes up on a phone); [holdHeight] keeps a floating panel's
/// height while the results change ([CoilCommandMenu.holdHeight]).
///
/// Bind it to ⌘K (Ctrl+K off Apple platforms) the Flutter way: an intent of
/// the app's own, mapped in [Shortcuts] near the app's root (or registered
/// with [ShortcutRegistry] from any screen) and handled by [Actions] below
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
/// [CharacterActivator] matches the character the key types, so it follows
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
  Widget? footer = const CoilCommandMenuFooter(),
  CoilMotion? motion,
  Rect? origin,
  bool autofocus = true,
  bool holdHeight = true,
}) => showCoilModal<void>(
  context: context,
  presentation: CoilCommandMenu.presentationOf(context),
  anchor: CoilModalAnchor.top,
  origin: origin,
  motion: motion,
  builder: (context) => CoilCommandMenu(
    entries: entries,
    placeholder: placeholder,
    semanticLabel: semanticLabel,
    empty: empty,
    footer: footer,
    motion: motion,
    autofocus: autofocus,
    holdHeight: holdHeight,
  ),
);

/// The panel [showCoilCommandMenu] opens: a search field over [entries],
/// and in a dialog a [footer] with key hints.
///
/// Show it in a [CoilModalRoute] or [CoilModalPage] with presentation
/// [presentationOf] and anchor [CoilModalAnchor.top]: a floating panel on a
/// phone and centered elsewhere. In a floating panel (or a sheet) it uses
/// touch rows and has no footer, and the panel keeps its height while the
/// results change, so the search field stays put; centered, it sits a fifth
/// of the way down the window, at most [maxHeight] or [maxHeightFraction] of
/// the window tall.
class CoilCommandMenu extends StatelessWidget {
  /// Creates a command menu panel.
  const CoilCommandMenu({
    required this.entries,
    super.key,
    this.placeholder = const Text('Type a command or search…'),
    this.semanticLabel = 'Type a command or search…',
    this.empty = const Text('No results'),
    this.footer = const CoilCommandMenuFooter(),
    this.motion,
    this.autofocus = true,
    this.holdHeight = true,
  });

  /// The rows and labels.
  ///
  /// The filter matches each row's `searchText`.
  final List<CoilMenuEntry> entries;

  /// The search field's hint, shown while it's empty.
  final Widget placeholder;

  /// The search field's name for screen readers.
  final String semanticLabel;

  /// What the list shows when nothing matches.
  final Widget empty;

  /// The strip under the list in a dialog: a [CoilCommandMenuFooter] with the
  /// default key hints, your own, or null for none.
  ///
  /// A sheet or floating panel (a phone, with no keyboard to hint at) never
  /// shows it.
  final Widget? footer;

  /// Motion tokens for the list, instead of the theme's.
  final CoilMotion? motion;

  /// Whether the search field takes focus as the menu opens, so typing
  /// filters at once. On a phone that raises the keyboard; pass false for a
  /// list that's mostly tapped, where the field narrows it on demand.
  final bool autofocus;

  /// Whether a floating panel fills its room, so it keeps its height and
  /// the search line stays put while the results change.
  ///
  /// False hugs the rows (up to the room) instead: right for a short list
  /// opened to pick from, where an empty panel below the rows reads as
  /// unfinished. A centered dialog or a sheet always hugs.
  final bool holdHeight;

  /// How a command menu shows at [context]: a floating panel on the touch tier
  /// in a compact window, centered elsewhere.
  ///
  /// Pass it, with [CoilModalAnchor.top], to the route that shows the menu.
  static CoilModalPresentation presentationOf(BuildContext context) =>
      CoilModalRoute.adaptivePresentationOf(context) ==
          CoilModalPresentation.sheet
      ? CoilModalPresentation.floating
      : CoilModalPresentation.centered;

  /// The widest the panel gets.
  static const maxWidth = 560.0;

  /// The tallest the panel gets in a window, search field and footer
  /// included.
  static const maxHeight = 440.0;

  /// The tallest the panel gets as a share of the window's height, when
  /// that's less than [maxHeight].
  static const maxHeightFraction = 0.76;

  /// The height of the search line on [tier]: 48 on the pointer tier, 52
  /// on touch.
  static double searchHeightOf(CoilTier tier) => switch (tier) {
    CoilTier.pointer => 48,
    CoilTier.touch => 52,
  };

  /// [child] filling a floating panel's room, so the panel keeps its height and
  /// the search line stays put while the results change.
  ///
  /// A sheet keeps hugging its content.
  Widget _fillFloating(BuildContext context, Widget child) =>
      holdHeight &&
          CoilModalRoute.presentationOf(context) ==
              CoilModalPresentation.floating
      ? SizedBox(height: double.infinity, child: child)
      : child;

  @override
  Widget build(BuildContext context) {
    final sheet =
        CoilModalRoute.presentationOf(context)?.usesSheetPanel ?? false;
    final theme = CoilTheme.of(context);
    final metrics = sheet
        ? theme.metrics.resolve(CoilTier.touch, CoilSize.regular)
        : CoilTheme.metricsOf(context);
    final searchHeight = searchHeightOf(metrics.tier);
    // A larger line than a menu's: the field is what the panel is for.
    final search = CoilMenuSearch(
      placeholder: placeholder,
      semanticLabel: semanticLabel,
      empty: empty,
      textStyle: theme.typography.resolve(metrics.tier, metrics.size).subtitle,
      minHeight: searchHeight,
      autofocus: autofocus,
    );
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
      // In a sheet or floating panel the close button ends the search line,
      // which takes the header's place.
      searchTrailing: sheet ? const CoilSheetCloseSlot() : null,
    );

    if (sheet) {
      return CoilSheetPanel(
        close: null,
        // The search line's middle runs through the close button's, the
        // corner's center: a 52 line reaches 2 into the sheet's top gap.
        child: _fillFloating(
          context,
          PaddingExtended(
            padding: EdgeInsets.only(
              top:
                  CoilSheetPanel.headerCenterOf(context) -
                  CoilSheetPanel.topGap -
                  searchHeight / 2,
            ),
            child: list,
          ),
        ),
      );
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
    final footer = this.footer;
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
                  constraints: BoxConstraints(
                    maxHeight: math.min(
                      maxHeight,
                      window.height * maxHeightFraction,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(child: list),
                      if (footer != null) footer,
                    ],
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

/// A key hint in a [CoilCommandMenuFooter]: what [keys] do.
@immutable
class CoilCommandMenuHint {
  /// Creates a hint.
  const CoilCommandMenuHint({required this.label, required this.keys});

  /// What the keys do, usually a [Text].
  final Widget label;

  /// The keys, usually a [CoilKbd].
  final Widget keys;
}

/// The strip under a [CoilCommandMenu]'s list in a dialog: what the keys
/// do there, each hint a muted caption followed by its key caps.
///
/// It sits under a hairline, one control high, with its text on the rows'
/// text edge. Screen readers skip it: the list and the field already say
/// what they do.
class CoilCommandMenuFooter extends StatelessWidget {
  /// Creates a footer with [hints].
  const CoilCommandMenuFooter({super.key, this.hints = defaultHints});

  /// The hints, from the start.
  final List<CoilCommandMenuHint> hints;

  /// Arrows select a row, Enter runs it, Escape closes the menu.
  static const defaultHints = [
    CoilCommandMenuHint(label: Text('Select'), keys: CoilKbd.keys(['↑', '↓'])),
    CoilCommandMenuHint(label: Text('Run'), keys: CoilKbd.keys(['↵'])),
    CoilCommandMenuHint(label: Text('Close'), keys: CoilKbd.keys(['esc'])),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final colors = theme.colors;
    final text = theme.typography.resolve(metrics.tier, metrics.size);
    // The list's separators: the hairline at 60 % of its own alpha.
    final line = colors.border.withValues(alpha: colors.border.a * 0.6);
    final style = text.caption.copyWith(color: colors.mutedForeground);
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 1, child: ColoredBox(color: line)),
          Padding(
            // One control high, its text on the rows' text edge.
            padding: EdgeInsets.symmetric(
              horizontal: metrics.popupInset + metrics.itemPaddingX,
              vertical: math.max(0, metrics.controlPaddingY(style)),
            ),
            child: DefaultTextStyle(
              style: style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              // One line: hints that don't fit are cut at the end, so
              // the footer never grows into the list's room.
              child: UnconstrainedBox(
                constrainedAxis: Axis.vertical,
                alignment: AlignmentDirectional.centerStart,
                clipBehavior: Clip.hardEdge,
                child: Row(
                  spacing: metrics.gap * 2,
                  children: [
                    for (final hint in hints)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: metrics.buttonGap,
                        children: [hint.label, hint.keys],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
