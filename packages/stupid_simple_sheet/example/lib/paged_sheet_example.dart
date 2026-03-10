import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// A sheet containing a [PageView] with horizontally pageable scroll views.
/// The sheet seamlessly coordinates between horizontal paging gestures and
/// vertical sheet dragging.
///
/// See also: [StupidSimpleCupertinoSheetRoute]
void showPagedSheet(BuildContext context) {
  Navigator.of(context).push(
    StupidSimpleCupertinoSheetRoute(
      backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
      child: const PagedSheetExample(),
    ),
  );
}

class PagedSheetExample extends StatelessWidget {
  const PagedSheetExample({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: PageView(
        children: [
          CustomScrollView(
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => CupertinoListTile(
                    title: Text('Page 1 — Item #$index'),
                  ),
                  childCount: 50,
                ),
              ),
            ],
          ),
          CustomScrollView(
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => CupertinoListTile(
                    title: Text('Page 2 — Item #$index'),
                  ),
                  childCount: 50,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
