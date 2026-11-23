import 'package:coil/coil.dart';
import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet_example/playground/sheet_config.dart';
import 'package:stupid_simple_sheet_example/shell/rows.dart';

/// How many rows the long list shows.
const _rowCount = 40;

/// How many pages the pager shows.
const _pageCount = 3;

/// The two lines the short content shows.
const _shortLines = [
  'A sheet hugs its content: this one is as tall as these two lines.',
  'Drag it down to close it.',
];

/// The playground's sheet in coil widgets, for coil's route and the bare
/// route: the configuration in one line at the top, the content the
/// configuration asks for, and `CoilSheetPanel`'s close button.
class CoilPlaygroundSheet extends StatelessWidget {
  /// Creates the sheet's content for [config].
  const CoilPlaygroundSheet({required this.config, super.key});

  /// The configuration the sheet was opened with.
  final SheetConfig config;

  @override
  Widget build(BuildContext context) => ConfirmClose(
    enabled: config.confirmBeforeClosing,
    cupertino: false,
    child: CoilSheetPanel(
      title: const Text('Sheet'),
      close: config.confirmBeforeClosing
          // Named, because the default button hides itself while a
          // PopScope refuses the pop.
          ? CoilSheetCloseButton(onPressed: Navigator.of(context).maybePop)
          : const CoilSheetCloseButton(),
      child: _body(context),
    ),
  );

  Widget _summary(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(
      config.summary,
      style: CoilTheme.textOf(context).muted.caption,
    ),
  );

  Widget _body(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    switch (config.content) {
      case SheetContentKind.longList:
        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          children: [
            _summary(context),
            const SizedBox(height: 8),
            for (var i = 1; i <= _rowCount; i++)
              DemoRow(label: Text('Row $i')),
          ],
        );
      case SheetContentKind.short:
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(config.summary, style: text.muted.caption),
              for (final line in _shortLines)
                Text(line, style: text.body),
            ],
          ),
        );
      case SheetContentKind.textField:
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Text(config.summary, style: text.muted.caption),
              CoilField(
                label: const Text('Note'),
                child: const CoilInput(placeholder: Text('Type something')),
              ),
            ],
          ),
        );
      case SheetContentKind.pages:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _summary(context),
            const SizedBox(height: 8),
            Expanded(
              child: PageView(
                // A PageView takes its own behavior, so it needs the
                // sheet's to hand drags over.
                scrollBehavior: CoilSheetRoute.scrollBehaviorOf(context),
                children: [
                  for (var page = 1; page <= _pageCount; page++)
                    ListView(
                      padding: const EdgeInsets.only(bottom: 12),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                          child: Text(
                            'Page $page of $_pageCount, swipe sideways',
                            style: text.muted.caption.copyWith(
                              fontWeight: text.emphasis,
                            ),
                          ),
                        ),
                        for (var i = 1; i <= 12; i++)
                          DemoRow(label: Text('Page $page, row $i')),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
    }
  }
}

/// The playground's sheet in Cupertino widgets, so the glass and Cupertino
/// routes keep their own look: a header with a close button, the
/// configuration in one line, and the content the configuration asks for.
class CupertinoPlaygroundSheet extends StatelessWidget {
  /// Creates the sheet's content for [config]. [glass] picks the glass
  /// route's floating header over the Cupertino route's navigation bar.
  const CupertinoPlaygroundSheet({
    required this.config,
    required this.glass,
    super.key,
  });

  /// The configuration the sheet was opened with.
  final SheetConfig config;

  /// Whether the glass route opened the sheet.
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return CupertinoTheme(
      data: CupertinoThemeData(brightness: brightness),
      child: Builder(
        builder: (context) => DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: ConfirmClose(
            enabled: config.confirmBeforeClosing,
            cupertino: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (glass) _glassHeader(context) else _navigationBar(context),
                Flexible(child: _body(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navigationBar(BuildContext context) => CupertinoNavigationBar(
    automaticallyImplyLeading: false,
    leading: CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: Navigator.of(context).maybePop,
      child: const Text('Close'),
    ),
    middle: const Text('Sheet'),
  );

  Widget _glassHeader(BuildContext context) => SizedBox(
    height: 72,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Text(
          'Sheet',
          style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 16),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(44),
              onPressed: Navigator.of(context).maybePop,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemFill.resolveFrom(
                    context,
                  ),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 18,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _summary(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Text(
      config.summary,
      style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle.copyWith(
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
  );

  Widget _rows(BuildContext context, {required int count, String? prefix}) =>
      CupertinoListSection.insetGrouped(
        backgroundColor: const Color(0x00000000),
        children: [
          for (var i = 1; i <= count; i++)
            CupertinoListTile.notched(
              title: Text(prefix == null ? 'Row $i' : '$prefix, row $i'),
            ),
        ],
      );

  Widget _body(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    switch (config.content) {
      case SheetContentKind.longList:
        return ListView(
          padding: EdgeInsets.only(top: 4, bottom: bottom + 12),
          children: [_summary(context), _rows(context, count: _rowCount)],
        );
      case SheetContentKind.short:
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              _summary(context),
              for (final line in _shortLines) Text(line),
            ],
          ),
        );
      case SheetContentKind.textField:
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              _summary(context),
              const CupertinoTextField(placeholder: 'Type something'),
            ],
          ),
        );
      case SheetContentKind.pages:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summary(context),
            Expanded(
              child: PageView(
                // A PageView takes its own behavior, so it needs the
                // sheet's to hand drags over.
                scrollBehavior: CoilSheetRoute.scrollBehaviorOf(context),
                children: [
                  for (var page = 1; page <= _pageCount; page++)
                    ListView(
                      padding: EdgeInsets.only(bottom: bottom + 12),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: Text(
                            'Page $page of $_pageCount, swipe sideways',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .tabLabelTextStyle
                                .copyWith(
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                ),
                          ),
                        ),
                        _rows(context, count: 8, prefix: 'Page $page'),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
    }
  }
}

/// Stops a dismissal and asks first, for the playground's "Confirm before
/// closing" setting. With [enabled] false it is just [child].
class ConfirmClose extends StatelessWidget {
  /// Wraps [child] so a dismissal asks before the sheet closes.
  const ConfirmClose({
    required this.enabled,
    required this.cupertino,
    required this.child,
    super.key,
  });

  /// Whether to ask at all.
  final bool enabled;

  /// Whether to ask in a Cupertino alert instead of a coil dialog, so the
  /// Cupertino sheets keep their look.
  final bool cupertino;

  /// The sheet's content.
  final Widget child;

  /// Runs after [PopScope] stopped a dismissal: the sheet has sprung back,
  /// so ask what to do.
  Future<void> _ask(BuildContext context) async {
    final navigator = Navigator.of(context);
    final close = cupertino
        ? await showCupertinoDialog<bool>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Close this sheet?'),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Keep open'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Close'),
                ),
              ],
            ),
          )
        : await showCoilDialog<bool>(
            context: context,
            builder: (context) => CoilDialog(
              title: const Text('Close this sheet?'),
              actions: [
                CoilButton(
                  variant: CoilButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Keep open'),
                ),
                CoilButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
    // `pop` skips PopScope, which only guards `maybePop` and the drag.
    if (close ?? false) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _ask(context);
      },
      child: child,
    );
  }
}
