import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_previews.dart';

/// Preview for the home page card — share sheet with contact circles and
/// pinned footer.
class ShareSheetPreview extends StatelessWidget {
  const ShareSheetPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CustomPaint(
      painter: DotGridPainter(
        dotColor: t.textTertiary.withValues(alpha: .2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            left: 40,
            right: 40,
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: t.previewMiniSurface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: t.previewMiniShadow,
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const MiniHandle(),
                  const SizedBox(height: 8),
                  // Contact circles
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 5,
                      children: [
                        for (final color in [
                          const Color(0xFF5856D6),
                          const Color(0xFF34C759),
                          const Color(0xFFFF9500),
                          const Color(0xFFFF2D55),
                        ])
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 0.5,
                    color: t.previewHandle,
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      spacing: 6,
                      children: [
                        Expanded(
                          child: Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: t.previewHandle.withValues(alpha: .3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: t.accentBlue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
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

/// A polished share-sheet example using [DismissalMode.shrink] with snap
/// points at 50% and 100%.
///
/// The sheet collapses from the top while keeping the footer buttons pinned
/// at the bottom — a pattern common in iOS share sheets.
class ShareSheetExample extends StatelessWidget {
  const ShareSheetExample({super.key});

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
              padding: const EdgeInsets.only(top: 8, bottom: 4),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final contact = _contacts[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
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
                              const SizedBox(width: 12),
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
