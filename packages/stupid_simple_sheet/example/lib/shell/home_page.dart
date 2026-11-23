import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet_example/shell/demo_scaffold.dart';
import 'package:stupid_simple_sheet_example/shell/home_logo.dart';

/// The example's front page: what the package does, and the demos.
class SheetHomePage extends StatelessWidget {
  /// Creates the home page.
  const SheetHomePage({super.key, this.onHome});

  /// Called when the logo is pressed, to go back to a combined gallery's
  /// landing page. Null leaves the logo as a plain image.
  final VoidCallback? onHome;

  static const _demos = [
    _DemoEntry(
      route: 'sheet:detents',
      title: 'Detents',
      description:
          'A comment thread that opens halfway and drags up to full height.',
    ),
    _DemoEntry(
      route: 'sheet:handoff',
      title: 'Scroll handoff',
      description:
          'A long list that hands its drag to the sheet once it reaches the '
          'top.',
    ),
    _DemoEntry(
      route: 'sheet:nested',
      title: 'Nested navigation',
      description: 'Filters that push their pages inside one sheet.',
    ),
    _DemoEntry(
      route: 'sheet:keyboard',
      title: 'Keyboard',
      description: 'A quick-add form that stays above the keyboard.',
    ),
    _DemoEntry(
      route: 'sheet:styles',
      title: 'Route styles',
      description: 'The same share sheet as coil, glass and Cupertino.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final padding = MediaQuery.paddingOf(context);
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: padding.top + 24,
        bottom: padding.bottom + 24,
      ),
      child: DemoContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HomeLogo(onPressed: onHome),
            const SizedBox(height: HomeLogo.gap),
            Semantics(
              header: true,
              child: Text('Stupid Simple Sheet', style: text.display),
            ),
            const SizedBox(height: 8),
            Text(
              'Sheets that snap, hand off from scrolling and ride on the '
              'keyboard, with spring physics.',
              style: text.muted.body,
            ),
            SizedBox(height: DemoScaffold.sectionGapOf(context)),
            CoilCardGroup(
              children: [
                for (final demo in _demos)
                  CoilCard(
                    title: Text(demo.title),
                    description: Text(demo.description),
                    onPressed: () => context.navigateTo(NamedRoute(demo.route)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoEntry {
  const _DemoEntry({
    required this.route,
    required this.title,
    required this.description,
  });

  final String route;
  final String title;
  final String description;
}
