import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_previews.dart';

/// Preview for the home page card — two stacked pages in one sheet.
class NestedNavigationPreview extends StatelessWidget {
  const NestedNavigationPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    Widget bar(Color color, double width) => Container(
          width: width,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        );
    return CustomPaint(
      painter: DotGridPainter(dotColor: t.textTertiary.withValues(alpha: .2)),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 48),
          child: MiniModal(
            width: 120,
            height: 76,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  bar(t.accentIndigo, 80),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.arrow_right,
                        size: 12,
                        color: t.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      bar(t.accentBlue, 64),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a content-sized sheet whose following pages merge into it.
///
/// The first sheet places a [SheetNavigator] inside its [SheetBackground], so
/// the background stays in place while the pages inside of it change. Every
/// page is a regular sheet route with its own [SheetBackground], which is only
/// drawn when the page ends up as a separate sheet.
void showNestedNavigationSheet(BuildContext context) {
  Navigator.of(context).push(
    StupidSimpleSheetRoute<void>(
      child: const SheetBackground.withTopMargin(
        child: SheetNavigator(child: _PlanPage()),
      ),
    ),
  );
}

Route<void> _pageRoute(Widget page, {bool mergeable = true}) {
  return StupidSimpleSheetRoute<void>(
    mergeable: mergeable,
    child: SheetBackground.withTopMargin(child: page),
  );
}

class _PlanPage extends StatelessWidget {
  const _PlanPage();

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'Choose a plan',
      children: [
        for (final (plan, price) in [('Basic', r'$4'), ('Pro', r'$12')])
          _Tile(
            title: plan,
            trailing: price,
            onTap: () => Navigator.of(context).push(
              _pageRoute(_DetailsPage(plan: plan)),
            ),
          ),
        const SizedBox(height: 8),
        CupertinoButton(
          child: const Text('Open as a separate sheet'),
          onPressed: () => Navigator.of(context).push(
            _pageRoute(const _DetailsPage(plan: 'Pro'), mergeable: false),
          ),
        ),
      ],
    );
  }
}

class _DetailsPage extends StatelessWidget {
  const _DetailsPage({required this.plan});

  final String plan;

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: '$plan plan',
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).pop(),
        child: const Icon(CupertinoIcons.back),
      ),
      children: [
        for (final feature in [
          'Unlimited sheets',
          'Spring physics',
          'Nested navigation',
          'Liquid glass',
          if (plan == 'Pro') ...['Priority support', 'Stickers'],
        ])
          _Tile(title: feature, trailing: '✓'),
        const SizedBox(height: 8),
        CupertinoButton.filled(
          child: const Text('Continue'),
          onPressed: () => Navigator.of(context).push(
            _pageRoute(_DonePage(plan: plan)),
          ),
        ),
      ],
    );
  }
}

class _DonePage extends StatelessWidget {
  const _DonePage({required this.plan});

  final String plan;

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'All set!',
      children: [
        Icon(
          CupertinoIcons.check_mark_circled_solid,
          size: 64,
          color: ExampleTheme.of(context).accentGreen,
        ),
        const SizedBox(height: 16),
        Text('You are on the $plan plan.', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        CupertinoButton.filled(
          child: const Text('Start over'),
          // Pops all merged pages, but keeps the first page of the sheet.
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ],
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.children,
    this.leading,
  });

  final String title;
  final Widget? leading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (leading case final leading?)
                    Align(alignment: Alignment.centerLeft, child: leading),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.title, required this.trailing, this.onTap});

  final String title;
  final String trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: TextStyle(color: t.textPrimary)),
            ),
            Text(trailing, style: TextStyle(color: t.textSecondary)),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: t.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
