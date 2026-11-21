import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:flutter/cupertino.dart';

/// Wraps an example in the bar that leads back to the landing page.
///
/// The Cupertino-based examples were written for `CupertinoApp`, so with
/// [cupertino] this provides what that app used to: the theme, the default
/// text and selection styles and the scroll behavior. The coil catalog sets
/// up its own environment and needs none of it.
class ExampleFrame extends StatelessWidget {
  /// Creates a frame around [child], the example named [package].
  const ExampleFrame({
    required this.package,
    required this.child,
    this.cupertino = true,
    super.key,
  });

  /// The package's name, shown as the current crumb.
  final String package;

  /// The example, usually its own `AutoRouter`.
  final Widget child;

  /// Whether to provide `CupertinoApp`'s environment to [child].
  final bool cupertino;

  @override
  Widget build(BuildContext context) {
    Widget body = MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: child,
    );
    if (cupertino) body = _CupertinoEnvironment(child: body);
    return ColoredBox(
      color: CoilTheme.of(context).colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExampleBar(package: package),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// What `CupertinoApp` wraps its pages in.
class _CupertinoEnvironment extends StatelessWidget {
  const _CupertinoEnvironment({required this.child});

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

/// The bar above an example: a breadcrumb from the landing page to the
/// example's package.
class ExampleBar extends StatelessWidget {
  /// Creates the bar for the example named [package].
  const ExampleBar({required this.package, super.key});

  /// The package's name, shown as the current crumb.
  final String package;

  /// A crumb's own horizontal padding, which the bar's start padding
  /// offsets so the first label lines up with the page gutter.
  static const _crumbPadding = 6.0;

  /// Where the first label starts.
  static const _gutter = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final touch = CoilTheme.tierOf(context) == CoilTier.touch;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: _gutter - _crumbPadding,
          end: _gutter - _crumbPadding,
          top: MediaQuery.viewPaddingOf(context).top + 4,
          bottom: 4,
        ),
        child: Semantics(
          container: true,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: CoilBreadcrumb(
              // Crumbs are 44 px tall on touch.
              size: touch ? CoilSize.regular : null,
              crumbs: [
                CoilCrumb(
                  label: const Text('Packages'),
                  onPressed: () =>
                      context.router.root.navigate(const NamedRoute('Home')),
                ),
                CoilCrumb(label: Text(package)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
