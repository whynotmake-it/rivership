import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// A sheet that cannot be dismissed by dragging. The user must tap the Close
/// button to dismiss it. Useful for confirmation dialogs or critical flows.
///
/// See also: [StupidSimpleCupertinoSheetRoute]
void showNonDraggableSheet(BuildContext context) {
  Navigator.of(context).push(
    StupidSimpleCupertinoSheetRoute(
      backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
      draggable: false,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: const NonDraggableSheetExample(),
    ),
  );
}

class NonDraggableSheetExample extends StatelessWidget {
  const NonDraggableSheetExample({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Non-Draggable Sheet'),
            leading: CupertinoButton(
              child: Text("Close"),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 16,
                children: [
                  Text(
                    'This sheet cannot be dragged!',
                    style: CupertinoTheme.of(context).textTheme.textStyle,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Use the Close button to dismiss.',
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .copyWith(color: CupertinoColors.secondaryLabel),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
