import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';

/// A compact gallery for comparing every SwiftUI-like presentation state.
class SheetParityPage extends StatelessWidget {
  const SheetParityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CupertinoPageScaffold(
      backgroundColor: t.canvas,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('SwiftUI Parity'),
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
              sliver: SliverList.list(
                children: [
                  for (final kind in _SheetKind.values)
                    _ParitySection(
                      title: kind.label,
                      children: [
                        _ParityButton(
                          title: 'Automatic / form',
                          detail: 'iPad: centered card • iPhone: page sheet',
                          onPressed: () => _push(
                            context,
                            kind: kind,
                            title: 'Automatic',
                          ),
                        ),
                        _ParityButton(
                          title: 'Page',
                          detail: 'Always an edge-to-edge bottom sheet',
                          onPressed: () => _push(
                            context,
                            kind: kind,
                            title: 'Page',
                            presentationSizing: PresentationSizing.page,
                          ),
                        ),
                        _ParityButton(
                          title: 'Fitted',
                          detail: 'Regular displays hug a 320×280 child',
                          onPressed: () => _push(
                            context,
                            kind: kind,
                            title: 'Fitted',
                            presentationSizing:
                                PresentationSizing.form.fitted(),
                            fittedContent: true,
                          ),
                        ),
                        _ParityButton(
                          title: 'Sticky',
                          detail:
                              'Regular displays grow beyond the standard card',
                          onPressed: () => _push(
                            context,
                            kind: kind,
                            title: 'Sticky',
                            presentationSizing: PresentationSizing.form.sticky(
                              horizontal: true,
                              vertical: true,
                            ),
                            stickyContent: true,
                          ),
                        ),
                        _ParityButton(
                          title: 'Medium + large detents',
                          detail: 'Opens at .medium, drags to .large',
                          onPressed: () => _push(
                            context,
                            kind: kind,
                            title: 'Medium + large',
                            snappingConfig: const SheetSnappingConfig.detents(
                              [SheetDetent.medium, SheetDetent.large],
                            ),
                          ),
                        ),
                        _ParityButton(
                          title: 'Fixed-height detent',
                          detail: '320pt card + .large',
                          onPressed: () => _push(
                            context,
                            kind: kind,
                            title: 'Fixed height',
                            snappingConfig: const SheetSnappingConfig.detents(
                              [SheetDetent.height(320), SheetDetent.large],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _push(
    BuildContext context, {
    required _SheetKind kind,
    required String title,
    PresentationSizing presentationSizing = PresentationSizing.automatic,
    SheetSnappingConfig snappingConfig = SheetSnappingConfig.full,
    bool fittedContent = false,
    bool stickyContent = false,
  }) {
    final child = _ParitySheet(
      kind: kind,
      title: title,
      presentationSizing: presentationSizing,
      snappingConfig: snappingConfig,
      fittedContent: fittedContent,
      stickyContent: stickyContent,
    );
    switch (kind) {
      case _SheetKind.glass:
        Navigator.of(context).push(
          StupidSimpleGlassSheetRoute<void>(
            backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
            presentationSizing: presentationSizing,
            snappingConfig: snappingConfig,
            child: child,
          ),
        );
      case _SheetKind.cupertino:
        Navigator.of(context).push(
          StupidSimpleCupertinoSheetRoute<void>(
            backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
            presentationSizing: presentationSizing,
            snappingConfig: snappingConfig,
            child: child,
          ),
        );
    }
  }
}

enum _SheetKind {
  glass('Glass'),
  cupertino('Cupertino');

  const _SheetKind(this.label);

  final String label;
}

class _ParitySection extends StatelessWidget {
  const _ParitySection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: t.textSecondary,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ParityButton extends StatelessWidget {
  const _ParityButton({
    required this.title,
    required this.detail,
    required this.onPressed,
  });

  final String title;
  final String detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 3,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
            Text(
              detail,
              style: TextStyle(fontSize: 13, color: t.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParitySheet extends StatelessWidget {
  const _ParitySheet({
    required this.kind,
    required this.title,
    required this.presentationSizing,
    required this.snappingConfig,
    required this.fittedContent,
    required this.stickyContent,
  });

  final _SheetKind kind;
  final String title;
  final PresentationSizing presentationSizing;
  final SheetSnappingConfig snappingConfig;
  final bool fittedContent;
  final bool stickyContent;

  @override
  Widget build(BuildContext context) {
    if (stickyContent) {
      return SizedBox(
        width: 800,
        height: 700,
        child: SafeArea(
          child: _sheetBody(context, compact: true),
        ),
      );
    }

    if (fittedContent) {
      return SizedBox(
        width: 320,
        height: 280,
        child: SafeArea(
          child: _sheetBody(context, compact: true),
        ),
      );
    }

    return CupertinoPageScaffold(
      child: SafeArea(child: _sheetBody(context)),
    );
  }

  Widget _sheetBody(BuildContext context, {bool compact = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text(
              '${kind.label} • $title',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            Text(
              compact
                  ? (stickyContent
                      ? '800×700 sticky content'
                      : '320×280 fitted content')
                  : 'Push to test stacking',
              textAlign: TextAlign.center,
            ),
            CupertinoButton.filled(
              child: const Text('Push Again'),
              onPressed: () => SheetParityPage._push(
                context,
                kind: kind,
                title: '$title (stacked)',
                presentationSizing: presentationSizing,
                snappingConfig: snappingConfig,
                fittedContent: fittedContent,
                stickyContent: stickyContent,
              ),
            ),
            CupertinoButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
