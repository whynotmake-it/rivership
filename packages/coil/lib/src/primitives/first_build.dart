import 'package:flutter/widgets.dart';

/// Builds [builder] with `first` true on its first build and false after.
///
/// Put it directly above a `TrackBuilder` whose tracks have no initial
/// value, so they can start at their resting value (`from:` on the first
/// build) instead of animating in from nothing. The flag lives as long as the
/// subtree under it, so a `TrackBuilder` that is rebuilt from scratch, for
/// instance when the tier changes the layout above it, starts at rest again.
class CoilFirstBuild extends StatefulWidget {
  /// Creates a first-build builder.
  const CoilFirstBuild({required this.builder, super.key});

  /// Builds the subtree.
  final Widget Function(BuildContext context, {required bool first}) builder;

  @override
  State<CoilFirstBuild> createState() => _CoilFirstBuildState();
}

class _CoilFirstBuildState extends State<CoilFirstBuild> {
  bool _built = false;

  @override
  Widget build(BuildContext context) {
    final first = !_built;
    _built = true;
    return widget.builder(context, first: first);
  }
}
