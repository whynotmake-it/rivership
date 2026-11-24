import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/character/blob_character.dart';
import 'package:merging_dots_example/editor/ui.dart';

/// Shows the blob character of merging_dots: pick a state and a body, and
/// point at it to make it look.
Future<void> showCharacterPlayground(BuildContext context) =>
    showCoilDialog<void>(
      context: context,
      builder: (context) => const CharacterPlayground(),
    );

/// The contents of the character dialog.
class CharacterPlayground extends StatefulWidget {
  const CharacterPlayground({super.key});

  @override
  State<CharacterPlayground> createState() => _CharacterPlaygroundState();
}

class _CharacterPlaygroundState extends State<CharacterPlayground>
    with FixedTickerProviderStateMixin {
  static const _states = {
    'loading': 'Loading',
    'idle': 'Idle',
    'happy': 'Happy',
    'surprised': 'Surprised',
    'thinking': 'Thinking',
    'sleepy': 'Sleepy',
  };

  var _body = BlobBody.round;
  var _thirtyFps = false;

  // Every motion of the character ticks with this state, so this one rate
  // drives the dots, the transitions and all idles.
  @override
  TickerRate get tickerRate =>
      _thirtyFps ? TickerRate.fps(30) : const TickerRate.vsync();
  late DotCharacter _character = BlobCharacter.build(body: _body);
  late final _controller = DotCharacterController(
    vsync: this,
    character: _character,
  )..onStateChanged = (_) => setState(() {});

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _look(Offset position, Size size) {
    final center = size.center(Offset.zero);
    _controller.lookAt(
      Offset(
        (position.dx - center.dx) / (size.width / 2),
        (position.dy - center.dy) / (size.height / 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CoilDialog(
      size: CoilDialogSize.lg,
      title: const Text('Character'),
      description: const Text(
        'A DotCharacter: states, transitions and idles on one layered dot '
        'scene. Point at it and it looks at you, tap it to make it blink.',
      ),
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, 260);
              return MouseRegion(
                onHover: (event) => _look(event.localPosition, size),
                onExit: (_) => _controller.lookAt(null),
                child: GestureDetector(
                  onTap: _controller.blink,
                  onPanUpdate: (details) => _look(details.localPosition, size),
                  onPanEnd: (_) => _controller.lookAt(null),
                  child: SizedBox.fromSize(
                    size: size,
                    child: Center(
                      child: SizedBox.square(
                        dimension: 220,
                        child: DotCharacterView(
                          character: _character,
                          controller: _controller,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          CoilSwitch(
            value: _thirtyFps,
            label: const Text('Animate at 30 fps'),
            onChanged: (value) {
              setState(() => _thirtyFps = value);
              updateTickerRate();
            },
          ),
          const SizedBox(height: 16),
          const RoleText('State', role: TextRole.caption, muted: true),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final MapEntry(:key, :value) in _states.entries)
                CoilButton(
                  variant: _controller.state == key
                      ? CoilButtonVariant.primary
                      : CoilButtonVariant.tertiary,
                  size: CoilSize.compact,
                  onPressed: () => _controller.goTo(key),
                  child: Text(value),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const RoleText('Body', role: TextRole.caption, muted: true),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final body in BlobBody.values)
                CoilButton(
                  variant: _body == body
                      ? CoilButtonVariant.secondary
                      : CoilButtonVariant.ghost,
                  size: CoilSize.compact,
                  onPressed: () => setState(() {
                    _body = body;
                    _character = BlobCharacter.build(body: body);
                    _controller.character = _character;
                  }),
                  child: Text(body.name),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
