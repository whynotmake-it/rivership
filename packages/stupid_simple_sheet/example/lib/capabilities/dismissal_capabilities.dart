import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/capabilities/capability.dart';
import 'package:stupid_simple_sheet_example/capabilities/capability_sheet.dart';
import 'package:stupid_simple_sheet_example/shell/coil_sheets.dart';

/// The ways a sheet closes, and the ways it refuses to.
final dismissalCapabilities = <Capability>[
  Capability(
    title: 'Shrink to close',
    description:
        'The sheet shrinks from the top instead of sliding, so a footer '
        'stays put.',
    code: _shrinkCode,
    open: (context) => Navigator.of(context).push(
      DemoSheetRoute<void>(
        context: context,
        dismissalMode: DismissalMode.shrink,
        child: CapabilitySheet(
          title: 'Shrink to close',
          hint:
              'Drag it down: the sheet loses height from the top and the '
              'footer stays on screen. Every other sheet here slides '
              'away instead.',
          code: _shrinkCode,
          layout: CapabilitySheetLayout.fills,
          footer: Padding(
            padding: const EdgeInsets.symmetric(horizontal: sheetInset),
            child: CoilActionBar(
              actions: [
                Builder(
                  builder: (context) => CoilButton(
                    onPressed: Navigator.of(context).maybePop,
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
          children: const [_Rows(24)],
        ),
      ),
    ),
  ),
  Capability(
    title: 'Not draggable',
    description: 'Dragging does nothing; only the buttons close it.',
    code: _notDraggableCode,
    open: (context) => Navigator.of(context).push(
      DemoSheetRoute<void>(
        context: context,
        draggable: false,
        child: const CapabilitySheet(
          title: 'Not draggable',
          hint:
              'Drag the sheet: it resists and stays. The close button is '
              'the only way out, so always give one.',
          code: _notDraggableCode,
          children: [_Rows(3)],
        ),
      ),
    ),
  ),
  Capability(
    title: 'Confirm before closing',
    description: 'A drag down asks first, and the sheet stays until you '
        'answer.',
    code: _confirmCode,
    open: (context) => Navigator.of(context).push(
      DemoSheetRoute<void>(context: context, child: const _ConfirmSheet()),
    ),
  ),
  Capability(
    title: "Barrier doesn't dismiss",
    description: 'Tapping outside leaves the sheet open; dragging still '
        'closes it.',
    code: _barrierCode,
    open: (context) => Navigator.of(context).push(
      DemoSheetRoute<void>(
        context: context,
        barrierDismissible: false,
        child: const CapabilitySheet(
          title: "Barrier doesn't dismiss",
          hint:
              'Tap the dimmed page above: nothing happens. Drag down or '
              'press close.',
          code: _barrierCode,
          children: [_Rows(3)],
        ),
      ),
    ),
  ),
];

const _shrinkCode = '''
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    // Shrinking keeps the content pinned to the bottom, so a
    // pinned footer is the last thing to go.
    dismissalMode: DismissalMode.shrink,
    child: YourContent(),
  ),
);''';

const _notDraggableCode = '''
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    // No drag at all: the sheet resists in both directions.
    draggable: false,
    child: YourContent(), // give it a close button
  ),
);''';

const _confirmCode = '''
PopScope(
  // The drag rubber-bands instead of closing, and the sheet
  // asks. `pop` skips PopScope; `maybePop` goes through it.
  canPop: false,
  onPopInvokedWithResult: (didPop, _) {
    if (!didPop) _confirmClose();
  },
  child: YourContent(),
);''';

const _barrierCode = '''
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    // A tap on the dimmed page, and Esc, leave the sheet open.
    barrierDismissible: false,
    child: YourContent(),
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

/// A sheet that asks before it closes.
class _ConfirmSheet extends StatefulWidget {
  const _ConfirmSheet();

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  /// Runs when a dismissal was refused: the sheet has already rubber-
  /// banded back, so ask what to do.
  Future<void> _confirmClose() async {
    final close = await showCoilDialog<bool>(
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
    if ((close ?? false) && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _confirmClose();
    },
    child: CapabilitySheet(
      title: 'Confirm before closing',
      hint:
          'Drag the sheet down, tap the dimmed page or press close: it '
          'rubber-bands back and asks first.',
      code: _confirmCode,
      // Named, because the default button hides itself while a PopScope
      // refuses the pop, and this sheet still needs a way out.
      close: CoilSheetCloseButton(onPressed: Navigator.of(context).maybePop),
      children: const [_Rows(3)],
    ),
  );
}
