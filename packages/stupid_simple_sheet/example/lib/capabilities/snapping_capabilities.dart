import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet_example/capabilities/capability.dart';
import 'package:stupid_simple_sheet_example/capabilities/capability_sheet.dart';
import 'package:stupid_simple_sheet_example/shell/coil_sheets.dart';

/// Where a sheet comes to rest, and what gets it there.
final snappingCapabilities = <Capability>[
  Capability(
    title: 'Detents',
    description: 'Three stops, opening at the middle one.',
    code: _detentsCode,
    open: (context) => Navigator.of(context).push(
      exampleSheetRoute<void>(
        context: context,
        snappingConfig: _detents,
        child: const CapabilitySheet(
          title: 'Detents',
          hint: 'Drag between the three stops: a third, two thirds, full.',
          code: _detentsCode,
          layout: CapabilitySheetLayout.fills,
          children: [_Rows(12)],
        ),
      ),
    ),
  ),
  Capability(
    title: 'Move from code',
    description: 'Send the sheet to a stop, or take its stops away.',
    code: _controllerCode,
    open: (context) => Navigator.of(context).push(
      exampleSheetRoute<void>(
        context: context,
        snappingConfig: _detents,
        child: const _ControllerSheet(),
      ),
    ),
  ),
  Capability(
    title: 'Fling physics',
    description: 'A fling moves one stop, however hard you throw it.',
    code: _flingCode,
    open: (context) => Navigator.of(context).push(
      exampleSheetRoute<void>(
        context: context,
        snappingConfig: const SheetSnappingConfig([
          0.33,
          0.66,
          1,
        ], initialSnap: 0.33),
        child: const CapabilitySheet(
          title: 'Fling physics',
          hint:
              'Fling the sheet up hard: it stops at the next stop, not '
              'the top. This is the default.',
          code: _flingCode,
          layout: CapabilitySheetLayout.fills,
          children: [_Rows(12)],
        ),
      ),
    ),
  ),
  Capability(
    title: 'Friction physics',
    description: 'A hard fling carries past a stop, as scrolling does.',
    code: _frictionCode,
    open: (context) => Navigator.of(context).push(
      exampleSheetRoute<void>(
        context: context,
        snappingConfig: const SheetSnappingConfig(
          [0.33, 0.66, 1],
          initialSnap: 0.33,
          physics: FrictionSnapPhysics(),
        ),
        child: const CapabilitySheet(
          title: 'Friction physics',
          hint:
              'Fling the sheet up hard: it skips the middle stop and '
              'settles where the throw would have ended.',
          code: _frictionCode,
          layout: CapabilitySheetLayout.fills,
          children: [_Rows(12)],
        ),
      ),
    ),
  ),
];

const _detents = SheetSnappingConfig([0.33, 0.66, 1], initialSnap: 0.66);

const _detentsCode = '''
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    snappingConfig: SheetSnappingConfig(
      [0.33, 0.66, 1.0],
      initialSnap: 0.66,
    ),
    child: YourContent(),
  ),
);''';

const _controllerCode = '''
final sheet = StupidSimpleSheetController.maybeOf<void>(context);

// Move to a stop.
sheet?.animateToRelative(0.33, snap: true);

// Leave only the full stop, and go there.
sheet?.overrideSnappingConfig(
  SheetSnappingConfig.full,
  animateToComply: true,
);

// Give the stops back.
sheet?.overrideSnappingConfig(null);''';

const _flingCode = '''
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    snappingConfig: SheetSnappingConfig(
      [0.33, 0.66, 1.0],
      initialSnap: 0.33,
      physics: FlingSnapPhysics(),
    ),
    child: YourContent(),
  ),
);''';

const _frictionCode = '''
Navigator.of(context).push(
  StupidSimpleSheetRoute(
    snappingConfig: SheetSnappingConfig(
      [0.33, 0.66, 1.0],
      initialSnap: 0.33,
      physics: FrictionSnapPhysics(),
    ),
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

/// The sheet that moves itself: buttons for each stop, and a toggle that
/// takes the middle stops away.
class _ControllerSheet extends StatefulWidget {
  const _ControllerSheet();

  @override
  State<_ControllerSheet> createState() => _ControllerSheetState();
}

class _ControllerSheetState extends State<_ControllerSheet> {
  /// Whether the stops have been overridden down to the full one.
  bool _onlyFull = false;

  StupidSimpleSheetController<void>? get _sheet =>
      StupidSimpleSheetController.maybeOf<void>(context);

  void _moveTo(double position) =>
      _sheet?.animateToRelative(position, snap: true);

  void _toggleStops() {
    final sheet = _sheet;
    if (sheet == null) return;
    if (_onlyFull) {
      sheet.overrideSnappingConfig(null);
    } else {
      sheet.overrideSnappingConfig(
        SheetSnappingConfig.full,
        animateToComply: true,
      );
    }
    setState(() => _onlyFull = !_onlyFull);
  }

  @override
  Widget build(BuildContext context) => CapabilitySheet(
    title: 'Move from code',
    hint:
        'Send the sheet to a stop, or leave it only the full one and '
        'watch it go there.',
    code: _controllerCode,
    layout: CapabilitySheetLayout.fills,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: sheetInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Row(
              spacing: 8,
              children: [
                for (final (label, position) in const [
                  ('33%', 0.33),
                  ('66%', 0.66),
                  ('Full', 1.0),
                ])
                  Expanded(
                    child: CoilButton(
                      variant: CoilButtonVariant.secondary,
                      onPressed: () => _moveTo(position),
                      child: Text(label),
                    ),
                  ),
              ],
            ),
            CoilButton(
              variant: CoilButtonVariant.secondary,
              onPressed: _toggleStops,
              child: Text(_onlyFull ? 'Restore stops' : 'Remove stops'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      ...capabilityRows(12),
    ],
  );
}
