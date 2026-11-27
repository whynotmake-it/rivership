import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';

/// A full-width row of demo actions that scrolls sideways when it runs out
/// of room.
///
/// The row spans its parent so its background and dividers never stop
/// short, the scroll view carries the side [padding] so the first and last
/// chip rest on the gutter instead of the clip edge, and the ends fade where
/// more chips are scrolled out of view.
class TurnsActionStrip extends StatelessWidget {
  const TurnsActionStrip({
    required this.children,
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.spacing = 6,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double spacing;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: CoilScrollEdgeFade(
      axis: Axis.horizontal,
      extent: 24,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        primary: false,
        padding: padding,
        child: Row(spacing: spacing, children: children),
      ),
    ),
  );
}
