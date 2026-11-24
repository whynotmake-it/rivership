import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet_example/capabilities/capability.dart';
import 'package:stupid_simple_sheet_example/capabilities/capability_sheet.dart';
import 'package:stupid_simple_sheet_example/shell/coil_sheets.dart';

/// How tall a sheet gets, and what moves it.
final sizeCapabilities = <Capability>[
  Capability(
    title: 'Full height',
    description: 'A list grows the sheet up to the top cap.',
    code: _fullCode,
    open: (context) => Navigator.of(context).push(
      exampleSheetRoute<void>(
        context: context,
        child: const CapabilitySheet(
          title: 'Full height',
          hint:
              'The list fills the sheet to the top cap, which leaves the '
              'status bar clear.',
          code: _fullCode,
          layout: CapabilitySheetLayout.fills,
          children: [_Rows(24)],
        ),
      ),
    ),
  ),
  Capability(
    title: 'Fits its content',
    description: 'Three rows make a sheet three rows tall.',
    code: _fitsCode,
    open: (context) => Navigator.of(context).push(
      exampleSheetRoute<void>(
        context: context,
        child: const CapabilitySheet(
          title: 'Fits its content',
          hint: 'Nothing sets this height: the content does.',
          code: _fitsCode,
          children: [_Rows(3)],
        ),
      ),
    ),
  ),
  Capability(
    title: 'Growing content',
    description: 'Add a row and the sheet resizes around its new content.',
    code: _growingCode,
    open: (context) => Navigator.of(context).push(
      exampleSheetRoute<void>(context: context, child: const _GrowingSheet()),
    ),
  ),
  Capability(
    title: 'Above the keyboard',
    description: 'A focused field rides up with the keyboard.',
    code: _keyboardCode,
    open: (context) => Navigator.of(context).push(
      exampleSheetRoute<void>(context: context, child: const _KeyboardSheet()),
    ),
  ),
];

const _fullCode = '''
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    // A scrollable fills the sheet; the route caps it below the
    // top safe area.
    child: ListView(children: rows),
  ),
);''';

const _fitsCode = '''
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    // Content that sizes itself makes a sheet of the same height,
    // sitting on the bottom edge.
    child: Column(mainAxisSize: MainAxisSize.min, children: rows),
  ),
);''';

const _growingCode = '''
// StupidSimpleSheetRoute sizes itself around its content, so
// adding a row grows the sheet automatically. Wrap the child
// in a size animation if you want the resize to animate.
setState(() => _rows += 1);''';

const _keyboardCode = '''
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    // The sheet starts above the keyboard instead of behind it,
    // so a focused field stays in sight. coil's sheet sets it.
    originateAboveBottomViewInset: true,
    child: YourForm(),
  ),
);''';

/// Numbered rows as one widget, so a const sheet can hold them.
class _Rows extends StatelessWidget {
  const _Rows(this.count);

  final int count;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: capabilityRows(count),
  );
}

/// A sheet that grows a row at a time.
class _GrowingSheet extends StatefulWidget {
  const _GrowingSheet();

  @override
  State<_GrowingSheet> createState() => _GrowingSheetState();
}

class _GrowingSheetState extends State<_GrowingSheet> {
  int _rows = 2;

  @override
  Widget build(BuildContext context) => CapabilitySheet(
    title: 'Growing content',
    hint: 'Add rows: the sheet resizes around its new content.',
    code: _growingCode,
    footer: Padding(
      padding: const EdgeInsets.symmetric(horizontal: sheetInset),
      child: CoilActionBar(
        actions: [
          if (_rows > 1)
            CoilButton(
              variant: CoilButtonVariant.secondary,
              onPressed: () => setState(() => _rows -= 1),
              child: const Text('Remove row'),
            ),
          CoilButton(
            onPressed: () => setState(() => _rows += 1),
            child: const Text('Add row'),
          ),
        ],
      ),
    ),
    children: capabilityRows(_rows),
  );
}

/// A sheet with one field in it, to open the keyboard under.
class _KeyboardSheet extends StatefulWidget {
  const _KeyboardSheet();

  @override
  State<_KeyboardSheet> createState() => _KeyboardSheetState();
}

class _KeyboardSheetState extends State<_KeyboardSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CapabilitySheet(
    title: 'Above the keyboard',
    hint: 'Tap the field: the sheet rides up on the keyboard.',
    code: _keyboardCode,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: sheetInset),
        child: CoilField(
          label: const Text('Note'),
          child: CoilInput(
            controller: _controller,
            placeholder: const Text('Type here'),
            textInputAction: TextInputAction.done,
          ),
        ),
      ),
    ],
  );
}
