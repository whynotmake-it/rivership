import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// KeepDir
// ---------------------------------------------------------------------------

/// Defines which side of a widget is visible when occluded by an [OverHeroine].
///
/// Example: [KeepDir.bottom] means "keep the content below the OverHeroine",
/// which is useful when an AppBar at the top occludes the top of a widget.
enum KeepDir { top, bottom, left, right }

// ---------------------------------------------------------------------------
// OverHeroineScope
// ---------------------------------------------------------------------------

/// A per-route scope that collects all [OverHeroine] widgets' positions.
///
/// Must be placed above both the [OverHeroine] widgets and the [Heroine]
/// so that the [ClippingShuttleBuilder] can find them.
///
/// Use: wrap your page's top-level content.
///
/// ```dart
/// OverHeroineScope(
///   child: Stack(
///     children: [
///       OverHeroine(keepDir: KeepDir.bottom, child: AppBar(...)),
///       ListView(
///         children: [
///           Heroine(
///             flightShuttleBuilder: ClippingShuttleBuilder(inner: ...),
///             child: ...,
///           ),
///         ],
///       ),
///     ],
///   ),
/// )
/// ```
class OverHeroineScope extends StatefulWidget {
  const OverHeroineScope({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<OverHeroineScope> createState() => _OverHeroineScopeState();

  /// Finds the nearest [OverHeroineScope] state from a [BuildContext].
  static _OverHeroineScopeState? of(BuildContext context) {
    return context.findAncestorStateOfType<_OverHeroineScopeState>();
  }
}

class _OverHeroineScopeState extends State<OverHeroineScope> {
  final Map<GlobalKey, KeepDir> _entries = {};

  void register(GlobalKey key, KeepDir keepDir) {
    _entries[key] = keepDir;
  }

  void unregister(GlobalKey key) {
    _entries.remove(key);
  }

  void updateKeepDir(GlobalKey key, KeepDir keepDir) {
    _entries[key] = keepDir;
  }

  /// Returns the bounding rectangles and [KeepDir] of all registered
  /// [OverHeroine]s, transformed to the coordinate space of [ancestor].
  ///
  /// OverHeroines with a zero or infinite size are filtered out.
  List<(Rect rect, KeepDir keepDir)> getRects(RenderObject? ancestor) {
    return _entries.entries.map((e) {
      final ctx = e.key.currentContext;
      if (ctx == null) return null;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.size.isFinite) return null;
      final rect = MatrixUtils.transformRect(
        box.getTransformTo(ancestor),
        Offset.zero & box.size,
      );
      return (rect, e.value);
    }).nonNulls.toList();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ---------------------------------------------------------------------------
// OverHeroine
// ---------------------------------------------------------------------------

/// A widget that marks a region as an occlusion boundary for heroine flights.
///
/// Wrap any widget that partially occludes a [Heroine] (e.g. an AppBar, a
/// bottom navigation bar, a floating panel) in [OverHeroine] and set
/// [keepDir] to the direction where the visible part of the occluded widget
/// lies.
///
/// Multiple [OverHeroine]s are applied one after another, each further
/// reducing the visible area.
class OverHeroine extends StatefulWidget {
  const OverHeroine({
    required this.child,
    required this.keepDir,
    super.key,
  });

  /// The widget that acts as the occlusion boundary.
  final Widget child;

  /// The direction from the [OverHeroine] towards the content that should
  /// remain visible.
  ///
  /// For an AppBar at the top, use [KeepDir.bottom] — the content below the
  /// AppBar stays visible.
  final KeepDir keepDir;

  @override
  State<OverHeroine> createState() => _OverHeroineState();
}

class _OverHeroineState extends State<OverHeroine> {
  final _key = GlobalKey();
  _OverHeroineScopeState? _scope;

  @override
  void initState() {
    super.initState();
    _scope = OverHeroineScope.of(context);
    _scope?.register(_key, widget.keepDir);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newScope = OverHeroineScope.of(context);
    if (newScope != _scope) {
      _scope?.unregister(_key);
      _scope = newScope;
      _scope?.register(_key, widget.keepDir);
    }
  }

  @override
  void didUpdateWidget(OverHeroine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keepDir != widget.keepDir) {
      (_scope ?? OverHeroineScope.of(context))?.updateKeepDir(
        _key,
        widget.keepDir,
      );
    }
  }

  @override
  void dispose() {
    _scope?.unregister(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(key: _key, child: widget.child);
  }
}
