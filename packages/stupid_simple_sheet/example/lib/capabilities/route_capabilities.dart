import 'package:coil/coil.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/capabilities/capability.dart';
import 'package:stupid_simple_sheet_example/capabilities/capability_sheet.dart';
import 'package:stupid_simple_sheet_example/shell/code_block.dart';
import 'package:stupid_simple_sheet_example/shell/plain_sheet.dart';

/// The routes the package ships, and one of your own.
final routeCapabilities = <Capability>[
  Capability(
    title: 'Glass sheet',
    description:
        'The iOS 26 style. Glass sheets stack, and only the first one '
        'blurs the page behind.',
    code: _glassCode,
    open: (context) => _openGlass(context, 1),
  ),
  Capability(
    title: 'Cupertino sheet',
    description: 'The iOS 18 modal: the page behind it pushes back.',
    code: _cupertinoCode,
    open: (context) => Navigator.of(context).push(
      StupidSimpleCupertinoSheetRoute<void>(
        backgroundColor: CupertinoDynamicColor.resolve(
          CupertinoColors.systemGroupedBackground,
          context,
        ),
        child: const _CupertinoScope(child: _CupertinoSheet()),
      ),
    ),
  ),
  Capability(
    title: 'Plain route',
    description:
        "The bare route has no look of its own; this one wears coil's "
        'surface.',
    code: _plainCode,
    open: (context) => Navigator.of(context).push(
      PlainSheetRoute<void>(
        context: context,
        child: CapabilitySheet(
          title: 'Plain route',
          hint:
              'This sheet is a plain route with a SheetBackground around '
              "its content. coil's sheet is built the same way.",
          code: _plainCode,
          children: capabilityRows(3),
        ),
      ),
    ),
  ),
  Capability(
    title: 'Custom route',
    description:
        'A floating card from your own PopupRoute, with the sheet '
        'transition mixed in.',
    code: _customCode,
    open: (context) => Navigator.of(context).push(
      FloatingCardRoute<void>(
        motion: CoilTheme.motionOf(context).gentle,
        scrim: CoilTheme.of(context).colors.scrim,
        child: InheritedTheme.capture(
          from: context,
          to: Navigator.of(context).context,
        ).wrap(const _FloatingCard()),
      ),
    ),
  ),
];

const _glassCode = '''
Navigator.of(context).push(
  StupidSimpleGlassSheetRoute(
    child: YourContent(),
  ),
);''';

const _cupertinoCode = '''
Navigator.of(context).push(
  StupidSimpleCupertinoSheetRoute(
    backgroundColor: CupertinoColors.systemGroupedBackground,
    child: YourContent(),
  ),
);''';

const _plainCode = '''
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    // The route brings the drag, the snapping and the keyboard
    // inset; the background brings the fill and the corners.
    child: SheetBackground(
      backgroundColor: colors.surface(3),
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      child: YourContent(),
    ),
  ),
);''';

const _customCode = '''
class FloatingCardRoute<T> extends PopupRoute<T>
    with StupidSimpleSheetTransitionMixin<T> {
  FloatingCardRoute({required this.child, required this.motion});

  final Widget child;

  @override
  final Motion motion;

  @override
  SheetSnappingConfig get snappingConfig => SheetSnappingConfig.full;

  @override
  bool get barrierDismissible => true;

  @override
  Widget buildContent(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.all(16),
    child: Align(alignment: Alignment.bottomCenter, child: child),
  );
}''';

Future<void> _openGlass(BuildContext context, int depth) =>
    Navigator.of(context).push(
      StupidSimpleGlassSheetRoute<void>(
        backgroundColor: CupertinoDynamicColor.resolve(
          CupertinoColors.systemGroupedBackground,
          context,
        ),
        child: _CupertinoScope(child: _GlassSheet(depth: depth)),
      ),
    );

/// Gives Cupertino content its own theme and text style, so nothing of
/// coil's reaches it.
class _CupertinoScope extends StatelessWidget {
  const _CupertinoScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return CupertinoTheme(
      data: CupertinoThemeData(brightness: brightness),
      child: Builder(
        builder: (context) => DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: child,
        ),
      ),
    );
  }
}

/// A glass sheet, which can open another one on top of itself.
class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.depth});

  /// How many glass sheets are open, this one included.
  final int depth;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CupertinoHeader(
          title: depth == 1 ? 'Glass sheet' : 'Glass sheet $depth',
          round: true,
        ),
        const _CupertinoHint(
          'Open another one: it slides over this sheet, and the page '
          'behind stays blurred once.',
        ),
        _CupertinoRows(count: 3, from: depth * 10 - 9),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: () => _openGlass(context, depth + 1),
              child: Text('Open glass sheet ${depth + 1}'),
            ),
          ),
        ),
        const _CupertinoCode(code: _glassCode),
        const SizedBox(height: 8),
      ],
    ),
  );
}

/// The Cupertino sheet: an iOS page with a navigation bar inside it.
class _CupertinoSheet extends StatelessWidget {
  const _CupertinoSheet();

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground,
    navigationBar: CupertinoNavigationBar(
      automaticallyImplyLeading: false,
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: Navigator.of(context).maybePop,
        child: const Text('Close'),
      ),
      middle: const Text('Cupertino sheet'),
    ),
    // The bar is translucent and the page scrolls under it.
    child: SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        children: const [
          _CupertinoHint(
            'The page behind pushed back as this opened. Drag down to '
            'send it forward again.',
          ),
          _CupertinoRows(count: 4),
          SizedBox(height: 8),
          _CupertinoCode(code: _cupertinoCode),
        ],
      ),
    ),
  );
}

/// A sheet header in iOS 26's shape: the title centered, a round close
/// button in the leading corner.
class _CupertinoHeader extends StatelessWidget {
  const _CupertinoHeader({required this.title, this.round = false});

  final String title;

  /// Whether the close button is the round glyph instead of a "Close"
  /// label.
  final bool round;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Text(
          title,
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
              child: round
                  ? DecoratedBox(
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
                    )
                  : const Text('Close'),
            ),
          ),
        ),
      ],
    ),
  );
}

/// One muted line of iOS body text, saying what to try.
class _CupertinoHint extends StatelessWidget {
  const _CupertinoHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Text(
      text,
      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
  );
}

/// Numbered rows as an iOS inset list.
class _CupertinoRows extends StatelessWidget {
  const _CupertinoRows({required this.count, this.from = 1});

  final int count;
  final int from;

  @override
  Widget build(BuildContext context) => CupertinoListSection.insetGrouped(
    backgroundColor: const Color(0x00000000),
    margin: const EdgeInsets.symmetric(horizontal: 16),
    children: [
      for (var i = from; i < from + count; i++)
        CupertinoListTile.notched(title: Text('Row $i')),
    ],
  );
}

/// The snippet in iOS colors, with a button that copies it, so no coil
/// style reaches a glass or Cupertino sheet.
class _CupertinoCode extends StatelessWidget {
  const _CupertinoCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final style = textStyle.copyWith(
      fontSize: 13,
      height: 18 / 13,
      fontFamily: CodeBlock.fontFamily,
      fontFamilyFallback: CodeBlock.fontFamilyFallback,
      fontFeatures: CodeBlock.fontFeatures,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The copy button has a row of its own, so no line of code runs
            // under it.
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, end: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dart',
                      style: textStyle.copyWith(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.square(44),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: code)).ignore(),
                    child: Semantics(
                      label: 'Copy code',
                      child: Icon(
                        CupertinoIcons.doc_on_doc,
                        size: 18,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(code, style: style, softWrap: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// A [PopupRoute] of your own with the sheet transition mixed in: the
/// drag, the spring and the dismissal come from the mixin, the look from
/// [child].
class FloatingCardRoute<T> extends PopupRoute<T>
    with StupidSimpleSheetTransitionMixin<T> {
  /// Creates a route that floats [child] over the page.
  FloatingCardRoute({
    required this.child,
    required this.motion,
    required this.scrim,
  });

  /// The card.
  final Widget child;

  @override
  final Motion motion;

  /// The color over the page behind.
  final Color scrim;

  @override
  SheetSnappingConfig get snappingConfig => SheetSnappingConfig.full;

  @override
  Color? get barrierColor => scrim;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Widget buildContent(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.all(16),
    child: Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: child,
      ),
    ),
  );
}

/// The card [FloatingCardRoute] floats: coil's popover surface, its own
/// title and close button, and the snippet.
class _FloatingCard extends StatelessWidget {
  const _FloatingCard();

  @override
  Widget build(BuildContext context) {
    final radii = CoilTheme.radiiOf(context);
    return CoilAdaptiveScope(
      tier: CoilTier.touch,
      size: CoilSize.regular,
      child: CoilSurface(
        offset: CoilSurface.popoverOffset,
        borderRadius: BorderRadius.circular(radii.container),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Builder(
                        builder: (context) => Text(
                          'Custom route',
                          style: CoilTheme.textOf(context).title,
                        ),
                      ),
                    ),
                  ),
                  const CoilSheetCloseButton(),
                ],
              ),
              Builder(
                builder: (context) => Text(
                  'A card inset 16 from the edges, on its own PopupRoute. '
                  'Drag it down or tap outside to close it.',
                  style: CoilTheme.textOf(context).muted.body,
                ),
              ),
              const CodeBlock(code: _customCode),
            ],
          ),
        ),
      ),
    );
  }
}
