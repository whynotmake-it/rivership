import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// A standard Cupertino-style modal sheet with a navigation bar and scrollable
/// content. Pushing the sheet pushes the previous route back, matching the
/// native iOS look and feel.
///
/// See also: [StupidSimpleCupertinoSheetRoute]
void showCupertinoSheet(BuildContext context) {
  Navigator.of(context).push(
    StupidSimpleCupertinoSheetRoute(
      backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
      child: const CupertinoSheetExample(),
    ),
  );
}

class CupertinoSheetExample extends StatelessWidget {
  const CupertinoSheetExample({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Sheet'),
            leading: CupertinoButton(
              child: Text("Close"),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SliverSafeArea(
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: CupertinoTextField(
                    placeholder: 'Type something...',
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => CupertinoListTile(
                      title: Text('Item #$index'),
                    ),
                    childCount: 50,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
