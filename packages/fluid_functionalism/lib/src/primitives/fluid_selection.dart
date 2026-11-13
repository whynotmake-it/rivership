import 'dart:async';
import 'dart:math' as math;

import 'package:fluid_functionalism/src/foundation/fluid_motion.dart';
import 'package:fluid_functionalism/src/foundation/fluid_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A contiguous run of selected items with an id that survives changes.
@immutable
class FluidSelectionRun {
  /// Creates a run from [start] to [end] (inclusive).
  const FluidSelectionRun(this.start, this.end, this.id);

  /// The first item.
  final int start;

  /// The last item.
  final int end;

  /// Stable id: a run keeps the id of the first of its items that had one
  /// last time, so a growing or shrinking run morphs instead of swapping.
  final int id;

  @override
  bool operator ==(Object other) =>
      other is FluidSelectionRun &&
      other.start == start &&
      other.end == end &&
      other.id == id;

  @override
  int get hashCode => Object.hash(start, end, id);

  @override
  String toString() => 'Run($start..$end #$id)';
}

/// Groups a selection into runs with stable ids (`assignRunIds` in
/// `use-merge-split.tsx`). After a split the upper run keeps the id and the
/// lower one gets a new id; after a merge the run keeps the upper id.
class FluidSelectionRuns {
  Map<int, int> _byItem = const {};
  int _lastId = 0;

  /// The current runs.
  List<FluidSelectionRun> get runs => _runs;
  List<FluidSelectionRun> _runs = const [];

  /// Regroups [selected], reusing ids from the previous grouping.
  List<FluidSelectionRun> update(Iterable<int> selected) {
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
    final runs = <FluidSelectionRun>[];
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
      runs.add(FluidSelectionRun(start, end, id));
    }
    _byItem = byItem;
    return _runs = runs;
  }
}

/// Two runs inside [outer] separated by exactly one item, or null.
(FluidSelectionRun up, FluidSelectionRun lo, int gap)? _bridgePair(
  FluidSelectionRun outer,
  List<FluidSelectionRun> runs,
) {
  final inside =
      runs.where((r) => r.start >= outer.start && r.end <= outer.end).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  if (inside.length != 2) return null;
  final [up, lo] = inside;
  return lo.start == up.end + 2 ? (up, lo, up.end + 1) : null;
}

enum _Phase { converge, splitIn, diverge }

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
  _Phase phase;

  /// The whole merged (or formerly merged) run, first..last item.
  final (int, int) span;
  Timer? timer;
}

/// Paints one background block per contiguous run of [selected] items and
/// animates runs merging and splitting (`use-merge-split.tsx`).
///
/// Adjacent selected items share one rounded shape whose outer corners are
/// round and whose inner edges are flush. Toggling the single item between
/// two runs **merges** them: their inner edges glide to the middle of that
/// item and meet, and only then do the corners there straighten. Clearing
/// an item inside a run **splits** it at that item's middle, and the two
/// halves glide apart while their new corners round. Everything rides the
/// theme's `moderate` spring; reduced motion makes it snap.
///
/// Place it in a [Stack] in the coordinate space of [rects] (a
/// `FluidHoverRegion`'s `backgroundBuilder` passes item rects).
class FluidSelectionBackground extends StatefulWidget {
  /// Creates a selection background.
  const FluidSelectionBackground({
    required this.selected,
    required this.rects,
    super.key,
    this.axis = Axis.vertical,
    this.color,
    this.radius,
    this.motion,
  });

  /// The selected item indices.
  final Set<int> selected;

  /// Every item's rect, by index.
  final Map<int, Rect> rects;

  /// Whether items run top to bottom or start to end.
  final Axis axis;

  /// The block color. Defaults to the theme's `active` wash.
  final Color? color;

  /// The outer corner radius. Defaults to the theme shape's item radius.
  final double? radius;

  /// Overrides the theme's motion tokens.
  final FluidMotionThemeData? motion;

  @override
  State<FluidSelectionBackground> createState() =>
      _FluidSelectionBackgroundState();
}

/// What one block should look like now.
@immutable
class _BlockSpec {
  const _BlockSpec({
    required this.rect,
    required this.corners,
    this.instant = false,
    this.cornerDelay = Duration.zero,
    this.enterFrom,
    this.visible = true,
  });

  final Rect rect;
  final _Corners corners;
  final bool instant;
  final Duration cornerDelay;
  final (Rect, _Corners)? enterFrom;
  final bool visible;
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

class _FluidSelectionBackgroundState extends State<FluidSelectionBackground> {
  final _runs = FluidSelectionRuns();
  List<FluidSelectionRun> _previous = const [];
  final _boundaries = <_Boundary>[];

  /// Runs that disappeared, kept while they fade out.
  final _leaving = <int, Rect>{};

  /// Blocks that jump (for one frame) instead of springing: a merged run
  /// at commit, whose two halves already look like the one block.
  final _jump = <int>{};

  @override
  void initState() {
    super.initState();
    _previous = _runs.update(widget.selected);
  }

  @override
  void didUpdateWidget(FluidSelectionBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (setEquals(oldWidget.selected, widget.selected)) return;
    final before = _previous;
    final after = _runs.update(widget.selected);
    _previous = after;
    _detect(before, after);
  }

  @override
  void dispose() {
    for (final b in _boundaries) {
      b.timer?.cancel();
    }
    super.dispose();
  }

  /// Merge/split detection (the layout effect in `useMergeSplitBlocks`).
  void _detect(List<FluidSelectionRun> before, List<FluidSelectionRun> after) {
    // Drop boundaries the new selection invalidated.
    _boundaries.removeWhere((b) {
      final stillValid = switch (b.phase) {
        _Phase.converge => after.any(
          (r) => r.id == b.survivor && r.start <= b.gap && r.end >= b.gap,
        ),
        _ =>
          after.any((r) => r.id == b.survivor) &&
              after.any((r) => r.id == b.other) &&
              !widget.selected.contains(b.gap),
      };
      if (!stillValid) b.timer?.cancel();
      return !stillValid;
    });

    for (final run in after) {
      final pair = _bridgePair(run, before);
      if (pair == null) continue;
      final (up, lo, gap) = pair;
      final other = up.id == run.id ? lo.id : up.id;
      if (up.id != run.id && lo.id != run.id) continue;
      _start(
        _Boundary(
          survivor: run.id,
          other: other,
          gap: gap,
          phase: _Phase.converge,
          span: (run.start, run.end),
        ),
        const Duration(milliseconds: 310),
      );
    }
    for (final run in before) {
      final pair = _bridgePair(run, after);
      if (pair == null) continue;
      final (up, lo, gap) = pair;
      _start(
        _Boundary(
          survivor: up.id,
          other: lo.id,
          gap: gap,
          phase: _Phase.splitIn,
          span: (run.start, run.end),
        ),
        const Duration(milliseconds: 240),
      );
    }

    // Plain disappearances fade out where they were.
    final afterIds = after.map((r) => r.id).toSet();
    final merging = _boundaries
        .where((b) => b.phase == _Phase.converge)
        .map((b) => b.other)
        .toSet();
    for (final run in before) {
      if (afterIds.contains(run.id) || merging.contains(run.id)) continue;
      final rect = _union(run.start, run.end);
      if (rect != null) _leaving[run.id] = rect;
    }
    for (final id in afterIds) {
      _leaving.remove(id);
    }
  }

  void _start(_Boundary boundary, Duration resolveAfter) {
    _boundaries.add(boundary);
    if (boundary.phase == _Phase.splitIn) {
      // Pinned at the seam for one frame, then the halves diverge.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_boundaries.contains(boundary)) return;
        setState(() => boundary.phase = _Phase.diverge);
      });
    }
    boundary.timer = Timer(resolveAfter, () {
      if (!mounted) return;
      setState(() {
        _boundaries.remove(boundary);
        if (boundary.phase == _Phase.converge) {
          // Commit: the survivor becomes the whole run at once and the
          // absorbed half goes; they already meet, so nothing visibly moves.
          _jump.add(boundary.survivor);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _jump.remove(boundary.survivor));
          });
        }
      });
    });
  }

  Rect? _union(int start, int end) {
    Rect? result;
    for (var i = start; i <= end; i++) {
      final r = widget.rects[i];
      if (r == null) continue;
      result = result == null ? r : result.expandToInclude(r);
    }
    return result;
  }

  bool get _vertical => widget.axis == Axis.vertical;

  /// Splits [rect] at [mid] along the axis.
  (Rect, Rect) _halves(Rect rect, double mid) => _vertical
      ? (
          Rect.fromLTRB(rect.left, rect.top, rect.right, mid),
          Rect.fromLTRB(rect.left, mid, rect.right, rect.bottom),
        )
      : (
          Rect.fromLTRB(rect.left, rect.top, mid, rect.bottom),
          Rect.fromLTRB(mid, rect.top, rect.right, rect.bottom),
        );

  /// Corners with the inner side (toward the seam) square.
  (_Corners, _Corners) _innerSquare(double r) => _vertical
      ? (_Corners(r, r, 0, 0), _Corners(0, 0, r, r))
      : (_Corners(r, 0, 0, r), _Corners(0, r, r, 0));

  Map<int, _BlockSpec> _blocks(double r) {
    final blocks = <int, _BlockSpec>{};
    for (final run in _runs.runs) {
      final rect = _union(run.start, run.end);
      if (rect != null) {
        blocks[run.id] = _BlockSpec(
          rect: rect,
          corners: _Corners.all(r),
          instant: _jump.contains(run.id),
        );
      }
    }
    for (final b in _boundaries) {
      final gapRect = widget.rects[b.gap];
      final whole = _union(b.span.$1, b.span.$2);
      if (gapRect == null || whole == null) continue;
      final mid = _vertical ? gapRect.center.dy : gapRect.center.dx;
      final (first, second) = _halves(whole, mid);
      final (firstCorners, secondCorners) = _innerSquare(r);
      final along = _vertical ? gapRect.height : gapRect.width;
      final delay = Duration(
        microseconds:
            (math.min(0.10, math.max(0.07, 0.07 + (mid / along) * 0.002)) * 1e6)
                .round(),
      );
      switch (b.phase) {
        case _Phase.converge:
          // The two old blocks' inner edges glide to the seam; the corners
          // there straighten only once the edges are about to meet.
          blocks[b.survivor] = _BlockSpec(
            rect: first,
            corners: firstCorners,
            cornerDelay: delay,
          );
          blocks[b.other] = _BlockSpec(
            rect: second,
            corners: secondCorners,
            cornerDelay: delay,
          );
        case _Phase.splitIn:
          // Pinned at the seam: identical to the single block it was.
          blocks[b.survivor] = _BlockSpec(
            rect: first,
            corners: firstCorners,
            instant: true,
          );
          blocks[b.other] = _BlockSpec(
            rect: second,
            corners: secondCorners,
            instant: true,
            enterFrom: (second, secondCorners),
          );
        case _Phase.diverge:
          break; // The plain run blocks: both spring to their real rects.
      }
    }
    for (final MapEntry(key: id, value: rect) in _leaving.entries) {
      blocks.putIfAbsent(
        id,
        () => _BlockSpec(rect: rect, corners: _Corners.all(r), visible: false),
      );
    }
    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluidTheme.of(context);
    final motion = FluidTheme.motionOf(context, override: widget.motion);
    final r = widget.radius ?? theme.shape.item;
    final color = widget.color ?? theme.colors.active;
    final blocks = _blocks(r);
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final MapEntry(key: id, value: spec) in blocks.entries)
            _Block(
              key: ValueKey(id),
              spec: spec,
              color: color,
              motion: motion,
              onGone: () => setState(() => _leaving.remove(id)),
            ),
        ],
      ),
    );
  }
}

/// One animated block: rect, corner radii and opacity tracks on one
/// controller.
class _Block extends StatefulWidget {
  const _Block({
    required this.spec,
    required this.color,
    required this.motion,
    required this.onGone,
    super.key,
  });

  final _BlockSpec spec;
  final Color color;
  final FluidMotionThemeData motion;
  final VoidCallback onGone;

  @override
  State<_Block> createState() => _BlockState();
}

class _BlockState extends State<_Block> with SingleTickerProviderStateMixin {
  late final _controller = TrackController(
    vsync: this,
    debugLabel: 'FluidSelectionBlock',
  );
  late final _rect = Track<Rect>(
    .rect,
    initial: widget.spec.enterFrom?.$1 ?? widget.spec.rect,
    debugLabel: 'Rect',
  );
  late final _corners = Track<_Corners>(
    _Corners.converter,
    initial: widget.spec.enterFrom?.$2 ?? widget.spec.corners,
    debugLabel: 'Corners',
  );
  late final _opacity = Track<double>(
    .single,
    // A brand-new run fades in where it is; a split half appears at once.
    initial: widget.spec.enterFrom != null ? 1 : 0,
    debugLabel: 'Opacity',
  );

  @override
  void initState() {
    super.initState();
    _apply(null);
  }

  @override
  void didUpdateWidget(_Block oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec.rect != widget.spec.rect ||
        oldWidget.spec.corners != widget.spec.corners ||
        oldWidget.spec.visible != widget.spec.visible ||
        oldWidget.spec.instant != widget.spec.instant) {
      _apply(oldWidget.spec);
    }
  }

  void _apply(_BlockSpec? old) {
    final spec = widget.spec;
    final m = widget.motion;
    final travel = spec.instant ? const Motion.instant() : m.moderate;
    _controller
        .animate([
          _rect([.to(spec.rect, motion: travel)]),
          _corners(
            [.to(spec.corners, motion: travel)],
            delay: spec.instant ? Duration.zero : spec.cornerDelay,
          ),
          _opacity([
            .to(
              spec.visible ? 1 : 0,
              motion: spec.visible ? m.fade : m.moderateExit,
            ),
          ]),
        ])
        .then((_) {
          if (mounted && !widget.spec.visible) widget.onGone();
        }, onError: (_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final opacity = _controller.value(_opacity).clamp(0.0, 1.0);
        return Positioned.fromRect(
          rect: _controller.value(_rect),
          child: Opacity(
            opacity: opacity,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: widget.color,
                shape: RoundedSuperellipseBorder(
                  borderRadius: _controller.value(_corners).borderRadius,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
