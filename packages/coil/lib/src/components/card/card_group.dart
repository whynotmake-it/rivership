import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/card/card.dart';
import 'package:coil/src/components/card/card_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// How a [CoilCardGroup] separates its cards.
enum CoilCardGroupLayout {
  /// One block with hairlines between the cards.
  divided,

  /// Separate cards with a gap between them.
  separated,
}

/// Lays out [CoilCard]s as one divided block or as separate cards, in
/// [columns], with one hover highlight gliding between the cards that have
/// an action.
class CoilCardGroup extends StatefulWidget {
  /// Creates a card group.
  const CoilCardGroup({
    required this.children,
    super.key,
    this.layout = CoilCardGroupLayout.divided,
    this.columns = 1,
    this.size,
    this.motion,
    this.motions,
    this.style,
  }) : assert(columns > 0, 'A group needs at least one column');

  /// The cards, in reading order.
  final List<Widget> children;

  /// Divided into one block, or separated.
  final CoilCardGroupLayout layout;

  /// How many cards per row.
  final int columns;

  /// Pins the group to one size step.
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions for the group, keyed by [CoilCardTrack]s. Only
  /// [CoilCardTrack.highlight] applies to the group; the cards take their
  /// own.
  final Map<CoilCardTrack<Object>, Motion>? motions;

  /// Overrides for the group's look, on top of the theme's [CoilCardStyle]
  /// and the defaults.
  final CoilCardStyle? style;

  @override
  State<CoilCardGroup> createState() => _CoilCardGroupState();
}

class _CoilCardGroupState extends State<CoilCardGroup> {
  final _surfaces = _SurfacePainter();

  @override
  void dispose() {
    _surfaces.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final style = CoilCardStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilCardStyle>(context)).merge(widget.style);
    final separated = widget.layout == CoilCardGroupLayout.separated;
    final columns = widget.columns;
    final count = widget.children.length;
    final rowCount = (count / columns).ceil();
    final gap = separated ? style.spacing! : 0.0;
    final radius = BorderRadius.circular(style.radius!);
    final surface = ShapeDecoration(
      color: style.surface,
      shadows: style.shadows,
      shape: RoundedSuperellipseBorder(
        borderRadius: radius,
        side: style.border!,
      ),
    );
    _surfaces.update(
      separated ? surface : null,
      count,
      Directionality.of(context),
    );

    Widget cell(int index) {
      final row = index ~/ columns;
      final column = index % columns;
      final card = CardSlot(index: index, child: widget.children[index]);
      if (separated) return card;
      return _Divider(
        index: index,
        below: row < rowCount - 1 && index + columns < count
            ? index + columns
            : null,
        after: column < columns - 1 && index + 1 < count ? index + 1 : null,
        color: style.divider!,
        child: card,
      );
    }

    Widget grid = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        for (var row = 0; row < rowCount; row++)
          if (columns == 1)
            cell(row)
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: gap,
                children: [
                  for (var column = 0; column < columns; column++)
                    Expanded(
                      child: row * columns + column < count
                          ? cell(row * columns + column)
                          : const SizedBox(),
                    ),
                ],
              ),
            ),
      ],
    );

    grid = CoilHoverRegion(
      axis: CoilHoverAxis.xy,
      child: CoilHoverHighlight(
        color: style.highlight,
        radius: style.radius,
        motion: widget.motion,
        glideMotion: CoilTheme.trackMotionOf(
          context,
          CoilCardTrack.highlight,
          instance: widget.motions,
          token: CoilTheme.motionOf(context, override: widget.motion).quick,
        ),
        background: [_surfaces],
        child: grid,
      ),
    );

    if (!separated) {
      grid = DecoratedBox(
        decoration: surface,
        child: ClipRSuperellipse(borderRadius: radius, child: grid),
      );
    }
    return CoilAdaptiveScope(size: widget.size, child: grid);
  }
}

/// The hairlines below and after one card of a divided group. They hide
/// next to the lit card, so the highlight reads as one shape.
class _Divider extends StatelessWidget {
  const _Divider({
    required this.index,
    required this.below,
    required this.after,
    required this.color,
    required this.child,
  });

  final int index;
  final int? below;
  final int? after;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lit = CoilHoverRegion.maybeOf(context)?.activeIndex;
    BorderSide side(int? neighbor) =>
        neighbor == null || lit == index || lit == neighbor
        ? BorderSide.none
        : BorderSide(color: color);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(bottom: side(below), end: side(after)),
      ),
      child: child,
    );
  }
}

/// Paints the surface of every card of a separated group under the group's
/// highlight, so the highlight shows on the card it lights.
class _SurfacePainter extends CoilLayerPainter {
  Decoration? _decoration;
  BoxPainter? _painter;
  int _count = 0;
  TextDirection _direction = TextDirection.ltr;

  void update(Decoration? decoration, int count, TextDirection direction) {
    if (decoration == _decoration &&
        count == _count &&
        direction == _direction) {
      return;
    }
    if (decoration != _decoration) {
      _painter?.dispose();
      _painter = null;
      _decoration = decoration;
    }
    _count = count;
    _direction = direction;
    notifyListeners();
  }

  @override
  void paint(Canvas canvas, Offset offset, CoilLayerGeometry geometry) {
    final decoration = _decoration;
    if (decoration == null) return;
    final painter = _painter ??= decoration.createBoxPainter(notifyListeners);
    for (var i = 0; i < _count; i++) {
      final rect = geometry.rectOf(i);
      if (rect == null || rect.isEmpty) continue;
      painter.paint(
        canvas,
        rect.topLeft + offset,
        ImageConfiguration(size: rect.size, textDirection: _direction),
      );
    }
  }

  @override
  void dispose() {
    _painter?.dispose();
    super.dispose();
  }
}
