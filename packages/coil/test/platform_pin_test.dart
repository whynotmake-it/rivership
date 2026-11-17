// A subtree pinned to another platform (a phone preview in a desktop
// window) follows that platform's conventions without touching the rest of
// the app.
import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the nearest pin wins; without one, the real platform', (
    tester,
  ) async {
    late BuildContext outer;
    late BuildContext inner;
    late BuildContext nested;
    await tester.pumpWidget(
      CoilTheme(
        data: CoilThemeData.light,
        child: Builder(
          builder: (context) {
            outer = context;
            return CoilAdaptiveScope(
              platform: TargetPlatform.iOS,
              child: Builder(
                builder: (context) {
                  inner = context;
                  // A scope that pins something else keeps the platform.
                  return CoilAdaptiveScope(
                    size: CoilSize.compact,
                    child: Builder(
                      builder: (context) {
                        nested = context;
                        return const SizedBox();
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );

    expect(CoilTheme.platformOf(outer), defaultTargetPlatform);
    expect(CoilTheme.platformOf(inner), TargetPlatform.iOS);
    expect(CoilTheme.platformOf(nested), TargetPlatform.iOS);
  });

  testWidgets('a pinned platform latches the tier', (tester) async {
    late BuildContext phone;
    late BuildContext desktop;
    await tester.pumpWidget(
      CoilTheme(
        data: CoilThemeData.light,
        child: Column(
          children: [
            CoilAdaptiveScope(
              platform: TargetPlatform.android,
              child: Builder(
                builder: (context) {
                  phone = context;
                  return const SizedBox();
                },
              ),
            ),
            CoilAdaptiveScope(
              platform: TargetPlatform.macOS,
              child: Builder(
                builder: (context) {
                  desktop = context;
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );

    expect(CoilTheme.tierOf(phone), CoilTier.touch);
    expect(CoilTheme.tierOf(desktop), CoilTier.pointer);
  });

  testWidgets("the sidebar's drawer takes the pinned platform's corners", (
    tester,
  ) async {
    Future<BorderRadius?> fallbackCorner(TargetPlatform platform) async {
      late BuildContext context;
      await tester.pumpWidget(
        CoilTheme(
          data: CoilThemeData.light,
          child: CoilAdaptiveScope(
            platform: platform,
            child: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return CoilSidebarStyle.fallback(
        CoilTheme.of(context),
        CoilTheme.metricsOf(context),
        platform: CoilTheme.platformOf(context),
      ).drawerFallbackCornerRadius;
    }

    expect(
      await fallbackCorner(TargetPlatform.iOS),
      CoilDrawerLook.fallbackCornerRadiusFor(TargetPlatform.iOS),
    );
    expect(
      await fallbackCorner(TargetPlatform.android),
      CoilDrawerLook.fallbackCornerRadiusFor(TargetPlatform.android),
    );
  });

  testWidgets('shortcut modifiers follow the pinned platform', (
    tester,
  ) async {
    // The sidebar's toggle key is ⌘B on Apple platforms and Ctrl+B elsewhere.
    Future<bool> toggledBy({
      required TargetPlatform platform,
      required bool meta,
    }) async {
      final controller = CoilSidebarController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => CoilTheme(
            data: CoilThemeData.light,
            child: CoilAdaptiveScope(
              platform: platform,
              tier: CoilTier.pointer,
              child: CoilSidebarScaffold(
                controller: controller,
                sidebar: const CoilSidebar(children: []),
                body: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = controller.open;
      await tester.sendKeyDownEvent(
        meta ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(
        meta ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
      );
      await tester.pumpAndSettle();
      return controller.open != before;
    }

    expect(await toggledBy(platform: TargetPlatform.macOS, meta: true), isTrue);
    expect(
      await toggledBy(platform: TargetPlatform.macOS, meta: false),
      isFalse,
    );
    expect(
      await toggledBy(platform: TargetPlatform.windows, meta: false),
      isTrue,
    );
  });
}
