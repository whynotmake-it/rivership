import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Tracks which indexed items are on screen in a scroll view, measured
/// after every frame while [attach]ed.
class VisibleItems extends ValueNotifier<(int, int)?> {
  VisibleItems() : super(null);

  final _boxes = <int, RenderBox>{};
  GlobalKey? _viewport;
  var _attached = false;

  /// Starts measuring against the box behind [viewport].
  void attach(GlobalKey viewport) {
    _viewport = viewport;
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  @override
  void dispose() {
    _attached = false;
    super.dispose();
  }

  void _measure(Duration _) {
    if (!_attached) return;
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    final viewport = _viewport?.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    int? first;
    int? last;
    for (final MapEntry(key: index, value: box) in _boxes.entries) {
      if (!box.attached || !box.hasSize) continue;
      final top = viewport.globalToLocal(box.localToGlobal(Offset.zero)).dy;
      if (top + box.size.height <= 0 || top >= viewport.size.height) continue;
      first = first == null ? index : math.min(first, index);
      last = last == null ? index : math.max(last, index);
    }
    final next = first == null ? null : (first, last!);
    if (next != value) value = next;
  }

  /// Wraps the item at [index] so it reports its box while laid out.
  Widget wrap(int index, Widget child) =>
      _Reporter(index: index, items: this, child: child);
}

class _Reporter extends SingleChildRenderObjectWidget {
  const _Reporter({
    required this.index,
    required this.items,
    required super.child,
  });

  final int index;
  final VisibleItems items;

  @override
  _RenderReporter createRenderObject(BuildContext context) =>
      _RenderReporter(index, items);

  @override
  void updateRenderObject(BuildContext context, _RenderReporter renderObject) {
    renderObject.update(index, items);
  }
}

class _RenderReporter extends RenderProxyBox {
  _RenderReporter(this._index, this._items);

  int _index;
  VisibleItems _items;

  void update(int index, VisibleItems items) {
    if (index == _index && identical(items, _items)) return;
    _unregister();
    _index = index;
    _items = items;
    if (attached) _items._boxes[_index] = this;
  }

  void _unregister() {
    if (identical(_items._boxes[_index], this)) _items._boxes.remove(_index);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _items._boxes[_index] = this;
  }

  @override
  void detach() {
    _unregister();
    super.detach();
  }
}
