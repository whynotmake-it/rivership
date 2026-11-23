import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';

/// Wraps a page of the example in coil's theme and its page floor.
///
/// The example is mounted inside other apps (the aggregate example runs it
/// under a `CupertinoApp`), so each page carries its own theme instead of
/// the app root. The theme follows the platform brightness and uses coil's
/// Allo typography.
class SheetExampleTheme extends StatelessWidget {
  /// Wraps [child] in the example's coil theme.
  const SheetExampleTheme({required this.child, super.key});

  /// The page.
  final Widget child;

  static final _light = CoilThemeData.light.copyWith(
    typography: CoilTypography.allo(roundness: 50),
  );

  static final _dark = CoilThemeData.dark.copyWith(
    typography: CoilTypography.allo(roundness: 50),
  );

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return CoilTheme(
      data: brightness == Brightness.dark ? _dark : _light,
      child: Builder(
        builder: (context) => ColoredBox(
          color: CoilTheme.of(context).colors.background,
          child: child,
        ),
      ),
    );
  }
}
