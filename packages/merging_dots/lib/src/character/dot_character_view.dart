import 'package:flutter/widgets.dart';
import 'package:merging_dots/src/character/dot_character.dart';
import 'package:merging_dots/src/character/dot_character_controller.dart';
import 'package:merging_dots/src/widgets/dot_views.dart';

/// Shows a [DotCharacter] in [state], moving to a new state whenever
/// [state] changes.
///
/// ```dart
/// DotCharacterView(
///   character: blob,
///   state: isLoading ? 'loading' : 'idle',
/// )
/// ```
///
/// Pass a [controller] to make it look somewhere or blink on cue. The view
/// then drives that controller instead of its own.
class DotCharacterView extends StatefulWidget {
  /// Shows [character] in [state], or its initial state.
  const DotCharacterView({
    required this.character,
    super.key,
    this.state,
    this.controller,
    this.seed,
  });

  /// The character to show.
  final DotCharacter character;

  /// The state to show, or null for the character's initial state.
  final String? state;

  /// Runs the character, or null to let the view create its own.
  final DotCharacterController? controller;

  /// Makes the idles' randomness repeatable, for the view's own
  /// controller.
  final int? seed;

  @override
  State<DotCharacterView> createState() => _DotCharacterViewState();
}

class _DotCharacterViewState extends State<DotCharacterView>
    with TickerProviderStateMixin {
  DotCharacterController? _own;

  DotCharacterController get _controller => widget.controller ?? _own!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _createOwn();
  }

  void _createOwn() {
    _own = DotCharacterController(
      vsync: this,
      character: widget.character,
      initialState: widget.state,
      seed: widget.seed,
    );
  }

  @override
  void didUpdateWidget(DotCharacterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && _own == null) _createOwn();
    if (widget.controller != null && _own != null) {
      _own!.dispose();
      _own = null;
    }
    final controller = _controller..character = widget.character;
    final state = widget.state;
    if (state != null && state != oldWidget.state) controller.goTo(state);
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DotSceneRenderer(
    animator: _controller.animator,
    style: widget.character.style,
    modifier: _controller,
  );
}
