import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

enum _Mode { off, idle, heating, cooling }

const _minTemp = 50.0;
const _maxTemp = 85.0;

const _slate = Color(0xFF6E7A8A);
const _green = Color(0xFF3FB07A);
const _orange = Color(0xFFF0852E);
const _cyan = Color(0xFF35BFD0);

/// A real thermostat: drag the dial to set your target temperature — it sticks,
/// like a Nest. The room temperature then drifts toward it, and the system mode
/// (off / idle / heating / cooling) is *derived* from that relationship.
///
/// Every value here is a [Track] on one [PhaseTrackController]. The color and
/// glow tracks are driven by [PhaseTrackController.goToPhase]; the room track is
/// never named in the phase timeline, so it animates entirely on its own via
/// [TrackController.animate] — one track running independently of the phases on
/// the very same controller.
class ThermostatPage extends StatefulWidget {
  const ThermostatPage({super.key});
  static const routeName = 'Thermostat';

  @override
  State<ThermostatPage> createState() => _ThermostatPageState();
}

class _ThermostatPageState extends State<ThermostatPage>
    with TickerProviderStateMixin {
  late final PhaseTrackController<_Mode> _controller =
      PhaseTrackController<_Mode>(vsync: this);

  // The room temperature drifts toward the target to simulate a real HVAC
  // system catching up. It lives on the same controller as the phase tracks but
  // is driven independently, never appearing in the phase timeline.
  final _room = Track<double>(
    .single,
    initial: 67,
    motion: .smoothSpring(duration: Duration(seconds: 3)),
  );

  // Visual tracks driven by the system mode, each on its own clock.
  final _ringColor = Track<Color>(
    .colorRgb,
    initial: _orange,
    motion: .smoothSpring(duration: Duration(milliseconds: 750)),
  );
  final _glow = Track<double>(
    .single,
    initial: 1,
    motion: .smoothSpring(duration: Duration(milliseconds: 450)),
  );

  double _target = 72;
  bool _power = true;
  _Mode _mode = _Mode.heating;

  // The timeline names only the phase tracks — the room track is deliberately
  // absent, so goToPhase never touches it.
  late final _timeline = TrackPhaseTimeline<_Mode>(
    {
      .off: [_ringColor.to(_slate), _glow.to(0)],
      .idle: [_ringColor.to(_green), _glow.to(.18)],
      .heating: [_ringColor.to(_orange), _glow.to(1)],
      .cooling: [_ringColor.to(_cyan), _glow.to(.7)],
    },
    from: [_ringColor.value(_orange), _glow.value(1)],
  );

  @override
  void initState() {
    super.initState();
    _controller.setTimeline(_timeline);
    _controller.addListener(_updateMode);
    // Enter mid-heat so the page is alive on arrival, then settles to idle.
    _controller.animate([_room.to(_target)]);
    _controller.goToPhase(_mode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _Mode _resolveMode() {
    if (!_power) return _Mode.off;
    final room = _controller.value(_room);
    if (_target > room + 0.4) return _Mode.heating;
    if (_target < room - 0.4) return _Mode.cooling;
    return _Mode.idle;
  }

  void _updateMode() {
    final next = _resolveMode();
    if (next != _mode) {
      setState(() => _mode = next);
      // Phase tracks transition; the room track keeps animating, untouched.
      _controller.goToPhase(next);
    }
  }

  void _onDialDrag(DragUpdateDetails d) {
    // Drag sets the target and it sticks — up is warmer.
    setState(() {
      _target = (_target - d.delta.dy * 0.15).clamp(_minTemp, _maxTemp);
    });
    if (_power) _controller.animate([_room.to(_target)]);
    _updateMode();
  }

  void _togglePower() {
    setState(() => _power = !_power);
    if (_power) {
      _controller.animate([_room.to(_target)]);
    } else {
      _controller.stop(tracks: [_room]);
    }
    _updateMode();
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ExamplePage(
      title: ThermostatPage.routeName,
      description:
          'Drag the dial to set your target — it sticks. The room temperature '
          'is its own track, drifting toward the target independently while the '
          'color and glow tracks are driven by phase changes on the very same '
          'controller — one track ignoring the phases entirely.',
      child: Column(
        children: [
          SizedBox(
            height: 340,
            child: Surface(
              child: Center(
                child: GestureDetector(
                  onVerticalDragUpdate: _onDialDrag,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final color = _power
                          ? _controller.value(_ringColor)
                          : _slate;
                      final glow = _controller.value(_glow).clamp(0.0, 1.0);
                      final room = _controller.value(_room);
                      return SizedBox(
                        width: 250,
                        height: 250,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(250, 250),
                              painter: _DialPainter(
                                color: color,
                                targetFraction:
                                    (_target - _minTemp) /
                                    (_maxTemp - _minTemp),
                                roomFraction:
                                    ((room - _minTemp) / (_maxTemp - _minTemp))
                                        .clamp(0.0, 1.0),
                                glow: _power ? glow : 0,
                                trackColor: t.border,
                                markerColor: t.textTertiary,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_iconFor(_mode), color: color, size: 28),
                                const SizedBox(height: 6),
                                Text(
                                  '${_target.round()}°',
                                  style: TextStyle(
                                    fontFamily: 'Archivo',
                                    fontSize: 60,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: -2,
                                    color: t.textPrimary,
                                  ),
                                ),
                                Text(
                                  _power
                                      ? '${_modeLabel(_mode)} · now ${room.round()}°'
                                      : 'OFF',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                    color: t.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Drag the dial to set the temperature',
                style: TextStyle(color: t.textTertiary, fontSize: 13),
              ),
              NeutralButton(
                onPressed: _togglePower,
                child: Text(_power ? 'Turn off' : 'Turn on'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _modeLabel(_Mode mode) => switch (mode) {
    _Mode.off => 'OFF',
    _Mode.idle => 'IDLE',
    _Mode.heating => 'HEATING',
    _Mode.cooling => 'COOLING',
  };

  IconData _iconFor(_Mode mode) => switch (mode) {
    _Mode.off => CupertinoIcons.power,
    _Mode.idle => CupertinoIcons.checkmark_alt,
    _Mode.heating => CupertinoIcons.flame_fill,
    _Mode.cooling => CupertinoIcons.snow,
  };
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.color,
    required this.targetFraction,
    required this.roomFraction,
    required this.glow,
    required this.trackColor,
    required this.markerColor,
  });

  final Color color;
  final double targetFraction;
  final double roomFraction;
  final double glow;
  final Color trackColor;
  final Color markerColor;

  static const _start = -math.pi / 2;
  static const _span = math.pi * 1.9;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 14;
    const stroke = 14.0;

    // Background track.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _start,
      _span,
      false,
      Paint()
        ..color = trackColor
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Glow halo.
    if (glow > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _start,
        _span * targetFraction,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.35 * glow)
          ..strokeWidth = stroke + 12 * glow
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 10 * glow),
      );
    }

    // Colored setpoint arc up to the target.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _start,
      _span * targetFraction,
      false,
      Paint()
        ..color = color
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Marker for the current room temperature.
    final angle = _start + _span * roomFraction;
    final marker = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(marker, 5, Paint()..color = markerColor);
    canvas.drawCircle(
      marker,
      5,
      Paint()
        ..color = trackColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) =>
      color != oldDelegate.color ||
      targetFraction != oldDelegate.targetFraction ||
      roomFraction != oldDelegate.roomFraction ||
      glow != oldDelegate.glow ||
      trackColor != oldDelegate.trackColor ||
      markerColor != oldDelegate.markerColor;
}
