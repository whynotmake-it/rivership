import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

/// A share-sheet style example that uses [DismissalMode.shrink] so the sheet
/// collapses from the top while keeping footer buttons pinned at the bottom.
/// Combined with snap points at 50% and 100%, this creates a two-stop sheet
/// with a persistent footer that stays visible even when the sheet is half-open.
///
/// See also: [DismissalMode.shrink], [SheetSnappingConfig]
void showShrinkSheet(BuildContext context) {
  Navigator.of(context).push(
    StupidSimpleGlassSheetRoute(
      snappingConfig: SheetSnappingConfig([0.5, 1]),
      backgroundSnapshotMode: RouteSnapshotMode.openAndForward,
      dismissalMode: DismissalMode.shrink,
      child: const ShrinkSheetExample(),
    ),
  );
}

class ShrinkSheetExample extends StatelessWidget {
  const ShrinkSheetExample({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey3.resolveFrom(context),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Share with...',
              style: textTheme.navTitleTextStyle,
            ),
          ),

          // Scrollable contact list
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final contact = _contacts[index];
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: contact.color,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    contact.initials,
                                    style: textTheme.textStyle.copyWith(
                                      color: CupertinoColors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contact.name,
                                      style: textTheme.textStyle,
                                    ),
                                    Text(
                                      contact.subtitle,
                                      style:
                                          textTheme.tabLabelTextStyle.copyWith(
                                        color: CupertinoColors.secondaryLabel
                                            .resolveFrom(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: _contacts.length,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sticky footer — stays visible during shrink dismissal
          Divider(
            color: CupertinoColors.opaqueSeparator.resolveFrom(context),
            height: 1,
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Text(
                      'Copy Link',
                      style: textTheme.textStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton.filled(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    borderRadius: BorderRadius.circular(12),
                    child: Text(
                      'Send',
                      style: textTheme.textStyle.copyWith(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
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

class _Contact {
  const _Contact(this.name, this.subtitle, this.initials, this.color);
  final String name;
  final String subtitle;
  final String initials;
  final Color color;
}

const _contacts = [
  _Contact('Alice Martin', 'Last seen 2m ago', 'AM', Color(0xFF5856D6)),
  _Contact('Bob Chen', 'Online', 'BC', Color(0xFF34C759)),
  _Contact('Carol Davis', 'Last seen 1h ago', 'CD', Color(0xFFFF9500)),
  _Contact('David Kim', 'Online', 'DK', Color(0xFFFF2D55)),
  _Contact('Eva Rodriguez', 'Last seen 3h ago', 'ER', Color(0xFF007AFF)),
  _Contact("Frank O'Brien", 'Last seen yesterday', 'FO', Color(0xFFAF52DE)),
  _Contact('Grace Lee', 'Online', 'GL', Color(0xFF30B0C7)),
  _Contact('Henry Patel', 'Last seen 30m ago', 'HP', Color(0xFFFF3B30)),
  _Contact('Iris Wang', 'Online', 'IW', Color(0xFF5AC8FA)),
  _Contact('James Taylor', 'Last seen 5m ago', 'JT', Color(0xFFFFCC00)),
  _Contact('Karen Nguyen', 'Last seen 2h ago', 'KN', Color(0xFF4CD964)),
  _Contact('Liam Brown', 'Online', 'LB', Color(0xFF5856D6)),
];
