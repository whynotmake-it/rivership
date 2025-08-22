import 'package:flutter/cupertino.dart';
import 'package:heroine/heroine.dart';
import 'package:heroine_example/main.dart';
import 'package:pull_down_button/pull_down_button.dart';

class MainSettingsButton extends StatelessWidget {
  const MainSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final fadeThroughShuttle = FadeThroughShuttleBuilder(
      fadeColor: CupertinoColors.extraLightBackgroundGray,
    );

    final chained = ChainedShuttleBuilder(builders: [
      FlipShuttleBuilder(),
      fadeThroughShuttle,
      FadeShuttleBuilder(),
    ]);
    return PullDownButton(
      itemBuilder: (context) => [
        PullDownMenuTitle(title: Text('Select Spring')),
        PullDownMenuItem.selectable(
          onTap: () => springNotifier.value = CupertinoMotion.bouncy(),
          title: 'Bouncy',
          selected: springNotifier.value == CupertinoMotion.bouncy(),
        ),
        PullDownMenuItem.selectable(
          onTap: () => springNotifier.value = CupertinoMotion.snappy(),
          title: 'Snappy',
          selected: springNotifier.value == CupertinoMotion.snappy(),
        ),
        PullDownMenuItem.selectable(
          onTap: () => springNotifier.value = CupertinoMotion.smooth(),
          title: 'Smooth',
          selected: springNotifier.value == CupertinoMotion.smooth(),
        ),
        PullDownMenuItem.selectable(
          onTap: () => springNotifier.value = CupertinoMotion.interactive(),
          title: 'Interactive',
          subtitle: 'Too fast - janky',
          icon: CupertinoIcons.exclamationmark_triangle,
          selected: springNotifier.value == CupertinoMotion.interactive(),
        ),
        PullDownMenuTitle(title: Text('Flight Shuttle Animation')),
        PullDownMenuItem.selectable(
          onTap: () => flightShuttleNotifier.value = const FlipShuttleBuilder(),
          title: 'Flip',
          selected: flightShuttleNotifier.value == const FlipShuttleBuilder(),
        ),
        PullDownMenuItem.selectable(
          onTap: () => flightShuttleNotifier.value = const FadeShuttleBuilder(),
          title: 'Fade',
          selected: flightShuttleNotifier.value == const FadeShuttleBuilder(),
        ),
        PullDownMenuItem.selectable(
          onTap: () => flightShuttleNotifier.value = fadeThroughShuttle,
          title: 'Fade through',
          selected: flightShuttleNotifier.value == fadeThroughShuttle,
        ),
        PullDownMenuItem.selectable(
          onTap: () => flightShuttleNotifier.value = chained,
          title: 'Flip + Fade through + Fade',
          selected: flightShuttleNotifier.value == chained,
        ),
        PullDownMenuItem.selectable(
          onTap: () =>
              flightShuttleNotifier.value = const SingleShuttleBuilder(),
          title: 'Standard Flutter Hero',
          selected: flightShuttleNotifier.value == const SingleShuttleBuilder(),
        ),
        PullDownMenuTitle(title: Text('Timing')),
        PullDownMenuItem.selectable(
          onTap: () => adjustSpringTimingToRoute.value =
              !adjustSpringTimingToRoute.value,
          title: 'Adjust Spring Timing to Route',
          selected: adjustSpringTimingToRoute.value,
        ),
      ],
      buttonBuilder: (context, showMenu) => CupertinoButton(
        onPressed: showMenu,
        padding: EdgeInsets.zero,
        child: const Icon(CupertinoIcons.settings),
      ),
    );
  }
}

class DetailsPageSettingsButton extends StatelessWidget {
  const DetailsPageSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PullDownButton(
      itemBuilder: (context) => [
        PullDownMenuTitle(title: Text('Aspect Ratio')),
        PullDownMenuActionsRow.medium(
          items: [
            PullDownMenuItem.selectable(
              icon: CupertinoIcons.square,
              onTap: () => detailsPageAspectRatio.value = 1.0,
              title: '1:1',
              selected: detailsPageAspectRatio.value == 1.0,
            ),
            PullDownMenuItem.selectable(
              icon: CupertinoIcons.rectangle,
              onTap: () => detailsPageAspectRatio.value = 1.5,
              title: '1.5:1',
              selected: detailsPageAspectRatio.value == 1.5,
            ),
          ],
        ),
      ],
      buttonBuilder: (context, showMenu) => CupertinoButton(
        child: const Icon(CupertinoIcons.photo),
        onPressed: showMenu,
      ),
    );
  }
}
