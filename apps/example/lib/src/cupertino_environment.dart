// ignore: deprecated_member_use
import 'package:flutter/cupertino.dart';

/// What `CupertinoApp` gave the Cupertino-based examples: the theme, the
/// default text and selection styles and the scroll behavior.
///
/// The app root is a coil `WidgetsApp`, so the examples written for
/// `CupertinoApp` get its environment here, and render as they do on their
/// own.
class CupertinoEnvironment extends StatelessWidget {
  /// Gives [child] `CupertinoApp`'s environment.
  const CupertinoEnvironment({required this.child, super.key});

  /// The example.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = const CupertinoThemeData().resolveFrom(context);
    return ScrollConfiguration(
      behavior: const CupertinoScrollBehavior(),
      child: CupertinoUserInterfaceLevel(
        data: CupertinoUserInterfaceLevelData.base,
        child: CupertinoTheme(
          data: theme,
          child: Builder(
            builder: (context) => DefaultSelectionStyle(
              selectionColor: theme.primaryColor.withValues(alpha: 0.2),
              cursorColor: theme.primaryColor,
              child: DefaultTextStyle(
                style: CupertinoTheme.of(context).textTheme.textStyle,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
