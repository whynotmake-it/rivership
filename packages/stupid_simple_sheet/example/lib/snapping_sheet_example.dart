import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// A sheet with multiple snap points (50% and 100%). Demonstrates how to
/// use [SheetSnappingConfig] and how to dynamically toggle snapping at
/// runtime via [StupidSimpleSheetController.overrideSnappingConfig].
///
/// See also: [SheetSnappingConfig], [StupidSimpleSheetController]
void showSnappingSheet(BuildContext context) {
  Navigator.of(context).push(
    StupidSimpleCupertinoSheetRoute(
      backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
      snappingConfig: SheetSnappingConfig(
        [0.5, 1.0],
        initialSnap: 0.5,
      ),
      child: const SnappingSheetExample(),
    ),
  );
}

class SnappingSheetExample extends StatefulWidget {
  const SnappingSheetExample({super.key});

  @override
  State<SnappingSheetExample> createState() => _SnappingSheetExampleState();
}

class _SnappingSheetExampleState extends State<SnappingSheetExample> {
  bool _snapDisabled = false;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Snapping Sheet'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: Text(_snapDisabled ? 'Enable Snaps' : 'Disable Snaps'),
              onPressed: () {
                final controller = StupidSimpleSheetController.maybeOf(context);
                controller
                    ?.overrideSnappingConfig(
                      _snapDisabled ? null : SheetSnappingConfig.full,
                      animateToComply: true,
                    )
                    .ignore();
                setState(() {
                  _snapDisabled = !_snapDisabled;
                });
              },
            ),
            leading: CupertinoButton(
              child: Text("Close"),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SliverFillRemaining(
            child: Center(
              child: Text(
                'Drag me to see snap points',
                style: CupertinoTheme.of(context).textTheme.textStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
