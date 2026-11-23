import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet_example/capabilities/capability.dart';
import 'package:stupid_simple_sheet_example/shell/demo_scaffold.dart';
import 'package:stupid_simple_sheet_example/shell/home_logo.dart';

/// The example's front page: the playground, then every capability as its
/// own card, grouped by what it is about.
class SheetHomePage extends StatelessWidget {
  /// Creates the home page.
  const SheetHomePage({super.key, this.onHome});

  /// Called when the logo is pressed, to go back to a combined gallery's
  /// landing page. Null leaves the logo as a plain image.
  final VoidCallback? onHome;

  /// The widest the page gets; wider windows center it.
  static const maxContentWidth = 960.0;

  /// From this width on, the sections sit in two columns.
  static const twoColumnWidth = 900.0;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final padding = MediaQuery.paddingOf(context);
    final gutter = DemoScaffold.gutterOf(context);
    final gap = DemoScaffold.sectionGapOf(context);
    final twoColumns = MediaQuery.sizeOf(context).width >= twoColumnWidth;
    final sections = [
      for (final group in capabilityGroups) _Section(group: group),
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: padding.top + 24,
        bottom: padding.bottom + 24,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth + 2 * gutter),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
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
                  'Spring-driven sheets for Flutter. Every card opens one '
                  'sheet that shows one thing it can do.',
                  style: text.muted.body,
                ),
                SizedBox(height: gap),
                CoilCard(
                  title: const Text('Playground'),
                  description: const Text(
                    'Configure every option, open the sheet and copy the '
                    'code.',
                  ),
                  onPressed: () =>
                      context.navigateTo(const NamedRoute('sheet:playground')),
                ),
                SizedBox(height: gap),
                if (twoColumns)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: gap,
                    children: [
                      for (final column in [0, 1])
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: gap,
                            children: [
                              for (final (index, section) in sections.indexed)
                                if (index.isEven == (column == 0)) section,
                            ],
                          ),
                        ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: gap,
                    children: sections,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One group of capabilities: a muted caption heading over its cards.
class _Section extends StatelessWidget {
  const _Section({required this.group});

  final CapabilityGroup group;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Semantics(
            header: true,
            child: Text(
              group.title,
              style: text.muted.caption.copyWith(fontWeight: text.emphasis),
            ),
          ),
        ),
        CoilCardGroup(
          children: [
            for (final capability in group.capabilities)
              CoilCard(
                title: Text(capability.title),
                description: Text(capability.description),
                onPressed: () => capability.open(context).ignore(),
              ),
          ],
        ),
      ],
    );
  }
}
