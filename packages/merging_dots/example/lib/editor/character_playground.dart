import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
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
    'pulse': 'Pulse',
    'goo': 'Goo',
    'orbit': 'Orbit',
    'idle': 'Idle',
    'happy': 'Happy',
    'surprised': 'Surprised',
    'thinking': 'Thinking',
    'sleepy': 'Sleepy',
    'done': 'Done',
    'error': 'Error',
  };

  var _body = BlobBody.round;
  var _tuning = const BlobTuning();
  var _thirtyFps = false;

  // Every motion of the character ticks with this state, so this one rate
  // drives the dots, the transitions and all idles.
  @override
  TickerRate get tickerRate =>
      _thirtyFps ? TickerRate.fps(30) : const TickerRate.vsync();
  late DotCharacter _character = _build();

  DotCharacter _build() => BlobCharacter.build(body: _body, tuning: _tuning);

  void _retune(BlobTuning tuning) {
    setState(() => _tuning = tuning);
    _controller.character = _character = _build();
  }

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
      size: CoilDialogSize.xl,
      title: const Text('Character'),
      description: const Text(
        'A DotCharacter: states, transitions and idles on one layered dot '
        'scene. Point at it and it looks at you, tap it to make it blink.',
      ),
      onClose: () => Navigator.of(context).pop(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _stage()),
          const SizedBox(width: 24),
          SizedBox(
            width: 300,
            height: math.min(560, MediaQuery.sizeOf(context).height * 0.65),
            child: _tuningPanel(),
          ),
        ],
      ),
    );
  }

  Widget _stage() {
    return Column(
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
                onPressed: () {
                  setState(() => _body = body);
                  _controller.character = _character = _build();
                },
                child: Text(body.name),
              ),
          ],
        ),
      ],
    );
  }

  Widget _tuningPanel() {
    final t = _tuning;
    Widget slider(
      String label,
      double value,
      double min,
      double max,
      BlobTuning Function(double value) apply,
    ) => PropertySlider(
      label: label,
      value: value,
      min: min,
      max: max,
      onChanged: (value) => _retune(apply(value)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: RoleText('Tuning', role: TextRole.caption, muted: true),
            ),
            CoilButton(
              variant: CoilButtonVariant.ghost,
              size: CoilSize.compact,
              onPressed: () => _retune(const BlobTuning()),
              child: const Text('Reset'),
            ),
            CoilButton(
              variant: CoilButtonVariant.tertiary,
              size: CoilSize.compact,
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: _tuning.toDart())),
              child: const Text('Copy'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: CoilScrollArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                const RoleText('Face', role: TextRole.caption, muted: true),
                slider(
                  'Body blend',
                  t.bodyBlend,
                  0.3,
                  2.5,
                  (v) => t.copyWith(bodyBlend: v),
                ),
                slider(
                  'Eye size',
                  t.eyeSize,
                  0.5,
                  1.6,
                  (v) => t.copyWith(eyeSize: v),
                ),
                slider(
                  'Eye spacing',
                  t.eyeSpacing,
                  0.6,
                  1.5,
                  (v) => t.copyWith(eyeSpacing: v),
                ),
                slider(
                  'Eye blend',
                  t.eyeBlend,
                  0,
                  12,
                  (v) => t.copyWith(eyeBlend: v),
                ),
                slider(
                  'Eye edge',
                  t.eyeEdge,
                  0,
                  10,
                  (v) => t.copyWith(eyeEdge: v),
                ),
                const RoleText('3D', role: TextRole.caption, muted: true),
                slider(
                  'Eye depth',
                  t.eyeDepth,
                  0,
                  2,
                  (v) => t.copyWith(eyeDepth: v),
                ),
                slider(
                  'Turn sideways',
                  t.turn.dx,
                  0,
                  1.2,
                  (v) => t.copyWith(turn: Offset(v, t.turn.dy)),
                ),
                slider(
                  'Turn up and down',
                  t.turn.dy,
                  0,
                  0.9,
                  (v) => t.copyWith(turn: Offset(t.turn.dx, v)),
                ),
                const RoleText('Loaders', role: TextRole.caption, muted: true),
                slider(
                  'Loading blend',
                  t.loadingBlend,
                  0,
                  20,
                  (v) => t.copyWith(loadingBlend: v),
                ),
                slider(
                  'Pulse blend',
                  t.pulseBlend,
                  0,
                  24,
                  (v) => t.copyWith(pulseBlend: v),
                ),
                slider(
                  'Goo blend',
                  t.gooBlend,
                  0,
                  24,
                  (v) => t.copyWith(gooBlend: v),
                ),
                slider(
                  'Goo push',
                  t.gooPush,
                  0,
                  16,
                  (v) => t.copyWith(gooPush: v),
                ),
                slider(
                  'Goo swell',
                  t.gooSwell,
                  1,
                  1.6,
                  (v) => t.copyWith(gooSwell: v),
                ),
                slider(
                  'Orbit blend',
                  t.orbitBlend,
                  0,
                  40,
                  (v) => t.copyWith(orbitBlend: v),
                ),
                CoilSwitch(
                  value: t.orbit3d,
                  label: const Text('3D orbit'),
                  onChanged: (v) => _retune(t.copyWith(orbit3d: v)),
                ),
                slider(
                  'Orbit radius',
                  t.orbitRadius,
                  6,
                  26,
                  (v) => t.copyWith(orbitRadius: v),
                ),
                slider(
                  'Orbit tilt',
                  t.orbitTilt,
                  0,
                  1.4,
                  (v) => t.copyWith(orbitTilt: v),
                ),
                slider(
                  'Orbit dot size',
                  t.orbitDotSize,
                  4,
                  12,
                  (v) => t.copyWith(orbitDotSize: v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
