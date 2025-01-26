part of 'heroines.dart';

/// An anchor for a [Heroine] transition that can be used to retarget [Heroine]
/// animations.
///
/// This must always be a descendant of a [Heroine] widget, and there can only
/// be one [HeroineAnchor] per [Heroine] widget.
class HeroineAnchor extends StatefulWidget {
  /// Creates a new [HeroineAnchor].
  const HeroineAnchor({
    required this.child,
    super.key,
  });

  /// The widget subtree that will be used as an anchor for the [Heroine]
  final Widget child;

  @override
  State<HeroineAnchor> createState() => _HeroineAnchorState();
}

class _HeroineAnchorState extends State<HeroineAnchor> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
