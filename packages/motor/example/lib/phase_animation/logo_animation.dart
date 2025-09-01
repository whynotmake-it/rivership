import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

class LogoAnimation extends StatelessWidget {
  const LogoAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Center(
        child: SequenceMotionBuilder(
          sequence: MotionSequence.stepsWithMotions(
            [
              (
                const LogoState(),
                NoMotion(Duration(seconds: 1)),
              ),
              (
                const LogoState(logoOpacity: 1),
                CurvedMotion(Duration(seconds: 1), Curves.ease),
              ),
              (
                const LogoState(logoOpacity: 1, textOpacity: 1, textWidth: 1),
                Motion.smoothSpring(duration: const Duration(seconds: 1)),
              ),
              (
                const LogoState(logoOpacity: 1, textOpacity: 1, textWidth: 1),
                NoMotion(Duration(seconds: 3)),
              ),
              (
                const LogoState(logoOpacity: 0, textOpacity: 0, textWidth: 1),
                CurvedMotion(Duration(seconds: 1), Curves.ease),
              ),
            ],
            loop: LoopMode.seamless,
          ),
          converter: const LogoStateConverter(),
          builder: (context, value, phase, child) => Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Opacity(
                opacity: value.logoOpacity.clamp(0, 1),
                child: const FlutterLogo(size: 50),
              ),
              SizeTransition(
                sizeFactor: AlwaysStoppedAnimation(value.textWidth),
                fixedCrossAxisSizeFactor: 1,
                axis: Axis.horizontal,
                axisAlignment: 1,
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    stops: [1 - value.textWidth, 1],
                    colors: [
                      DefaultTextStyle.of(context).style.color!.withValues(
                            alpha: value.textOpacity.clamp(0, 1),
                          ),
                      DefaultTextStyle.of(context).style.color!,
                    ],
                  ).createShader(bounds),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Opacity(
                      opacity: value.textOpacity.clamp(0, 1),
                      child: const Text(
                        'Motor',
                        style: TextStyle(
                          fontSize: 36,
                          fontFamily: 'Archivo',
                          letterSpacing: 2,
                          fontVariations: [
                            FontVariation.weight(500),
                            FontVariation.width(200),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@immutable
class LogoState {
  const LogoState({
    this.logoOpacity = 0,
    this.textOpacity = 0,
    this.textWidth = 0,
  });

  final double logoOpacity;
  final double textOpacity;
  final double textWidth;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LogoState &&
        other.logoOpacity == logoOpacity &&
        other.textOpacity == textOpacity &&
        other.textWidth == textWidth;
  }

  @override
  int get hashCode => Object.hash(logoOpacity, textOpacity, textWidth);
}

class LogoStateConverter implements MotionConverter<LogoState> {
  const LogoStateConverter();

  @override
  List<double> normalize(LogoState value) =>
      [value.logoOpacity, value.textOpacity, value.textWidth];

  @override
  LogoState denormalize(List<double> values) => LogoState(
        logoOpacity: values[0],
        textOpacity: values[1],
        textWidth: values[2],
      );
}
