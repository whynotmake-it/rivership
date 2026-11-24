import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A photo from the network that fades in over [background] once it has
/// loaded, so a tile never flashes empty.
///
/// A photo that fails to load leaves [background] showing.
class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto(
    this.url, {
    required this.background,
    super.key,
    this.fit = BoxFit.cover,
    this.motion = const CupertinoMotion.smooth(),
  });

  final String url;

  /// The fill while the photo loads.
  final Color background;

  final BoxFit fit;

  /// How the photo fades in.
  final Motion motion;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: background,
    child: Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          wasSynchronouslyLoaded
          ? child
          : SingleMotionBuilder(
              value: frame == null ? 0 : 1,
              motion: motion,
              builder: (context, opacity, child) =>
                  Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
              child: child,
            ),
    ),
  );
}
