import 'dart:async';
import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

/// A "press and hold to pay" choreography. One [TrackController] plays a single
/// [TrackTimeline] where eight tracks of two types — the button morph, the
/// spinner, the checkmark draw + pop, and the receipt slide — converge through
/// a `sync` barrier so the check never starts drawing until the puck is a
/// settled circle and the spinner is gone. Release early and it springs back:
/// the whole orchestration is interruptible.
class PaymentSuccessPage extends StatefulWidget {
  const PaymentSuccessPage({super.key});
  static const routeName = 'Payment Success';

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

const _fullWidth = 220.0;
const _puck = 56.0;
const _belowReceipt = Offset(0, 240);

class _PaymentSuccessPageState extends State<PaymentSuccessPage>
    with TickerProviderStateMixin {
  late final _controller = TrackController(vsync: this);

  final _buttonW = Track<double>(.single, initial: _fullWidth);
  final _textVisibility = Track<double>(.single, initial: 1);
  final _spinnerOpacity = Track<double>(.single, initial: 0);
  final _spinnerAngle = Track<double>(.single, initial: 0);
  final _checkDraw = Track<double>(.single, initial: 0);
  final _checkScale = Track<double>(.single, initial: 1);
  final _receipt = Track<Offset>(.offset, initial: _belowReceipt);
  final _receiptOpacity = Track<double>(.single, initial: 0);

  Timer? _holdTimer;
  bool _charging = false;
  bool _committing = false;
  bool _done = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  static const _holdDuration = Duration(milliseconds: 650);

  void _onTapDown(TapDownDetails _) {
    if (_committing || _done) return;
    _holdTimer?.cancel();
    setState(() => _charging = true);
    // The button squeezes toward a circle over the hold, so the countdown is
    // something you watch and feel, then commit takes over at the puck.
    _controller.animate([
      _buttonW.to(_puck, motion: .smoothSpring(duration: _holdDuration)),
      _textVisibility.to(0, motion: .snappySpring(duration: _holdDuration)),
    ]);
    _holdTimer = Timer(_holdDuration, _commit);
  }

  void _onRelease() {
    if (_committing || _done) return;
    _holdTimer?.cancel();
    setState(() => _charging = false);
    _controller.animate([
      _buttonW.to(_fullWidth, motion: .bouncySpring()),
      _textVisibility.to(1, motion: .snappySpring(duration: _holdDuration)),
    ]);
  }

  void _commit() {
    setState(() {
      _charging = false;
      _committing = true;
    });
    _controller
        .play(
          TrackTimeline([
            // Morph the pill down to a circular puck, then wait at the barrier.
            _buttonW([
              .to(
                _puck,
                motion: .smoothSpring(duration: Duration(milliseconds: 280)),
              ),
              .sync(token: #ready),
            ]),
            // Spinner fades in, holds through "processing", fades out.
            _spinnerOpacity([
              .to(
                1,
                motion: .snappySpring(duration: Duration(milliseconds: 160)),
              ),
              .hold(const Duration(milliseconds: 750)),
              .to(
                0,
                motion: .snappySpring(duration: Duration(milliseconds: 160)),
              ),
              .sync(token: #ready),
            ]),
            // Spinner sweeps while processing.
            _spinnerAngle([
              .to(
                2 * math.pi * 3,
                motion: const CurvedMotion(
                  Duration(milliseconds: 1050),
                  Curves.easeInOut,
                ),
              ),
              .sync(token: #ready),
            ]),
            // These wait at the barrier, then run together once it releases.
            _checkDraw([
              .sync(token: #ready),
              .to(
                1,
                motion: const CurvedMotion(
                  Duration(milliseconds: 340),
                  Curves.easeOutCubic,
                ),
              ),
            ]),
            _checkScale([
              .sync(token: #ready),
              .to(
                1.3,
                motion: .bouncySpring(extraBounce: .4).trimmed(fromEnd: .5),
              ),
              .to(1),
            ]),
            _receipt([
              .sync(token: #ready),
              .to(
                Offset.zero,
                motion: .smoothSpring(duration: Duration(milliseconds: 520)),
              ),
            ]),
            _receiptOpacity([
              .sync(token: #ready),
              .to(
                1,
                motion: .smoothSpring(duration: Duration(milliseconds: 360)),
              ),
            ]),
          ]),
        )
        .whenComplete(() {
          if (mounted) setState(() => _done = true);
        });
  }

  void _reset() {
    setState(() {
      _charging = false;
      _committing = false;
      _done = false;
    });
    _controller.set([
      _buttonW.value(_fullWidth),
      _spinnerOpacity.value(0),
      _spinnerAngle.value(0),
      _checkDraw.value(0),
      _checkScale.value(1),
      _receipt.value(_belowReceipt),
      _receiptOpacity.value(0),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ExamplePage(
      title: PaymentSuccessPage.routeName,
      next: (label: 'Boarding Pass', routeName: 'Boarding Pass'),
      description:
          'Press and hold the button to pay — release early and it springs '
          'back. On commit, one timeline morphs the button into a spinner, '
          'processes, then waits at a sync barrier so the checkmark only draws '
          'once everything else has settled, and the receipt slides up.',
      action: _done
          ? Align(
              alignment: Alignment.centerLeft,
              child: NeutralButton(
                onPressed: _reset,
                child: const Text('Reset'),
              ),
            )
          : null,
      child: SizedBox(
        height: 440,
        child: Surface(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ExampleTheme.surfaceRadius),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Receipt slides up from below.
                    Align(
                      alignment: const Alignment(0, 0.62),
                      child: Transform.translate(
                        offset: _controller.value(_receipt),
                        child: Opacity(
                          opacity: _controller
                              .value(_receiptOpacity)
                              .clamp(0.0, 1.0),
                          child: const _Receipt(),
                        ),
                      ),
                    ),
                    // The morphing button / puck.
                    Align(
                      alignment: const Alignment(0, -0.35),
                      child: GestureDetector(
                        onTapDown: _onTapDown,
                        onTapUp: (_) => _onRelease(),
                        onTapCancel: _onRelease,
                        child: _PayButton(
                          width: _controller.value(_buttonW),
                          textVisibility: _controller.value(_textVisibility),
                          spinnerOpacity: _controller
                              .value(_spinnerOpacity)
                              .clamp(0.0, 1.0),
                          spinnerAngle: _controller.value(_spinnerAngle),
                          checkDraw: _controller
                              .value(_checkDraw)
                              .clamp(0.0, 1.0),
                          checkScale: _controller.value(_checkScale),
                          theme: t,
                        ),
                      ),
                    ),
                    if (!_committing && !_charging)
                      Align(
                        alignment: const Alignment(0, 0.1),
                        child: Text(
                          'press and hold',
                          style: TextStyle(
                            color: t.textTertiary,
                            fontSize: 12,
                            fontFamily: 'JetBrains Mono',
                            fontFamilyFallback: const ['monospace', 'Menlo'],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  const _PayButton({
    required this.width,
    required this.textVisibility,
    required this.spinnerOpacity,
    required this.spinnerAngle,
    required this.checkDraw,
    required this.checkScale,
    required this.theme,
  });

  final double width;
  final double textVisibility;
  final double spinnerOpacity;
  final double spinnerAngle;
  final double checkDraw;
  final double checkScale;
  final ExampleTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final showLabel = width > _puck + 40;
    return Container(
      width: width,
      height: _puck,
      decoration: BoxDecoration(
        color: t.textPrimary,
        borderRadius: BorderRadius.circular(_puck / 2),
        boxShadow: t.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showLabel)
              Opacity(
                opacity: textVisibility.clamp(0.0, 1.0),
                child: Text(
                  'Pay  \$42.00',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    color: t.surfaceSolid,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (spinnerOpacity > 0)
              Opacity(
                opacity: spinnerOpacity,
                child: Transform.rotate(
                  angle: spinnerAngle,
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CustomPaint(
                      painter: _SpinnerPainter(t.surfaceSolid),
                    ),
                  ),
                ),
              ),
            if (checkDraw > 0)
              Transform.scale(
                scale: checkScale,
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CustomPaint(
                    painter: _CheckPainter(checkDraw, t.surfaceSolid),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(2),
      -math.pi / 2,
      math.pi * 1.4,
      false,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) => color != oldDelegate.color;
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.18, h * 0.52)
      ..lineTo(w * 0.42, h * 0.74)
      ..lineTo(w * 0.82, h * 0.28);

    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(
      0,
      metric.length * progress.clamp(0.0, 1.0),
    );
    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}

class _Receipt extends StatelessWidget {
  const _Receipt();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: ShapeDecoration(
        color: t.surfaceSolid,
        shape: RoundedSuperellipseBorder(
          side: BorderSide(color: t.border),
          borderRadius: BorderRadius.circular(22),
        ),
        shadows: t.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Payment sent',
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'To Continuum · \$42.00',
            style: TextStyle(color: t.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                CupertinoIcons.checkmark_seal_fill,
                size: 18,
                color: t.textTertiary,
              ),
              const SizedBox(width: 8),
              Text(
                'Confirmed just now',
                style: TextStyle(color: t.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
