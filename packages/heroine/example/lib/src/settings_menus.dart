import 'package:heroine_example/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:heroine/heroine.dart';

class MainSettingsButton extends StatelessWidget {
  const MainSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PullDownButton(
      itemBuilder: (context) => [
        PullDownMenuTitle(title: Text('Select Spring')),
        PullDownMenuItem.selectable(
          onTap: () => springNotifier.value = SimpleSpring.bouncy,
          title: 'Bouncy',
          selected: springNotifier.value == SimpleSpring.bouncy,
        ),
        PullDownMenuItem.selectable(
          onTap: () => springNotifier.value = SimpleSpring.snappy,
          title: 'Snappy',
          selected: springNotifier.value == SimpleSpring.snappy,
        ),
        PullDownMenuItem.selectable(
          onTap: () => springNotifier.value = SimpleSpring.defaultIOS,
          title: 'Default iOS',
          selected: springNotifier.value == SimpleSpring.defaultIOS,
        ),
        PullDownMenuItem.selectable(
          onTap: () => springNotifier.value = const SimpleSpring(),
          title: 'Smooth',
          selected: springNotifier.value == const SimpleSpring(),
        ),
        PullDownMenuItem.selectable(
          onTap: () => springNotifier.value = SimpleSpring.interactive,
          title: 'Interactive',
          subtitle: 'Too fast - janky',
          icon: CupertinoIcons.exclamationmark_triangle,
          selected: springNotifier.value == SimpleSpring.interactive,
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
