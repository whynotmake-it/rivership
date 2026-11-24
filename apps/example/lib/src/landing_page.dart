import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/link.dart';

import 'packages.dart';

final _repositoryUri = Uri.parse('https://github.com/whynotmake-it/rivership');

/// The page that lists the packages and opens their examples.
class LandingPage extends StatelessWidget {
  /// Creates the landing page.
  const LandingPage({super.key});

  static const _maxWidth = 960.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final wide = size.width >= 600;
    final gutter = wide ? 24.0 : 16.0;
    final section = wide ? 48.0 : 32.0;
    final text = CoilTheme.textOf(context);
    final contentWidth = math.min(
      size.width - 2 * gutter - padding.horizontal,
      _maxWidth,
    );

    return ColoredBox(
      color: CoilTheme.of(context).colors.background,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          gutter + padding.left,
          padding.top + section,
          gutter + padding.right,
          padding.bottom + section,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('whynotmake.it', style: text.display),
                const SizedBox(height: 8),
                Text(
                  'Flutter packages from the rivership repository. The '
                  'examples run right here in your browser.',
                  style: text.muted.body,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _LinkButton(
                    uri: _repositoryUri,
                    label: 'GitHub',
                    variant: CoilButtonVariant.tertiary,
                  ),
                ),
                SizedBox(height: section),
                Text('Examples', style: text.title),
                const SizedBox(height: 12),
                CoilCardGroup(
                  layout: CoilCardGroupLayout.separated,
                  style: const CoilCardStyle(spacing: 16),
                  columns: contentWidth >= 720 ? 2 : 1,
                  children: [
                    for (final package in examplePackages)
                      _PackageCard(package: package),
                  ],
                ),
                SizedBox(height: section),
                Text('More packages', style: text.title),
                const SizedBox(height: 12),
                CoilCardGroup(
                  children: [
                    for (final package in morePackages)
                      _PackageCard(
                        package: package,
                        inline: contentWidth >= 600,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package, this.inline = false});

  final Package package;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final route = package.exampleRoute;
    // A ghost button's label sits inside its padding, so when it would lead
    // a stacked card's action row, the links get a hairline instead: the
    // row then starts at the card's text edge, like "Open example" does.
    final linkVariant = inline || route != null
        ? CoilButtonVariant.ghost
        : CoilButtonVariant.tertiary;
    return CoilCard(
      variant: inline ? CoilCardVariant.inline : CoilCardVariant.stacked,
      title: Text(package.name),
      description: Text(package.description),
      actions: [
        if (route != null)
          CoilButton(
            variant: CoilButtonVariant.secondary,
            size: CoilSize.compact,
            onPressed: () => context.navigateToPath(route),
            child: const Text('Open example'),
          ),
        if (package.onPub)
          _LinkButton(
            uri: package.pubUri,
            label: 'pub.dev',
            variant: linkVariant,
          ),
        _LinkButton(
          uri: package.githubUri,
          label: 'GitHub',
          variant: linkVariant,
        ),
      ],
    );
  }
}

/// A button that opens [uri] in a new tab.
class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.uri,
    required this.label,
    required this.variant,
  });

  final Uri uri;
  final String label;
  final CoilButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    return Link(
      uri: uri,
      target: LinkTarget.blank,
      builder: (context, followLink) => CoilButton(
        variant: variant,
        size: CoilSize.compact,
        onPressed: followLink,
        child: Text(label),
      ),
    );
  }
}
