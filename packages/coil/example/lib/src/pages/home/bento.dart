import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/shell/navigation.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// One tile of the home page's grid: a live composition of [links]'
/// components, with a link to each one's page underneath.
@immutable
class BentoTileData {
  const BentoTileData({
    required this.title,
    required this.links,
    required this.builder,
    this.span = 1,
  });

  /// What the tile shows, for screen readers and tests.
  final String title;

  /// The pages of the components the tile is built from.
  final List<CatalogEntry> links;

  final WidgetBuilder builder;

  /// How many columns the tile takes where there are that many.
  final int span;
}

/// The home page's grid: 3 columns on a wide pane, 2 on a medium one, 1 on
/// a phone. Tiles fill rows in order, a wide tile taking 2 columns, and
/// every tile in a row is as tall as the tallest, so rows line up without
/// fixed heights (text can grow to 2×).
class BentoGrid extends StatelessWidget {
  const BentoGrid({required this.tiles, super.key});

  final List<BentoTileData> tiles;

  /// The columns for a pane [width] wide.
  static int columnsFor(double width) => width >= 960
      ? 3
      : width >= 600
      ? 2
      : 1;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = columnsFor(constraints.maxWidth);
      final gap = CoilTheme.tierOf(context) == CoilTier.touch ? 16.0 : 12.0;
      final rows = <List<BentoTileData>>[];
      var row = <BentoTileData>[];
      var used = 0;
      for (final tile in tiles) {
        final span = math.min(tile.span, columns);
        if (used + span > columns) {
          rows.add(row);
          row = [];
          used = 0;
        }
        row.add(tile);
        used += span;
      }
      if (row.isNotEmpty) rows.add(row);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: [
          for (final row in rows)
            _EqualHeightRow(
              gap: gap,
              spans: [for (final tile in row) math.min(tile.span, columns)],
              textDirection: Directionality.of(context),
              children: [for (final tile in row) BentoTile(data: tile)],
            ),
        ],
      );
    },
  );
}

/// A tile: the live composition on top, and a footer naming the
/// components in it, each a link to its page.
class BentoTile extends StatelessWidget {
  const BentoTile({required this.data, super.key});

  final BentoTileData data;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radius = BorderRadius.circular(
      CoilTheme.radiiOf(context).container + 4,
    );
    final touch = CoilTheme.tierOf(context) == CoilTier.touch;
    return Semantics(
      container: true,
      label: data.title,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.background,
          shape: RoundedSuperellipseBorder(
            borderRadius: radius,
            side: BorderSide(color: colors.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // Under a row's height, the footer stays at the bottom.
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: EdgeInsets.all(touch ? 16 : 20),
              child: Builder(builder: data.builder),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _TileLinks(links: data.links),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The footer's links: a compact ghost button per component.
class _TileLinks extends StatelessWidget {
  const _TileLinks({required this.links});

  final List<CatalogEntry> links;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 2,
    runSpacing: 2,
    children: [
      for (final entry in links)
        CoilButton(
          variant: CoilButtonVariant.ghost,
          size: CoilSize.compact,
          trailing: const CatalogIcon(Glyph.arrowUpRight),
          onPressed: () =>
              unawaited(openCatalogPage(AutoRouter.of(context), entry)),
          child: Text(entry.title),
        ),
    ],
  );
}

/// Lays [children] out side by side, [spans] columns wide each, with [gap]
/// between them, all as tall as the tallest: each child is measured at its
/// width, then laid out again at that width and the row's height.
class _EqualHeightRow extends MultiChildRenderObjectWidget {
  const _EqualHeightRow({
    required this.spans,
    required this.gap,
    required this.textDirection,
    required super.children,
  });

  final List<int> spans;
  final double gap;
  final TextDirection textDirection;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEqualHeightRow(
        spans: spans,
        gap: gap,
        textDirection: textDirection,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderEqualHeightRow renderObject,
  ) => renderObject
    ..spans = spans
    ..gap = gap
    ..textDirection = textDirection;
}

class _RowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderEqualHeightRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _RowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _RowParentData> {
  _RenderEqualHeightRow({
    required this._spans,
    required this._gap,
    required this._textDirection,
  });

  List<int> get spans => _spans;
  List<int> _spans;
  set spans(List<int> value) {
    if (listEquals(value, _spans)) return;
    _spans = value;
    markNeedsLayout();
  }

  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RowParentData) {
      child.parentData = _RowParentData();
    }
  }

  List<double> _widths(double width) {
    final total = _spans.fold(0, (a, b) => a + b);
    final unit = (width - _gap * (_spans.length - 1)) / total;
    return [for (final span in _spans) math.max(0, unit * span)];
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final widths = _widths(width);
    var height = 0.0;
    var child = firstChild;
    var i = 0;
    while (child != null) {
      child.layout(
        BoxConstraints.tightFor(width: widths[i]),
        parentUsesSize: true,
      );
      height = math.max(height, child.size.height);
      child = childAfter(child);
      i++;
    }
    var x = 0.0;
    child = firstChild;
    i = 0;
    while (child != null) {
      // A minimum, not a tight height: tight constraints would make the
      // tile a relayout boundary, and a tile whose content grows (a
      // spacing change, an expanding panel) would never ask the row to
      // measure again.
      child.layout(
        BoxConstraints(
          minWidth: widths[i],
          maxWidth: widths[i],
          minHeight: height,
        ),
        parentUsesSize: true,
      );
      (child.parentData! as _RowParentData).offset = Offset(
        _textDirection == TextDirection.ltr ? x : width - x - widths[i],
        0,
      );
      x += widths[i] + _gap;
      child = childAfter(child);
      i++;
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  double computeMinIntrinsicHeight(double width) => _tallest(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _tallest(width);

  double _tallest(double width) {
    final widths = _widths(width);
    var height = 0.0;
    var child = firstChild;
    var i = 0;
    while (child != null) {
      height = math.max(height, child.getMaxIntrinsicHeight(widths[i]));
      child = childAfter(child);
      i++;
    }
    return height;
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
