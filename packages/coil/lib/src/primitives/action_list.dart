import 'dart:async';
import 'dart:math' as math;

import 'package:coil/src/foundation/input_modality.dart';
import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/foundation/typography.dart';
import 'package:coil/src/primitives/active_item.dart';
import 'package:coil/src/primitives/anchor.dart';
import 'package:coil/src/primitives/drawn_glyph.dart';
import 'package:coil/src/primitives/edge_fade.dart';
import 'package:coil/src/primitives/hover.dart';
import 'package:coil/src/primitives/interaction.dart';
import 'package:coil/src/primitives/layer.dart';
import 'package:coil/src/primitives/popup_controller.dart';
import 'package:coil/src/primitives/scrollbar.dart';
import 'package:coil/src/primitives/text_field_core.dart';
import 'package:coil/src/primitives/typeahead.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// One entry of a [CoilActionList]: a [CoilAction] row, a [CoilSubmenu]
/// row, a [CoilMenuLabel] heading or a [CoilMenuSeparator].
@immutable
sealed class CoilMenuEntry {
  const CoilMenuEntry();
}

/// How a [CoilAction] reads.
enum CoilActionTone {
  /// An ordinary action.
  normal,

  /// An action that destroys something: red. Put it last, after a
  /// separator.
  destructive,
}

/// The mark a checkable [CoilAction] shows when [CoilAction.selected].
enum CoilActionMark {
  /// Not checkable.
  none,

  /// One of several independent options: a check.
  check,

  /// One choice among the rows around it: a dot.
  radio,
}

/// One row of a [CoilActionList].
class CoilAction extends CoilMenuEntry {
  /// Creates an action.
  const CoilAction({
    required this.label,
    this.searchText,
    this.semanticLabel,
    this.leading,
    this.shortcut,
    this.onPressed,
    this.tone = CoilActionTone.normal,
    this.mark = CoilActionMark.none,
    this.selected = false,
  });

  /// What the row shows, usually a [Text]. The row styles it and screen
  /// readers read it.
  final Widget label;

  /// The row as plain text: typeahead and a search field match it. Without
  /// it, they skip the row.
  final String? searchText;

  /// Names the action where it shows as an icon only, such as a sidebar
  /// row's action button.
  final String? semanticLabel;

  /// A glyph before the label, styled by [IconTheme].
  final Widget? leading;

  /// The keyboard shortcut, shown at the end of the row on the pointer tier
  /// only (a finger has no keyboard).
  final Widget? shortcut;

  /// Runs the action. Null disables the row.
  final VoidCallback? onPressed;

  /// How the row reads.
  final CoilActionTone tone;

  /// Whether the row is checkable, and how it shows [selected].
  final CoilActionMark mark;

  /// Whether a checkable row is on: semibold, with its mark.
  final bool selected;

  /// Whether the row can be picked.
  bool get enabled => onPressed != null;
}

/// A row that opens more [entries]: beside the menu for a pointer, in its
/// place on touch.
class CoilSubmenu extends CoilMenuEntry {
  /// Creates a submenu row.
  const CoilSubmenu({
    required this.label,
    required this.entries,
    this.searchText,
    this.semanticLabel,
    this.leading,
  });

  /// What the row shows, usually a [Text]; also the back row's label in a
  /// touch submenu.
  final Widget label;

  /// The row as plain text: typeahead and a search field match it.
  final String? searchText;

  /// Names the submenu where it shows as an icon only, such as a sidebar
  /// row's action button.
  final String? semanticLabel;

  /// A glyph before the label, styled by [IconTheme].
  final Widget? leading;

  /// The submenu's rows, headings and separators.
  final List<CoilMenuEntry> entries;

  /// Whether the row can open: when the submenu has rows.
  bool get enabled =>
      entries.any((entry) => entry is CoilAction || entry is CoilSubmenu);

  /// How many submenu levels [entries] nest, counting this one.
  static int depthOf(List<CoilMenuEntry> entries) => entries.fold(
    0,
    (depth, entry) => entry is CoilSubmenu
        ? math.max(depth, 1 + depthOf(entry.entries))
        : depth,
  );
}

/// A search field over a [CoilActionList] that filters its rows by their
/// `searchText`.
@immutable
class CoilMenuSearch {
  /// Describes the search field.
  const CoilMenuSearch({
    this.placeholder = const Text('Search'),
    this.semanticLabel = 'Search',
    this.empty = const Text('No results'),
  });

  /// The field's placeholder, usually a [Text].
  final Widget placeholder;

  /// The field's name for screen readers.
  final String semanticLabel;

  /// Shown when no row matches, usually a [Text].
  final Widget empty;
}

/// A heading over a group of rows.
class CoilMenuLabel extends CoilMenuEntry {
  /// Creates a heading.
  const CoilMenuLabel(this.label);

  /// The heading, usually a [Text], styled as a muted caption.
  final Widget label;
}

/// A hairline between groups of rows.
class CoilMenuSeparator extends CoilMenuEntry {
  /// Creates a separator.
  const CoilMenuSeparator();
}

/// A menu's rows, headings and separators, for a popover or a sheet.
///
/// A hovering pointer lights rows with a gliding highlight. The arrow keys,
/// Home and End move between enabled rows, typing jumps to a row by its
/// `searchText`, and Enter or Space picks. Escape and Tab dismiss. Opened
/// from the keyboard, the list starts on the first row with a focus ring.
///
/// Picking an action calls [onClose] with [CoilPopupCloseReason.selected]
/// and then runs it. Picking a checkable row runs it first and closes after
/// the theme's `acknowledgeDuration`, so the mark lands before the menu
/// goes. On the touch tier of [metrics], rows rest at full
/// strength, since a finger can't hover.
///
/// With [search], a field above the rows filters them.
///
/// The rows scroll when the list is taller than its room, with edges that
/// fade into [surface].
///
/// A [CoilSubmenu] row opens its list beside this one for a pointer: on a
/// 100 ms hover, a click, Enter, Space or the arrow toward its side. The
/// pointer can cross other rows on its way there. [submenu] wraps that list
/// in its surface. On the touch tier the submenu replaces the rows instead,
/// under a back row.
class CoilActionList extends StatefulWidget {
  /// Creates an action list.
  const CoilActionList({
    required this.entries,
    required this.onClose,
    required this.metrics,
    required this.surface,
    required this.scrollbar,
    super.key,
    this.fadeExtent = 32,
    this.highlight,
    this.pressFill,
    this.radius,
    this.submenu,
    this.onBack,
    this.search,
    this.motion,
  });

  /// The rows, headings and separators.
  final List<CoilMenuEntry> entries;

  /// Wraps a pointer submenu's list in its popover surface.
  final Widget Function(BuildContext context, Widget list)? submenu;

  /// Called by the arrow away from a submenu's side: a submenu closes
  /// itself with it.
  final VoidCallback? onBack;

  /// Shows a search field that keeps focus and filters the rows: typing
  /// narrows them to labels that contain the text, the arrows move through
  /// the matches and Enter picks one. Headings and separators stay with
  /// their matching rows.
  final CoilMenuSearch? search;

  /// Called when a pick, Escape or Tab closes the menu.
  final ValueChanged<CoilPopupCloseReason> onClose;

  /// The row sizes, and the tier that picks the rows' resting emphasis.
  final CoilMetrics metrics;

  /// The color behind the list, which the scroll edges fade into.
  final Color surface;

  /// How the scrollbar looks.
  final CoilScrollbarLook scrollbar;

  /// How far each scroll edge fade reaches.
  final double fadeExtent;

  /// The hover highlight; the theme's `hover` tint when null.
  final Color? highlight;

  /// The fill under a row while a finger presses it; the theme's `active`
  /// tint when null.
  final Color? pressFill;

  /// The row corner radius; the theme's item radius when null.
  final double? radius;

  /// Overrides the theme's motion tokens for this list.
  final CoilMotion? motion;

  @override
  State<CoilActionList> createState() => _CoilActionListState();
}

class _CoilActionListState extends State<CoilActionList>
    with TickerProviderStateMixin {
  final _active = CoilActiveItemController();
  final _query = TextEditingController();
  late List<CoilMenuEntry?> _items = _compute();
  late List<GlobalKey> _rowKeys = _keysFor(_items.length);
  Timer? _acknowledge;

  /// Whether a pick is being acknowledged: from a checkable row's pick (in
  /// this list or a submenu) until the menu closes, the list ignores the
  /// pointer and the keys, so the highlight stays on the picked row and
  /// nothing else can be picked.
  bool _frozen = false;

  void _freeze() {
    if (_frozen) return;
    setState(() => _frozen = true);
    _FreezeScope.maybeOf(context)?.call();
  }

  /// The rows of the touch submenus drilled into, from the top.
  final _path = <int>[];

  /// The pointer submenu's row, while it is open.
  int? _sub;
  Timer? _subTimer;
  final _subControllers = <int, CoilPopoverController>{};
  final _subLists = <int, GlobalKey>{};

  /// Where the pointer last was over [_sub]'s row: the safe triangle's tip.
  Offset? _apex;

  static List<GlobalKey> _keysFor(int count) => [
    for (var i = 0; i < count; i++) GlobalKey(debugLabel: 'CoilActionList $i'),
  ];

  bool get _touch => widget.metrics.tier == CoilTier.touch;

  /// The rows shown: a drilled-into submenu's under a back row (null), or
  /// the list's own, narrowed by the search text.
  List<CoilMenuEntry?> _compute() {
    final open = _drilled;
    final level = open == null ? widget.entries : [null, ...open.entries];
    final query = _query.text.trim().toLowerCase();
    return widget.search == null || query.isEmpty
        ? level
        : _filter(level, query);
  }

  /// The rows of [level] whose labels contain [query], with the headings
  /// over them and one separator between groups that kept rows.
  static List<CoilMenuEntry?> _filter(
    List<CoilMenuEntry?> level,
    String query,
  ) {
    final shown = <CoilMenuEntry?>[];
    CoilMenuLabel? heading;
    var gap = false;
    for (final entry in level) {
      switch (entry) {
        case null:
          shown.add(null);
        case CoilMenuSeparator():
          gap = shown.isNotEmpty;
          heading = null;
        case final CoilMenuLabel label:
          heading = label;
        case CoilAction() || CoilSubmenu()
            when _searchTextOf(entry)?.toLowerCase().contains(query) ?? false:
          if (gap) shown.add(const CoilMenuSeparator());
          if (heading != null) shown.add(heading);
          shown.add(entry);
          gap = false;
          heading = null;
        case _:
      }
    }
    return shown;
  }

  /// Recomputes the rows after the entries, the path or the text changed.
  void _refresh() {
    _items = _compute();
    if (_rowKeys.length != _items.length) _rowKeys = _keysFor(_items.length);
  }

  void _onQuery() {
    if (_sub != null) _closeSub();
    setState(_refresh);
    // The first match is the one Enter picks.
    if (_query.text.trim().isEmpty) {
      _active.clear();
    } else {
      _active.first(count: _count, isEnabled: _enabled);
    }
  }

  /// The submenu drilled into, if any.
  CoilSubmenu? get _drilled {
    CoilSubmenu? sub;
    for (final row in _path) {
      sub = (sub?.entries ?? widget.entries)[row] as CoilSubmenu;
    }
    return sub;
  }

  /// Whether [_path] still leads through submenus of the current entries.
  bool get _pathValid {
    var entries = widget.entries;
    for (final row in _path) {
      if (row >= entries.length) return false;
      final entry = entries[row];
      if (entry is! CoilSubmenu) return false;
      entries = entry.entries;
    }
    return true;
  }

  int get _count => _items.length;
  bool _enabled(int i) => switch (_items[i]) {
    null => true,
    final CoilAction action => action.enabled,
    final CoilSubmenu sub => sub.enabled,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    _startKeyboard();
    _active.addListener(_onActive);
    _query.addListener(_onQuery);
  }

  @override
  void didUpdateWidget(CoilActionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_pathValid) _path.clear();
    _refresh();
    if (_sub case final sub?
        when sub >= _count || _items[sub] is! CoilSubmenu) {
      _closeSub();
    }
  }

  @override
  void dispose() {
    _acknowledge?.cancel();
    _subTimer?.cancel();
    _query.dispose();
    _active
      ..removeListener(_onActive)
      ..dispose();
    super.dispose();
  }

  /// Opened from the keyboard, a list starts on its first row.
  void _startKeyboard() {
    if (CoilInputModality.instance.value == CoilModality.keyboard) {
      _active.first(count: _count, isEnabled: _enabled);
    }
  }

  void _onActive() {
    _reveal();
    final i = _active.index;
    _subTimer?.cancel();
    if (_sub != null && i != _sub) _closeSub();
    if (i != null &&
        i != _sub &&
        !_touch &&
        _active.via == CoilModality.pointer &&
        _items[i] is CoilSubmenu) {
      _subTimer = Timer(
        const Duration(milliseconds: 100),
        () => _openSub(i),
      );
    }
  }

  /// Scrolls a row the keyboard made active into view.
  void _reveal() {
    if (!_active.keyboardDriven) return;
    final i = _active.index;
    final row = i == null ? null : _rowKeys[i].currentContext;
    if (row == null) return;
    Scrollable.ensureVisible(
      row,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    Scrollable.ensureVisible(
      row,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  /// Closes the menu, then runs the action. A checkable row runs first and
  /// closes once its mark has landed. A submenu row opens its submenu, and
  /// the back row leaves one.
  void _pick(int i) {
    if (_frozen || !_enabled(i)) return;
    switch (_items[i]) {
      case null:
        _back();
      case CoilSubmenu():
        _touch ? _drill(i) : _openSub(i);
      case final CoilAction action when action.mark == CoilActionMark.none:
        widget.onClose(CoilPopupCloseReason.selected);
        action.onPressed?.call();
      case final CoilAction action:
        action.onPressed?.call();
        _freeze();
        _acknowledge?.cancel();
        _acknowledge = Timer(
          CoilTheme.motionOf(
            context,
            override: widget.motion,
          ).acknowledgeDuration,
          () => widget.onClose(CoilPopupCloseReason.selected),
        );
      case _:
    }
  }

  void _drill(int i) {
    setState(() {
      // The back row shifts a drilled-into submenu's rows by one.
      _path.add(_path.isEmpty ? i : i - 1);
      _refresh();
    });
    _active.clear();
    _startKeyboard();
  }

  /// Leaves a touch submenu for its parent rows, on the row it opened from.
  void _back() {
    if (_path.isEmpty) {
      widget.onBack?.call();
      return;
    }
    final keyboard = _active.keyboardDriven;
    final row = _path.last + (_path.length > 1 ? 1 : 0);
    setState(() {
      _path.removeLast();
      _refresh();
    });
    _active.activate(
      keyboard ? row : null,
      via: keyboard ? CoilModality.keyboard : CoilModality.pointer,
    );
  }

  void _openSub(int i) {
    _subTimer?.cancel();
    if (_sub == i) return;
    if (_sub != null) _closeSub();
    if (!_enabled(i)) return;
    setState(() => _sub = i);
    _subControllers[i]?.show();
  }

  void _closeSub() {
    final i = _sub;
    if (i == null) return;
    _subControllers[i]?.hide();
    _apex = null;
    setState(() => _sub = null);
  }

  /// A pick or a dismissal in the submenu closes the whole menu; Escape, a
  /// tap outside it or the back arrow close only the submenu.
  void _subClosed(CoilPopupCloseReason reason) {
    _closeSub();
    if (reason == CoilPopupCloseReason.selected ||
        reason == CoilPopupCloseReason.dismissed) {
      widget.onClose(reason);
    }
  }

  /// Whether the pointer at [position] is on its way to the open submenu:
  /// over it, or inside the triangle from where it left the row to the
  /// submenu's near edge. Hover doesn't move off the row meanwhile.
  bool _hold(Offset position) {
    // An acknowledged pick keeps its row lit.
    if (_frozen) return true;
    final i = _sub;
    if (i == null) return false;
    final row = _globalRect(_rowKeys[i]);
    final sub = _subLists[i] == null ? null : _globalRect(_subLists[i]!);
    if (row == null || sub == null) return false;
    if (row.contains(position)) {
      _apex = position;
      return false;
    }
    if (sub.contains(position)) return true;
    final apex = _apex;
    if (apex == null) return false;
    final right = sub.center.dx > row.center.dx;
    final b = right ? sub.topLeft : sub.topRight;
    final c = right ? sub.bottomLeft : sub.bottomRight;
    return _inTriangle(position, apex, b, c);
  }

  static Rect? _globalRect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }

  static bool _inTriangle(Offset p, Offset a, Offset b, Offset c) {
    double side(Offset p1, Offset p2, Offset p3) =>
        (p1.dx - p3.dx) * (p2.dy - p3.dy) - (p2.dx - p3.dx) * (p1.dy - p3.dy);
    final d1 = side(p, a, b);
    final d2 = side(p, b, c);
    final d3 = side(p, c, a);
    final negative = d1 < 0 || d2 < 0 || d3 < 0;
    final positive = d1 > 0 || d2 > 0 || d3 > 0;
    return !(negative && positive);
  }

  /// Opens the active submenu row; on any other row does nothing.
  void _forward() {
    final i = _active.index;
    if (i != null && _items[i] is CoilSubmenu) _pick(i);
  }

  /// The search text of [entry]; headings, separators and rows without
  /// one match nothing.
  static String? _searchTextOf(CoilMenuEntry? entry) => switch (entry) {
    final CoilAction action => action.searchText,
    final CoilSubmenu sub => sub.searchText,
    _ => null,
  };

  void _pickActive() {
    if (_active.index case final i?) _pick(i);
  }

  Widget _subPopover(int i, CoilSubmenu sub, Widget row) {
    final metrics = widget.metrics;
    return CoilPopover(
      controller: _subControllers.putIfAbsent(
        i,
        () => CoilPopoverController(debugLabel: 'CoilActionList.submenu'),
      ),
      onClose: _subClosed,
      axis: Axis.horizontal,
      sideOffset: metrics.popupInset + 2,
      crossOffset: metrics.popupInset,
      minWidth: 0,
      motion: widget.motion,
      popover: (context) {
        final list = _FreezeScope(
          freeze: _freeze,
          child: CoilActionList(
            key: _subLists.putIfAbsent(
              i,
              () => GlobalKey(debugLabel: 'CoilActionList.submenu $i'),
            ),
            entries: sub.entries,
            onClose: _subClosed,
            onBack: _closeSub,
            metrics: metrics,
            surface: widget.surface,
            scrollbar: widget.scrollbar,
            fadeExtent: widget.fadeExtent,
            highlight: widget.highlight,
            pressFill: widget.pressFill,
            radius: widget.radius,
            submenu: widget.submenu,
            motion: widget.motion,
          ),
        );
        return widget.submenu?.call(context, list) ?? list;
      },
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final metrics = widget.metrics;
    final radius = widget.radius ?? theme.shape.radii(metrics.tier).item;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final items = _items;
    final pressFill = widget.pressFill ?? theme.colors.active;
    Widget row(int i, CoilAction action, {Widget? trailing, bool? expanded}) =>
        CoilHoverItem(
          key: _rowKeys[i],
          index: i,
          enabled: action.enabled,
          child: _Row(
            index: i,
            action: action,
            trailing: trailing,
            expanded: expanded,
            active: _active,
            metrics: metrics,
            radius: radius,
            pressFill: pressFill,
            motion: motion,
            onPressed: action.enabled ? () => _pick(i) : null,
          ),
        );
    final searching = widget.search != null;
    final bindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
          _active.move(1, count: _count, isEnabled: _enabled),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
          _active.move(-1, count: _count, isEnabled: _enabled),
      // In a search field these keys edit the text.
      if (!searching) ...{
        SingleActivator(
          rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight,
        ): _forward,
        SingleActivator(
          rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft,
        ): _back,
        const SingleActivator(LogicalKeyboardKey.home): () =>
            _active.first(count: _count, isEnabled: _enabled),
        const SingleActivator(LogicalKeyboardKey.end): () =>
            _active.last(count: _count, isEnabled: _enabled),
        const SingleActivator(LogicalKeyboardKey.space, includeRepeats: false):
            _pickActive,
      },
      const SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false):
          _pickActive,
      const SingleActivator(
        LogicalKeyboardKey.numpadEnter,
        includeRepeats: false,
      ): _pickActive,
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          widget.onClose(CoilPopupCloseReason.escape),
      const SingleActivator(LogicalKeyboardKey.tab): () =>
          widget.onClose(CoilPopupCloseReason.dismissed),
    };
    // While a pick is acknowledged, the list's keys do nothing (and don't
    // reach anything else).
    if (_frozen) {
      for (final key in [...bindings.keys]) {
        bindings[key] = () {};
      }
    }
    final list = Semantics(
      role: SemanticsRole.menu,
      child: CoilScrollEdgeFade.solid(
        color: widget.surface,
        extent: widget.fadeExtent,
        child: ScrollConfiguration(
          behavior: CoilScrollBehavior(
            tier: metrics.tier,
            look: widget.scrollbar,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(metrics.popupInset),
            // The region and its layer scroll with the rows, so the
            // highlight and the ring stay on their rows.
            child: CoilHoverRegion(
              activeItem: _active,
              followFocus: false,
              hold: _hold,
              child: ListenableBuilder(
                listenable: _active,
                builder: (context, rows) {
                  final ring = CoilHighlight(
                    debugLabel: 'CoilActionList.ring',
                    target: _active.keyboardDriven ? _active.index : null,
                    fadeIn: false,
                    motion: motion.quick,
                    exitMotion: motion.fadeExit,
                    exitTravelMotion: motion.quick,
                    fade: motion.fade,
                    inflate: 1 + theme.focusRingWidth,
                    decoration: ShapeDecoration(
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(
                          theme.shape.radii(metrics.tier).focusRing,
                        ),
                        side: BorderSide(
                          color: theme.colors.focusRing,
                          width: theme.focusRingWidth,
                        ),
                      ),
                    ),
                  );
                  return CoilHoverHighlight(
                    color: widget.highlight,
                    radius: radius,
                    motion: widget.motion,
                    foreground: [ring],
                    child: rows!,
                  );
                },
                child: IgnorePointer(
                  ignoring: _frozen,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, entry) in items.indexed)
                        switch (entry) {
                          null => row(
                            i,
                            CoilAction(
                              label: _drilled!.label,
                              leading: const CoilDrawnGlyph(
                                CoilGlyph.chevronStart,
                              ),
                              onPressed: _back,
                            ),
                          ),
                          final CoilAction action => row(i, action),
                          final CoilSubmenu sub when _touch => row(
                            i,
                            _asAction(sub),
                            trailing: const CoilDrawnGlyph(
                              CoilGlyph.chevronEnd,
                            ),
                          ),
                          final CoilSubmenu sub => _subPopover(
                            i,
                            sub,
                            row(
                              i,
                              _asAction(sub),
                              trailing: const CoilDrawnGlyph(
                                CoilGlyph.chevronEnd,
                              ),
                              expanded: _sub == i,
                            ),
                          ),
                          final CoilMenuLabel label => _GroupLabel(
                            key: _rowKeys[i],
                            label: label.label,
                            metrics: metrics,
                          ),
                          CoilMenuSeparator() => _Separator(
                            key: _rowKeys[i],
                            inset: metrics.popupInset,
                          ),
                        },
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.search case final search?) {
      // The field keeps focus and drives the list. Its shortcuts are off
      // while an IME composes, so Enter commits the composition first.
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchField(
            controller: _query,
            search: search,
            metrics: metrics,
            onSubmitted: _pickActive,
            shortcuts: {
              for (final MapEntry(:key, :value) in bindings.entries)
                key: VoidCallbackIntent(value),
            },
          ),
          const _Separator(inset: 0, padding: EdgeInsets.zero),
          Flexible(
            child: items.isEmpty
                ? _Empty(label: search.empty, metrics: metrics)
                : list,
          ),
        ],
      );
    }
    return CallbackShortcuts(
      bindings: bindings,
      child: ListenableBuilder(
        listenable: _active,
        builder: (context, child) => CoilTypeahead(
          searchTexts: [for (final entry in items) _searchTextOf(entry)],
          current: _active.index,
          isEnabled: (i) => !_frozen && _enabled(i),
          onMatch: (i) => _active.activate(i, via: CoilModality.keyboard),
          child: child!,
        ),
        child: Focus(
          autofocus: true,
          debugLabel: 'CoilActionList',
          child: list,
        ),
      ),
    );
  }

  /// A submenu's row as an action that does nothing itself.
  static CoilAction _asAction(CoilSubmenu sub) => CoilAction(
    label: sub.label,
    searchText: sub.searchText,
    leading: sub.leading,
    onPressed: sub.enabled ? () {} : null,
  );
}

/// One row: leading glyph and label. It paints only its own press fill;
/// the list's layer paints the highlight and the ring.
class _Row extends StatefulWidget {
  const _Row({
    required this.index,
    required this.action,
    required this.active,
    required this.metrics,
    required this.radius,
    required this.pressFill,
    required this.motion,
    required this.onPressed,
    this.trailing,
    this.expanded,
  });

  final int index;
  final CoilAction action;

  /// Shown at the row's end instead of the shortcut: a submenu's chevron.
  final Widget? trailing;

  /// Whether the row's submenu is open; null for rows without one.
  final bool? expanded;
  final CoilActiveItemController active;
  final CoilMetrics metrics;
  final double radius;
  final Color pressFill;
  final CoilMotion motion;
  final VoidCallback? onPressed;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final metrics = widget.metrics;
    final motion = widget.motion;
    final enabled = widget.onPressed != null;
    final touch = metrics.tier == CoilTier.touch;
    // The active row is lit by the pointer or, when the keyboard moved it
    // there, focused.
    final lit = CoilHoverRegion.maybeOf(context)?.activeIndex == widget.index;
    final keyboard = widget.active.keyboardDriven;
    final radius = BorderRadius.circular(widget.radius);
    final action = widget.action;
    return Semantics(
      role: switch (action.mark) {
        CoilActionMark.none => SemanticsRole.menuItem,
        CoilActionMark.check => SemanticsRole.menuItemCheckbox,
        CoilActionMark.radio => SemanticsRole.menuItemRadio,
      },
      checked: action.mark == CoilActionMark.none ? null : action.selected,
      expanded: widget.expanded,
      enabled: enabled,
      container: true,
      onTap: widget.onPressed,
      child: Opacity(
        opacity: enabled ? 1 : widget.metrics.disabledRowOpacity,
        // Rows aren't focus stops: the list holds focus and the active item
        // says which row Enter picks.
        child: CoilInteractionDetector(
          states: _states,
          enabled: enabled,
          onTap: widget.onPressed,
          excludeFromSemantics: true,
          child: ListenableBuilder(
            listenable: _states,
            builder: (context, child) {
              final raw = CoilInteractionDetector.statesFor(
                _states.value,
                enabled: enabled,
              );
              final states = {
                ...raw,
                if (lit && keyboard) WidgetState.focused,
                if (lit && !keyboard) WidgetState.hovered,
              };
              final pressed = states.contains(WidgetState.pressed);
              // Touch rows rest at full strength: the muted to foreground
              // change says "the pointer is here", which a finger can't.
              final emphasized =
                  touch ||
                  pressed ||
                  states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused);
              final color = action.tone == CoilActionTone.destructive
                  ? colors.redLabel
                  : emphasized || action.selected
                  ? colors.foreground
                  : colors.mutedForeground;
              // A finger gets a fill while it presses; a hovering pointer
              // already shows the highlight.
              final fill = pressed && !raw.contains(WidgetState.hovered)
                  ? widget.pressFill
                  : widget.pressFill.withValues(alpha: 0);
              return MotionBuilder<Color>(
                value: fill,
                converter: MotionConverter.colorRgb,
                motion: pressed ? motion.fade : motion.fadeExit,
                debugLabel: 'CoilActionList.press',
                builder: (context, fill, child) => DecoratedBox(
                  decoration: ShapeDecoration(
                    color: fill,
                    shape: RoundedSuperellipseBorder(borderRadius: radius),
                  ),
                  child: child,
                ),
                child: MotionBuilder<Color>(
                  value: color,
                  converter: MotionConverter.colorRgb,
                  motion: motion.fade,
                  debugLabel: 'CoilActionList.label',
                  builder: (context, color, _) => _RowContent(
                    action: widget.action,
                    trailing: widget.trailing,
                    metrics: metrics,
                    color: color,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The leading glyph, label and trailing shortcut or mark, at least a
/// control tall and centered in it.
class _RowContent extends StatelessWidget {
  const _RowContent({
    required this.action,
    required this.metrics,
    required this.color,
    this.trailing,
  });

  final CoilAction action;
  final Widget? trailing;
  final CoilMetrics metrics;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final pointer = metrics.tier == CoilTier.pointer;
    final mark = switch (action.mark) {
      CoilActionMark.none => null,
      _ when !action.selected => SizedBox.square(dimension: metrics.iconSize),
      CoilActionMark.check => IconTheme.merge(
        data: const IconThemeData(weight: CoilIconWeight.emphasis),
        child: const CoilDrawnGlyph(CoilGlyph.check),
      ),
      CoilActionMark.radio => SizedBox.square(
        dimension: metrics.iconSize,
        child: Center(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: color,
              shape: const RoundedSuperellipseBorder(
                borderRadius: BorderRadius.all(Radius.circular(3)),
              ),
            ),
            child: const SizedBox.square(dimension: 6),
          ),
        ),
      ),
    };
    final shortcut = pointer ? action.shortcut : null;
    final trailing = this.trailing;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: metrics.controlHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: metrics.itemPaddingX),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          heightFactor: 1,
          child: IconTheme(
            data: IconThemeData(
              size: metrics.iconSize,
              applyTextScaling: true,
              color: color,
            ),
            child: DefaultTextStyle(
              style: theme.typography.style(
                metrics.body,
                weight: action.selected
                    ? CoilWeight.semibold
                    : CoilWeight.normal,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: Row(
                spacing: metrics.gap,
                children: [
                  // The row reads its label only.
                  if (action.leading case final leading?)
                    ExcludeSemantics(child: leading),
                  Expanded(child: action.label),
                  if (shortcut != null)
                    ExcludeSemantics(
                      child: DefaultTextStyle(
                        style: theme.typography.style(
                          metrics.caption,
                          color: theme.colors.mutedForeground,
                        ),
                        child: shortcut,
                      ),
                    ),
                  if (mark != null) ExcludeSemantics(child: mark),
                  if (trailing != null) ExcludeSemantics(child: trailing),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A heading over a group of rows: a muted caption.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label, required this.metrics, super.key});

  final Widget label;
  final CoilMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.itemPaddingX,
          8,
          metrics.itemPaddingX,
          6,
        ),
        child: DefaultTextStyle(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.style(
            metrics.caption,
            color: theme.colors.mutedForeground,
          ),
          child: label,
        ),
      ),
    );
  }
}

/// A hairline between groups, reaching the popup's edges.
class _Separator extends StatelessWidget {
  const _Separator({
    required this.inset,
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  /// The popup's padding, which the line reaches across.
  final double inset;

  /// The space around the line.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // FF's `bg-border/60`: 60 % of the hairline's own alpha (the border
    // token is foreground at 12 %, 40 % in high contrast).
    final border = CoilTheme.of(context).colors.border;
    return Padding(
      padding: padding,
      // Negative side padding reaches across the popup's inset.
      child: PaddingExtended(
        padding: EdgeInsets.symmetric(horizontal: -inset),
        child: SizedBox(
          height: 1,
          child: ColoredBox(color: border.withValues(alpha: border.a * 0.6)),
        ),
      ),
    );
  }
}

/// The search field over a filtered list: a borderless line of text that
/// keeps focus and hands the list's keys to it.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.search,
    required this.metrics,
    required this.shortcuts,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final CoilMenuSearch search;
  final CoilMetrics metrics;
  final Map<ShortcutActivator, Intent> shortcuts;

  /// The soft keyboard's search key: picks the active row.
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    return Semantics(
      label: search.semanticLabel,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: metrics.controlHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.popupInset + metrics.itemPaddingX,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            heightFactor: 1,
            child: CoilTextFieldCore(
              controller: controller,
              autofocus: true,
              placeholder: search.placeholder,
              placeholderColor: colors.mutedForeground,
              style: theme.typography.style(
                metrics.body,
                color: colors.foreground,
              ),
              cursorColor: colors.foreground,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              onSubmitted: (_) => onSubmitted(),
              shortcuts: shortcuts,
            ),
          ),
        ),
      ),
    );
  }
}

/// What a search shows when no row matches.
class _Empty extends StatelessWidget {
  const _Empty({required this.label, required this.metrics});

  final Widget label;
  final CoilMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: EdgeInsets.all(metrics.popupInset + metrics.itemPaddingX),
        child: DefaultTextStyle(
          textAlign: TextAlign.center,
          style: theme.typography.style(
            metrics.body,
            color: theme.colors.mutedForeground,
          ),
          child: label,
        ),
      ),
    );
  }
}

/// Lets a submenu's list freeze the lists it opened from when it
/// acknowledges a pick, so the whole menu ignores input until it closes.
class _FreezeScope extends InheritedWidget {
  const _FreezeScope({required this.freeze, required super.child});

  final VoidCallback freeze;

  static VoidCallback? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_FreezeScope>()?.freeze;

  @override
  bool updateShouldNotify(_FreezeScope oldWidget) => false;
}
