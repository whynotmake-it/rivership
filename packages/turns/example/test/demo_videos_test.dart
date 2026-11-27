import 'dart:io';

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';
import 'package:turns_example/src/demos/ai_assistant_demo.dart';
import 'package:turns_example/src/demos/slack_demo.dart';
import 'package:turns_example/src/demos/whatsapp_demo.dart';

/// Video recordings are gated behind `RECORD_VIDEOS=1` so normal `melos test`
/// stays fast. Run:
///
/// ```sh
/// RECORD_VIDEOS=1 flutter test test/demo_videos_test.dart
/// ```
final bool _recordVideos = Platform.environment['RECORD_VIDEOS'] == '1';

const _videoSettings = SnapVideoSettings(
  frameRate: 30,
  timing: VideoTiming.smooth,
  encoding: VideoEncoding.h264(crf: 18),
  includeDeviceFrame: true,
  renderShadows: true,
  overlay: SnapPointerOverlay.builder,
  minimumPointerDuration: Duration(milliseconds: 160),
  finalHold: Duration(milliseconds: 600),
  pathPrefix: '.snaptest/recordings',
);

Widget _buildPhoneDemoHost({
  required Widget child,
  required bool padSafeArea,
}) {
  final baseTheme = CoilThemeData.light.copyWith(
    typography: CoilTypography.allo(),
  );

  return WidgetsApp(
    color: baseTheme.colors.brand,
    debugShowCheckedModeBanner: false,
    pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, _, _) => builder(context),
    ),
    home: CoilTheme(
      data: baseTheme,
      child: CoilAdaptiveScope(
        tier: CoilTier.touch,
        child: Builder(
          builder: (context) {
            final colors = CoilTheme.of(context).colors;
            final text = CoilTheme.textOf(context);
            var body = child;
            if (padSafeArea) {
              final padding = MediaQuery.paddingOf(context);
              body = Column(
                children: [
                  ColoredBox(
                    color: colors.surfaces[1],
                    child: SizedBox(
                      height: padding.top,
                      width: double.infinity,
                    ),
                  ),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      removeBottom: true,
                      child: child,
                    ),
                  ),
                  ColoredBox(
                    color: colors.background,
                    child: SizedBox(
                      height: padding.bottom,
                      width: double.infinity,
                    ),
                  ),
                ],
              );
            }
            return ColoredBox(
              color: colors.background,
              child: DefaultTextStyle(style: text.body, child: body),
            );
          },
        ),
      ),
    ),
  );
}

/// Advances fake time in small increments so Motor springs, timers, and
/// streaming tokens animate smoothly at the recording frame rate.
Future<void> _pumpSmooth(
  WidgetTester tester,
  Duration total, {
  Duration step = const Duration(milliseconds: 33),
}) async {
  var remaining = total;
  while (remaining > Duration.zero) {
    final slice = remaining < step ? remaining : step;
    await tester.pump(slice);
    remaining -= slice;
  }
}

/// Taps [finder] with a realistic touch-down hold so [SnapPointerOverlay]
/// renders a clear touch indicator.
Future<void> _smoothTap(WidgetTester tester, Finder finder) async {
  final center = tester.getCenter(finder);
  final gesture = await tester.startGesture(center);
  await tester.pump(const Duration(milliseconds: 90));
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Drags incrementally with an ease-in-out profile at 16ms intervals so
/// `snap.recordVideo` captures smooth finger motion rather than a 1-frame jump.
Future<void> _smoothDrag(
  WidgetTester tester, {
  required Offset start,
  required Offset totalDelta,
  int steps = 28,
  Duration stepDuration = const Duration(milliseconds: 16),
  Duration holdBeforeRelease = const Duration(milliseconds: 48),
}) async {
  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 32));
  var previousFraction = 0.0;
  for (var i = 1; i <= steps; i++) {
    final eased = Curves.easeInOutCubic.transform(i / steps);
    final deltaFraction = eased - previousFraction;
    previousFraction = eased;
    await gesture.moveBy(totalDelta * deltaFraction);
    await tester.pump(stepDuration);
  }
  if (holdBeforeRelease > Duration.zero) {
    await tester.pump(holdBeforeRelease);
  }
  await gesture.up();
  await tester.pump(stepDuration);
}

void main() {
  snapTest(
    'record ai_turn_pin video',
    devices: {Devices.ios.iPhone16Pro},
    skip: !_recordVideos,
    timeout: const Timeout(Duration(minutes: 4)),
    (tester) async {
      await tester.pumpWidget(
        _buildPhoneDemoHost(
          padSafeArea: true,
          child: const AiAssistantDemo(),
        ),
      );
      await _pumpSmooth(tester, const Duration(milliseconds: 500));

      final recording = await snap.recordVideo(
        name: 'ai_turn_pin',
        settings: _videoSettings,
      );

      // Pause briefly on initial transcript.
      await _pumpSmooth(tester, const Duration(milliseconds: 350));

      // Trigger deep-dive GFM stream -> prompt spring-pins to top with
      // SliverTurnStage reservation while thinking steps + markdown stream.
      await _smoothTap(tester, find.byKey(const Key('ai.quick_long')));
      await _pumpSmooth(tester, const Duration(milliseconds: 3000));

      // Mid-stream finger drag upward (zero-fight disengagement!).
      await _smoothDrag(
        tester,
        start: const Offset(200, 320),
        totalDelta: const Offset(0, 320),
        steps: 26,
      );
      await _pumpSmooth(tester, const Duration(milliseconds: 650));

      // Jump back to the streaming reply at the bottom.
      final jumpBottom = find.byKey(const Key('ai.jump_bottom'));
      expect(jumpBottom, findsOneWidget);
      await _smoothTap(tester, jumpBottom);
      await _pumpSmooth(tester, const Duration(milliseconds: 1600));

      final mp4 = await recording.stop();
      expect(mp4.existsSync(), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  snapTest(
    'record whatsapp_sections video',
    devices: {Devices.ios.iPhone16Pro},
    skip: !_recordVideos,
    timeout: const Timeout(Duration(minutes: 4)),
    (tester) async {
      await tester.pumpWidget(
        _buildPhoneDemoHost(
          padSafeArea: false,
          child: const WhatsAppDemo(),
        ),
      );
      await _pumpSmooth(tester, const Duration(milliseconds: 600));

      final recording = await snap.recordVideo(
        name: 'whatsapp_sections',
        settings: _videoSettings,
      );

      await _pumpSmooth(tester, const Duration(milliseconds: 350));

      // Smooth drag upward through Today -> Yesterday -> May 12 watching
      // floating date pills push each other cleanly at the top edge.
      await _smoothDrag(
        tester,
        start: const Offset(200, 300),
        totalDelta: const Offset(0, 380),
        steps: 30,
      );
      await _pumpSmooth(tester, const Duration(milliseconds: 280));
      await _smoothDrag(
        tester,
        start: const Offset(200, 300),
        totalDelta: const Offset(0, 380),
        steps: 30,
      );
      await _pumpSmooth(tester, const Duration(milliseconds: 350));

      // Prepend older history with 0.0px shift while scrolled mid-thread.
      await _smoothTap(tester, find.byKey(const Key('whatsapp.load_older')));
      await _pumpSmooth(tester, const Duration(milliseconds: 600));

      // Spring back to Today so the quoted reply card is in view.
      await _smoothTap(tester, find.byKey(const Key('whatsapp.jump_bottom')));
      await _pumpSmooth(tester, const Duration(milliseconds: 850));

      // Tap quoted reply card -> springs smoothly to offscreen May 12 target
      // with Motor highlight glow.
      final quoteCard = find.byKey(const Key('whatsapp.quote_jump'));
      expect(quoteCard, findsOneWidget);
      await _smoothTap(tester, quoteCard);
      await _pumpSmooth(tester, const Duration(milliseconds: 1050));

      // Spring back to bottom.
      await _smoothTap(tester, find.byKey(const Key('whatsapp.jump_bottom')));
      await _pumpSmooth(tester, const Duration(milliseconds: 900));

      final mp4 = await recording.stop();
      expect(mp4.existsSync(), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  snapTest(
    'record slack_sections video',
    devices: {Devices.ios.iPhone16Pro},
    skip: !_recordVideos,
    timeout: const Timeout(Duration(minutes: 4)),
    (tester) async {
      await tester.pumpWidget(
        _buildPhoneDemoHost(
          padSafeArea: false,
          child: const SlackDemo(),
        ),
      );
      await _pumpSmooth(tester, const Duration(milliseconds: 600));

      final recording = await snap.recordVideo(
        name: 'slack_sections',
        settings: _videoSettings,
      );

      // Pause briefly showing bookmarks, transparent pinned Today date pill,
      // and Slack's floating "10 new messages" top pill over a 3,000-msg feed.
      await _pumpSmooth(tester, const Duration(milliseconds: 450));

      // Tap Slack's floating "10 new messages" pill -> springs to the
      // offscreen first-unread message with the red "New" divider line clearly
      // visible right above it.
      final unreadPill = find.byKey(const Key('slack.unread_pill'));
      expect(unreadPill, findsOneWidget);
      await _smoothTap(tester, unreadPill);
      await _pumpSmooth(tester, const Duration(milliseconds: 1150));

      // Jump across day sections to RFC #42 on May 13.
      await _smoothTap(tester, find.byKey(const Key('slack.jump_rfc')));
      await _pumpSmooth(tester, const Duration(milliseconds: 1200));

      // Smooth upward drag across messages watching the transparent floating
      // day pill hover cleanly over scrolled content.
      await _smoothDrag(
        tester,
        start: const Offset(200, 330),
        totalDelta: const Offset(0, -240),
        steps: 22,
      );
      await _pumpSmooth(tester, const Duration(milliseconds: 400));

      final jumpBottom = find.byKey(const Key('slack.jump_bottom'));
      expect(jumpBottom, findsOneWidget);
      await _smoothTap(tester, jumpBottom);
      await _pumpSmooth(tester, const Duration(milliseconds: 950));

      final mp4 = await recording.stop();
      expect(mp4.existsSync(), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
