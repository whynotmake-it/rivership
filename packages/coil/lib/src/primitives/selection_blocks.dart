import 'dart:math' as math;

import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/primitives/motion_layer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A contiguous run of selected items with an id that survives changes.
@immutable
class CoilSelectionRun {
  /// Creates a run from [start] to [end] (inclusive).
  const CoilSelectionRun(this.start, this.end, this.id);

  /// The first item.
  final int start;

  /// The last item.
  final int end;

  /// Stable id: a run keeps the id of the first of its items that had one
  /// last time, so a growing or shrinking run morphs instead of swapping.
  final int id;

  @override
  bool operator ==(Object other) =>
      other is CoilSelectionRun &&
      other.start == start &&
      other.end == end &&
      other.id == id;

  @override
  int get hashCode => Object.hash(start, end, id);

  @override
  String toString() => 'Run($start..$end #$id)';
}

/// Groups a selection into runs with stable ids.
/// After a split the upper run keeps the id and the
/// lower one gets a new id; after a merge the run keeps the upper id.
class CoilSelectionRuns {
  Map<int, int> _byItem = const {};
  int _lastId = 0;

  /// The current runs.
  List<CoilSelectionRun> get runs => _runs;
  List<CoilSelectionRun> _runs = const [];

  /// Regroups [selected], reusing ids from the previous grouping.
  List<CoilSelectionRun> update(Iterable<int> selected) {
    final sorted = selected.toSet().toList()..sort();
    final spans = <(int, int)>[];
    for (final i in sorted) {
      if (spans.isNotEmpty && spans.last.$2 == i - 1) {
        spans.last = (spans.last.$1, i);
      } else {
        spans.add((i, i));
      }
    }
    final used = <int>{};
    final byItem = <int, int>{};
    final runs = <CoilSelectionRun>[];
    for (final (start, end) in spans) {
      int? id;
      for (var i = start; i <= end; i++) {
        final previous = _byItem[i];
        if (previous != null && !used.contains(previous)) {
          id = previous;
          break;
        }
      }
      id ??= ++_lastId;
      used.add(id);
      for (var i = start; i <= end; i++) {
        byItem[i] = id;
      }
      runs.add(CoilSelectionRun(start, end, id));
    }
    _byItem = byItem;
    return _runs = runs;
  }
}

/// Two runs inside [outer] separated by exactly one item, or null.
(CoilSelectionRun up, CoilSelectionRun lo, int gap)? _bridgePair(
  CoilSelectionRun outer,
  List<CoilSelectionRun> runs,
) {
  final inside =
      runs.where((r) => r.start >= outer.start && r.end <= outer.end).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  if (inside.length != 2) return null;
  final [up, lo] = inside;
  return lo.start == up.end + 2 ? (up, lo, up.end + 1) : null;
}

enum _Phase { converge, split }

class _Boundary {
  _Boundary({
    required this.survivor,
    required this.other,
    required this.gap,
    required this.phase,
    required this.span,
  });

  final int survivor;
  final int other;
  final int gap;
  final _Phase phase;

  /// The whole merged (or formerly merged) run, first..last item.
  final (int, int) span;

  /// Whether a merge's commit is scheduled.
  bool committing = false;

  /// Whether a split's halves have been pinned at the seam already.
  bool pinned = false;
}

/// Where a block is, in terms of items: resolved to a rect at paint time.
@immutable
sealed class _Geometry {
  const _Geometry();
}

/// The union of items [start]..[end].
class _RunGeometry extends _Geometry {
  const _RunGeometry(this.start, this.end);
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is _RunGeometry && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// The [first] or second half of items [start]..[end], split at the middle
/// of item [gap].
class _HalfGeometry extends _Geometry {
  const _HalfGeometry(this.start, this.end, this.gap, {required this.first});
  final int start;
  final int end;
  final int gap;
  final bool first;

  @override
  bool operator ==(Object other) =>
      other is _HalfGeometry &&
      other.start == start &&
      other.end == end &&
      other.gap == gap &&
      other.first == first;

  @override
  int get hashCode => Object.hash(start, end, gap, first);
}

/// Wherever the block was last painted (a run that is fading out).
class _FrozenGeometry extends _Geometry {
  const _FrozenGeometry();
}

/// What one block should look like now.
@immutable
class _BlockSpec {
  const _BlockSpec({
    required this.geometry,
    required this.corners,
    this.from,
    this.fromCorners,
    this.instant = false,
    this.visible = true,
  });

  final _Geometry geometry;
  final _Corners corners;

  /// Where the block starts this change (a split half pinned at the seam).
  final _Geometry? from;
  final _Corners? fromCorners;
  final bool instant;

  final bool visible;
}

/// Paints one block behind each run of adjacent selected items, and
/// animates runs merging and splitting. A painter for a `CoilMotionLayer`
/// whose targets are the items.
///
/// Adjacent selected items share one shape: outer corners round, inner
/// edges flush. Selecting the single item between two runs **merges**
/// them: their inner edges glide to that item's middle, then the corners
/// there straighten. Clearing an item inside a run **splits** it there:
/// the halves glide apart while their new corners round. Everything rides
/// the `standard` spring, so it follows runtime motion changes and snaps
/// under reduced motion.
///
/// Blocks are resolved to item rects while painting, so they stay on items
/// that resize or reflow.
class CoilSelectionPainter extends CoilLayerPainter {
  /// Creates a selection painter ticking on [_vsync].
  CoilSelectionPainter({required this._vsync});

  final TickerProvider _vsync;
  final _runs = CoilSelectionRuns();
  List<CoilSelectionRun> _previous = const [];
  final _boundaries = <_Boundary>[];
  final _blocks = <int, _BlockAnimation>{};
  Set<int>? _selected;
  Axis _axis = Axis.vertical;
  double _radius = 8;
  Color _color = const Color(0x12000000);
  CoilMotion _motion = const CoilMotion();

  /// Sets the selection and style. Call on every build; an unchanged
  /// selection only restyles.
  void update({
    required Set<int> selected,
    required Color color,
    required double radius,
    required CoilMotion motion,
    Axis axis = Axis.vertical,
  }) {
    _axis = axis;
    _color = color;
    _radius = radius;
    _motion = motion;
    final previousSelection = _selected;
    _selected = {...selected};
    if (previousSelection == null) {
      _previous = _runs.update(selected);
      _apply(initial: true);
    } else if (!setEquals(previousSelection, selected)) {
      final before = _previous;
      final after = _runs.update(selected);
      _previous = after;
      _detect(before, after);
      _apply();
    }
    notifyListeners();
  }

  /// Finds runs that merged or split since the last selection.
  void _detect(List<CoilSelectionRun> before, List<CoilSelectionRun> after) {
    final selected = _selected!;
    // Drop boundaries the new selection invalidated.
    _boundaries.removeWhere((b) {
      final stillValid = switch (b.phase) {
        _Phase.converge => after.any(
          (r) => r.id == b.survivor && r.start <= b.gap && r.end >= b.gap,
        ),
        _Phase.split =>
          after.any((r) => r.id == b.survivor) &&
              after.any((r) => r.id == b.other) &&
              !selected.contains(b.gap),
      };
      return !stillValid;
    });

    for (final run in after) {
      final pair = _bridgePair(run, before);
      if (pair == null) continue;
      final (up, lo, gap) = pair;
      if (up.id != run.id && lo.id != run.id) continue;
      _boundaries.add(
        _Boundary(
          survivor: run.id,
          other: up.id == run.id ? lo.id : up.id,
          gap: gap,
          phase: _Phase.converge,
          span: (run.start, run.end),
        ),
      );
    }
    for (final run in before) {
      final pair = _bridgePair(run, after);
      if (pair == null) continue;
      final (up, lo, gap) = pair;
      _boundaries.add(
        _Boundary(
          survivor: up.id,
          other: lo.id,
          gap: gap,
          phase: _Phase.split,
          span: (run.start, run.end),
        ),
      );
    }
  }

  /// Commits a merge once its halves meet: the survivor becomes the whole
  /// run at once and the absorbed half goes. They already touch, so nothing
  /// visibly moves. Called at the end of paint.
  void _commit(_Boundary boundary) {
    if (!_boundaries.remove(boundary)) return;
    _apply(instant: {boundary.survivor}, drop: {boundary.other});
  }

  /// Advances merges while painting: once both halves have glided to the
  /// seam and their inner corners have squared off (together, on the same
  /// spring), the merge commits. It rides the motion tokens, so a slower
  /// `standard` spring is never cut short and reduced motion commits at
  /// once.
  void _advanceMerges() {
    for (final b in [..._boundaries]) {
      if (b.phase != _Phase.converge || b.committing) continue;
      final survivor = _blocks[b.survivor];
      final other = _blocks[b.other];
      if (survivor == null || other == null) continue;
      if (!survivor.glided || !other.glided) continue;
      if (survivor.cornersArrived && other.cornersArrived) {
        b.committing = true;
        // The halves already meet, so this frame looks the same; the merged
        // block paints from the next one.
        _commit(b);
      }
    }
  }

  /// The corners with the inner side (toward the seam) square.
  (_Corners, _Corners) _innerSquare(double r) => _axis == Axis.vertical
      ? (_Corners(r, r, 0, 0), _Corners(0, 0, r, r))
      : (_Corners(r, 0, 0, r), _Corners(0, r, r, 0));

  Map<int, _BlockSpec> _specs({Set<int> instant = const {}}) {
    final r = _radius;
    final specs = <int, _BlockSpec>{
      for (final run in _runs.runs)
        run.id: _BlockSpec(
          geometry: _RunGeometry(run.start, run.end),
          corners: _Corners.all(r),
          instant: instant.contains(run.id),
        ),
    };
    for (final b in _boundaries) {
      final (start, end) = b.span;
      final first = _HalfGeometry(start, end, b.gap, first: true);
      final second = _HalfGeometry(start, end, b.gap, first: false);
      final (firstCorners, secondCorners) = _innerSquare(r);
      switch (b.phase) {
        case _Phase.converge:
          // The two old blocks' inner edges glide to the seam while the
          // corners there square off.
          specs[b.survivor] = _BlockSpec(
            geometry: first,
            corners: firstCorners,
          );
          specs[b.other] = _BlockSpec(
            geometry: second,
            corners: secondCorners,
          );
        case _Phase.split:
          // Both halves start pinned at the seam, exactly the block they
          // were, then glide to their runs while the new corners round.
          if (b.pinned) break;
          b.pinned = true;
          specs[b.survivor] = specs[b.survivor]!.withFrom(first, firstCorners);
          specs[b.other] = specs[b.other]!.withFrom(second, secondCorners);
      }
    }
    return specs;
  }

  void _apply({
    bool initial = false,
    Set<int> instant = const {},
    Set<int> drop = const {},
  }) {
    final specs = _specs(instant: instant);
    // A split's halves are pinned at the seam once; from then on they are
    // ordinary runs gliding apart.
    _boundaries.removeWhere((b) => b.phase == _Phase.split && b.pinned);
    final m = _motion;
    for (final MapEntry(key: id, value: spec) in specs.entries) {
      (_blocks[id] ??= _BlockAnimation(
        vsync: _vsync,
        corners: spec.fromCorners ?? spec.corners,
        // New runs fade in where they are; split halves appear at once.
        opacity: initial || spec.from != null ? 1 : 0,
        onTick: notifyListeners,
      )).setSpec(spec, m);
    }
    // Runs that disappeared: an absorbed merge half goes at once, anything
    // else fades out where it was.
    for (final id in _blocks.keys.toList()) {
      if (specs.containsKey(id)) continue;
      final block = _blocks[id]!;
      if (drop.contains(id) || !block.spec.visible && block.gone) {
        _blocks.remove(id)!.dispose();
        continue;
      }
      if (block.spec.visible) {
        block.setSpec(
          _BlockSpec(
            geometry: const _FrozenGeometry(),
            corners: block.spec.corners,
            visible: false,
          ),
          m,
          onGone: () {
            if (_blocks[id] == block && !specs.containsKey(id)) {
              _blocks.remove(id)!.dispose();
              notifyListeners();
            }
          },
        );
      }
    }
  }

  Rect? _resolve(_Geometry geometry, CoilLayerGeometry items, Rect? last) {
    Rect? union(int start, int end) {
      Rect? result;
      for (var i = start; i <= end; i++) {
        final r = items.rectOf(i);
        if (r == null) continue;
        result = result == null ? r : result.expandToInclude(r);
      }
      return result;
    }

    switch (geometry) {
      case _RunGeometry(:final start, :final end):
        return union(start, end);
      case _HalfGeometry(:final start, :final end, :final gap, :final first):
        final whole = union(start, end);
        final gapRect = items.rectOf(gap);
        if (whole == null || gapRect == null) return null;
        if (_axis == Axis.vertical) {
          final mid = gapRect.center.dy;
          return first
              ? Rect.fromLTRB(whole.left, whole.top, whole.right, mid)
              : Rect.fromLTRB(whole.left, mid, whole.right, whole.bottom);
        }
        final mid = gapRect.center.dx;
        return first
            ? Rect.fromLTRB(whole.left, whole.top, mid, whole.bottom)
            : Rect.fromLTRB(mid, whole.top, whole.right, whole.bottom);
      case _FrozenGeometry():
        return last;
    }
  }

  @override
  void paint(Canvas canvas, Offset offset, CoilLayerGeometry geometry) {
    for (final block in _blocks.values) {
      final target = _resolve(block.spec.geometry, geometry, block.lastPainted);
      if (target == null) continue;
      final from = block.pendingFrom;
      final rect = block.resolve(
        target,
        from == null ? null : _resolve(from, geometry, null),
        _motion,
      );
      final opacity = block.opacity;
      if (opacity <= 0) continue;
      if (opacity < 1) {
        canvas.saveLayer(
          null,
          Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
        );
      }
      final shifted = rect.shift(offset);
      ShapeDecoration(
            color: _color,
            shape: RoundedSuperellipseBorder(
              borderRadius: block.corners.borderRadius,
            ),
          )
          .createBoxPainter(_noop)
          .paint(
            canvas,
            shifted.topLeft,
            ImageConfiguration(size: shifted.size),
          );
      if (opacity < 1) canvas.restore();
    }
    _advanceMerges();
  }

  @override
  void dispose() {
    for (final block in _blocks.values) {
      block.dispose();
    }
    super.dispose();
  }
}

extension on _BlockSpec {
  _BlockSpec withFrom(_Geometry from, _Corners fromCorners) => _BlockSpec(
    geometry: geometry,
    corners: corners,
    from: from,
    fromCorners: fromCorners,
  );
}

/// One block's motion: a rect delta relative to its geometry, its corner
/// radii and its opacity, as tracks on one controller.
class _BlockAnimation {
  _BlockAnimation({
    required TickerProvider vsync,
    required _Corners corners,
    required double opacity,
    required VoidCallback onTick,
  }) : _controller = TrackController(
         vsync: vsync,
         debugLabel: 'CoilSelectionBlock',
       ) {
    _cornersTrack = Track<_Corners>(
      _Corners.converter,
      initial: corners,
      debugLabel: 'Corners',
    );
    _opacityTrack = Track<double>(
      .single,
      initial: opacity,
      debugLabel: 'Opacity',
    );
    _controller.addListener(onTick);
  }

  final TrackController _controller;
  final _delta = Track<Rect>(.rect, initial: Rect.zero, debugLabel: 'Delta');
  late final Track<_Corners> _cornersTrack;
  late final Track<double> _opacityTrack;

  _BlockSpec spec = const _BlockSpec(
    geometry: _FrozenGeometry(),
    corners: _Corners.all(0),
  );
  bool _hasSpec = false;
  bool _retarget = false;
  bool _instant = false;
  _Geometry? pendingFrom;
  Rect? lastPainted;
  bool gone = false;

  _Corners get corners => _controller.value(_cornersTrack);
  double get opacity => _controller.value(_opacityTrack).clamp(0.0, 1.0);

  void setSpec(
    _BlockSpec next,
    CoilMotion m, {
    VoidCallback? onGone,
  }) {
    final first = !_hasSpec;
    _hasSpec = true;
    final moved = first || next.geometry != spec.geometry || next.from != null;
    spec = next;
    if (moved && !first) {
      _retarget = true;
      _instant = next.instant;
    }
    pendingFrom = next.from;
    if (first && next.from == null) _retarget = false;
    final travel = next.instant ? const Motion.instant() : m.standard;
    _controller
        .animate([
          // The corners change with the glide, on the same spring, so a
          // merge's seam squares off as the blocks meet, not after.
          _cornersTrack([
            .to(next.corners, motion: travel),
          ], from: next.fromCorners),
          _opacityTrack([
            .to(
              next.visible ? 1 : 0,
              motion: next.visible ? m.fade : m.standardExit,
            ),
          ]),
        ])
        .then(
          (_) {
            if (!next.visible) {
              gone = true;
              onGone?.call();
            }
          },
          onError: (Object _) {},
        );
  }

  /// Whether the block's glide toward its geometry is done.
  bool get glided =>
      !_retarget &&
      pendingFrom == null &&
      _controller.value(_delta) == Rect.zero;

  /// Whether the corners reached the spec's corners.
  bool get cornersArrived => corners == spec.corners;

  /// The rect to paint this frame for [target], starting any glide the
  /// last [setSpec] asked for. Called while painting.
  Rect resolve(Rect target, Rect? from, CoilMotion m) {
    Rect diff(Rect a, Rect b) => Rect.fromLTRB(
      a.left - b.left,
      a.top - b.top,
      a.right - b.right,
      a.bottom - b.bottom,
    );
    if (from != null || _retarget) {
      final start = from ?? lastPainted;
      final delta = start == null ? Rect.zero : diff(start, target);
      if (_instant || delta == Rect.zero) {
        _controller.set([_delta.value(Rect.zero)]);
      } else {
        _controller.animate([
          _delta([.to(Rect.zero, motion: m.standard)], from: delta),
        ]);
      }
      _retarget = false;
      _instant = false;
      pendingFrom = null;
    }
    final d = _controller.value(_delta);
    final rect = Rect.fromLTRB(
      target.left + d.left,
      target.top + d.top,
      target.right + d.right,
      target.bottom + d.bottom,
    );
    lastPainted = rect;
    return rect;
  }

  void dispose() => _controller.dispose();
}

/// Four corner radii: top-left, top-right, bottom-right, bottom-left.
@immutable
class _Corners {
  const _Corners(this.tl, this.tr, this.br, this.bl);
  const _Corners.all(double r) : this(r, r, r, r);

  final double tl;
  final double tr;
  final double br;
  final double bl;

  static const converter = MotionConverter<_Corners>.custom(
    normalize: _normalize,
    denormalize: _denormalize,
  );

  static List<double> _normalize(_Corners c) => [c.tl, c.tr, c.br, c.bl];
  // A converter callback, not a constructor substitute.
  // ignore: prefer_constructors_over_static_methods
  static _Corners _denormalize(List<double> v) => _Corners(
    math.max(0, v[0]),
    math.max(0, v[1]),
    math.max(0, v[2]),
    math.max(0, v[3]),
  );

  BorderRadius get borderRadius => BorderRadius.only(
    topLeft: Radius.circular(tl),
    topRight: Radius.circular(tr),
    bottomRight: Radius.circular(br),
    bottomLeft: Radius.circular(bl),
  );

  @override
  bool operator ==(Object other) =>
      other is _Corners &&
      other.tl == tl &&
      other.tr == tr &&
      other.br == br &&
      other.bl == bl;

  @override
  int get hashCode => Object.hash(tl, tr, br, bl);
}

void _noop() {}
