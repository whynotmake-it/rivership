import 'package:auto_route/auto_route.dart';
import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';
import 'package:turns_example/main.dart';
import 'package:turns_example/src/demos/ai_assistant_demo.dart';
import 'package:turns_example/src/demos/imessage_demo.dart';
import 'package:turns_example/src/demos/onboarding_demo.dart';
import 'package:turns_example/src/demos/slack_demo.dart';
import 'package:turns_example/src/demos/whatsapp_demo.dart';
import 'package:turns_example/src/shell/turns_shell.dart';

const _desktopSettings = SnaptestSettings(
  blockText: false,
  renderShadows: true,
);

const _phoneSettings = SnaptestSettings.rendered();

Widget _buildShellApp(RootStackRouter testRouter) {
  final theme = CoilThemeData.light.copyWith(typography: CoilTypography.allo());
  return WidgetsApp.router(
    title: 'turns',
    color: theme.colors.brand,
    debugShowCheckedModeBanner: false,
    routerConfig: testRouter.config(),
    builder: (context, child) => CoilTheme(
      data: theme,
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

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

Future<void> _pumpFrames(
  WidgetTester tester,
  Duration total, {
  Duration step = const Duration(milliseconds: 50),
}) async {
  var remaining = total;
  while (remaining > Duration.zero) {
    final slice = remaining < step ? remaining : step;
    await tester.pump(slice);
    remaining -= slice;
  }
}

void main() {
  snapTest(
    'turns shell desktop overview',
    settings: _desktopSettings,
    (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final testRouter = RootStackRouter.build(
        routes: [
          NamedRouteDef.shell(
            name: 'Home',
            path: '/',
            children: turnsRoutesFor(onHome: () {}),
          ),
        ],
      );
      addTearDown(testRouter.dispose);

      await tester.pumpWidget(_buildShellApp(testRouter));
      await _pumpFrames(tester, const Duration(milliseconds: 400));

      await tester.tap(find.text('Overview'));
      await _pumpFrames(tester, const Duration(milliseconds: 500));

      expect(find.text('Interactive Demos'), findsOneWidget);
      expect(find.text('Core Primitives'), findsOneWidget);

      await snap(name: 'shell_desktop_overview');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  snapTest(
    'turns shell desktop ai assistant',
    settings: _desktopSettings,
    (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final testRouter = RootStackRouter.build(
        routes: [
          NamedRouteDef.shell(
            name: 'Home',
            path: '/',
            children: turnsRoutesFor(onHome: () {}),
          ),
        ],
      );
      addTearDown(testRouter.dispose);

      await tester.pumpWidget(_buildShellApp(testRouter));
      await _pumpFrames(tester, const Duration(milliseconds: 500));

      expect(find.byKey(const Key('ai.quick_long')), findsOneWidget);
      expect(find.byType(TurnsShell), findsOneWidget);

      await snap(name: 'shell_desktop_ai');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  snapTest(
    'ai assistant iphone',
    devices: {Devices.ios.iPhone16Pro},
    settings: _phoneSettings,
    (tester) async {
      await tester.pumpWidget(
        _buildPhoneDemoHost(
          padSafeArea: true,
          child: const AiAssistantDemo(),
        ),
      );
      await _pumpFrames(tester, const Duration(milliseconds: 500));

      expect(find.byKey(const Key('ai.quick_long')), findsOneWidget);

      await snap(name: 'ai_assistant_iphone');

      // Trigger a streaming GFM turn and capture mid-stream with pinned prompt.
      await tester.tap(find.byKey(const Key('ai.quick_long')));
      await _pumpFrames(tester, const Duration(milliseconds: 2800));

      await snap(name: 'ai_assistant_streaming_iphone');

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  snapTest(
    'whatsapp iphone',
    devices: {Devices.ios.iPhone16Pro},
    settings: _phoneSettings,
    (tester) async {
      await tester.pumpWidget(
        _buildPhoneDemoHost(
          padSafeArea: false,
          child: const WhatsAppDemo(),
        ),
      );
      await _pumpFrames(tester, const Duration(milliseconds: 600));

      expect(find.byKey(const Key('whatsapp.load_older')), findsOneWidget);
      expect(find.byKey(const Key('whatsapp.quote_jump')), findsOneWidget);

      await snap(name: 'whatsapp_iphone');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  snapTest(
    'slack iphone',
    devices: {Devices.ios.iPhone16Pro},
    settings: _phoneSettings,
    (tester) async {
      await tester.pumpWidget(
        _buildPhoneDemoHost(
          padSafeArea: false,
          child: const SlackDemo(),
        ),
      );
      await _pumpFrames(tester, const Duration(milliseconds: 600));

      expect(find.byKey(const Key('slack.jump_rfc')), findsOneWidget);
      expect(find.byKey(const Key('slack.unread_pill')), findsOneWidget);

      await snap(name: 'slack_iphone');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  snapTest(
    'imessage iphone',
    devices: {Devices.ios.iPhone16Pro},
    settings: _phoneSettings,
    (tester) async {
      await tester.pumpWidget(
        _buildPhoneDemoHost(
          padSafeArea: true,
          child: const IMessageDemo(),
        ),
      );
      await _pumpFrames(tester, const Duration(milliseconds: 600));

      expect(find.byKey(const Key('imessage.load_older')), findsOneWidget);
      expect(find.byKey(const Key('imessage.jump_ref')), findsOneWidget);

      await snap(name: 'imessage_iphone');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  snapTest(
    'onboarding iphone',
    devices: {Devices.ios.iPhone16Pro},
    settings: _phoneSettings,
    (tester) async {
      await tester.pumpWidget(
        _buildPhoneDemoHost(
          padSafeArea: true,
          child: const OnboardingDemo(),
        ),
      );
      await _pumpFrames(tester, const Duration(milliseconds: 600));

      expect(find.byKey(const Key('onboarding.continue')), findsOneWidget);

      await snap(name: 'onboarding_iphone');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
