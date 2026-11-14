import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

/// Content that shows how its route presents it.
class _Content extends StatelessWidget {
  const _Content({this.text = 'Content'});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        Text('as ${CoilModalRoute.presentationOf(context)?.name}'),
        GestureDetector(
          onTap: () => Navigator.pop(context, 'done'),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

/// Pushes [route] and records its result.
class _Pusher extends StatelessWidget {
  const _Pusher({required this.route, required this.results});

  final Route<String> Function(BuildContext context) route;
  final List<Object?> results;

  @override
  Widget build(BuildContext context) => Center(
    child: GestureDetector(
      onTap: () async =>
          results.add(await Navigator.of(context).push(route(context))),
      child: const Text('Open'),
    ),
  );
}

/// A Router app whose navigator shows [modal] above the home page while
/// `open` is true; system back reaches it through the router.
class _PagesApp extends StatefulWidget {
  const _PagesApp({required this.modal, this.tier = CoilTier.pointer});

  final Page<Object?> Function() modal;
  final CoilTier tier;

  @override
  State<_PagesApp> createState() => _PagesAppState();
}

class _PagesAppState extends State<_PagesApp> {
  late final _delegate = _Delegate(this);

  bool open = false;
  int removed = 0;

  void show() => setState(() => open = true);

  @override
  void didUpdateWidget(_PagesApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _delegate.refresh();
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _delegate.refresh();
  }

  @override
  void dispose() {
    _delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WidgetsApp.router(
    color: const Color(0xFF000000),
    routerConfig: RouterConfig(
      routerDelegate: _delegate,
      backButtonDispatcher: RootBackButtonDispatcher(),
    ),
    builder: (context, router) => CoilAdaptiveScope(
      tier: widget.tier,
      child: CoilTheme(data: CoilThemeData.light, child: router!),
    ),
  );
}

class _Delegate extends RouterDelegate<Object>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  _Delegate(this.app);

  final _PagesAppState app;

  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  void refresh() => notifyListeners();

  @override
  Future<void> setNewRoutePath(Object configuration) async {}

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    pages: [
      const _HomePage(),
      if (app.open) app.widget.modal(),
    ],
    onDidRemovePage: (page) => app.setState(() {
      app.removed++;
      app.open = false;
    }),
  );
}

class _HomePage extends Page<void> {
  const _HomePage() : super(key: const ValueKey('home'));

  @override
  Route<void> createRoute(BuildContext context) => PageRouteBuilder<void>(
    settings: this,
    pageBuilder: (context, _, _) => const SizedBox.expand(),
  );
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Future<void> _tapScrim(WidgetTester tester) async {
  await tester.tapAt(const Offset(4, 4));
  await tester.pumpAndSettle();
}

void main() {
  group('pushed directly', () {
    Future<List<Object?>> open(
      WidgetTester tester, {
      CoilModalPresentation? presentation = CoilModalPresentation.centered,
      bool dismissible = true,
      CoilTier tier = CoilTier.pointer,
    }) async {
      final results = <Object?>[];
      await tester.pumpWidget(
        testApp(
          tier: tier,
          home: _Pusher(
            results: results,
            route: (context) => CoilModalRoute<String>(
              context: context,
              presentation: presentation,
              dismissible: dismissible,
              builder: (context) => const _Content(),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsOneWidget);
      return results;
    }

    for (final presentation in CoilModalPresentation.values) {
      testWidgets('${presentation.name}: returns the popped value', (
        tester,
      ) async {
        useScreen(tester, TestScreen.desktop);
        final results = await open(tester, presentation: presentation);
        expect(find.text('as ${presentation.name}'), findsOneWidget);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.text('Content'), findsNothing);
        expect(results, ['done']);
      });

      testWidgets('${presentation.name}: the scrim and back close it', (
        tester,
      ) async {
        useScreen(tester, TestScreen.desktop);
        final results = await open(tester, presentation: presentation);
        await _tapScrim(tester);
        expect(find.text('Content'), findsNothing);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await _back(tester);
        expect(find.text('Content'), findsNothing);
        expect(results, [null, null]);
      });

      testWidgets('${presentation.name}: not dismissible, nothing closes it', (
        tester,
      ) async {
        useScreen(tester, TestScreen.desktop);
        await open(tester, presentation: presentation, dismissible: false);
        await _tapScrim(tester);
        await _back(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Content'), findsOneWidget);
      });
    }

    testWidgets('Escape closes a centered modal', (tester) async {
      useScreen(tester, TestScreen.desktop);
      final results = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsNothing);
      expect(results, [null]);
    });

    testWidgets('with no presentation, a phone gets a sheet', (tester) async {
      useScreen(tester, TestScreen.phone);
      await open(tester, presentation: null, tier: CoilTier.touch);
      expect(find.text('as sheet'), findsOneWidget);
    });

    testWidgets('with no presentation, a desktop gets it centered', (
      tester,
    ) async {
      useScreen(tester, TestScreen.desktop);
      await open(tester, presentation: null);
      expect(find.text('as centered'), findsOneWidget);
    });
  });

  group('as a page in Navigator.pages', () {
    Future<_PagesAppState> open(
      WidgetTester tester,
      Page<Object?> Function() modal, {
      CoilTier tier = CoilTier.pointer,
    }) async {
      await tester.pumpWidget(_PagesApp(modal: modal, tier: tier));
      final app = tester.state<_PagesAppState>(find.byType(_PagesApp))..show();
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsOneWidget);
      return app;
    }

    for (final presentation in CoilModalPresentation.values) {
      testWidgets('${presentation.name}: the scrim, back and pop remove it', (
        tester,
      ) async {
        useScreen(tester, TestScreen.desktop);
        CoilModalPage<String> page() => CoilModalPage<String>(
          key: const ValueKey('modal'),
          presentation: presentation,
          child: const _Content(),
        );
        final app = await open(tester, page);
        expect(find.text('as ${presentation.name}'), findsOneWidget);
        await _tapScrim(tester);
        expect(find.text('Content'), findsNothing);
        expect(app.removed, 1);

        await open(tester, page);
        await _back(tester);
        expect(find.text('Content'), findsNothing);
        expect(app.removed, 2);

        await open(tester, page);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.text('Content'), findsNothing);
        expect(app.removed, 3);
      });
    }

    testWidgets('not dismissible, the scrim and back leave it open', (
      tester,
    ) async {
      useScreen(tester, TestScreen.desktop);
      final app = await open(
        tester,
        () => const CoilModalPage<void>(
          dismissible: false,
          child: _Content(),
        ),
      );
      await _tapScrim(tester);
      await _back(tester);
      expect(find.text('Content'), findsOneWidget);
      expect(app.removed, 0);
    });

    testWidgets('with no presentation, a phone gets a sheet', (tester) async {
      useScreen(tester, TestScreen.phone);
      await open(
        tester,
        () => const CoilModalPage<void>(child: _Content()),
        tier: CoilTier.touch,
      );
      expect(find.text('as sheet'), findsOneWidget);
    });

    testWidgets('an updated page updates the open modal', (tester) async {
      useScreen(tester, TestScreen.desktop);
      var text = 'Content';
      final app = await open(
        tester,
        () => CoilModalPage<void>(
          key: const ValueKey('modal'),
          child: _Content(text: text),
        ),
      );
      text = 'Updated';
      app.show();
      await tester.pumpAndSettle();
      expect(find.text('Updated'), findsOneWidget);
    });
  });

  group('each show function and its route look the same', () {
    Widget dialog(BuildContext context) => CoilDialog(
      title: const Text('Rename'),
      actions: [
        CoilButton(
          variant: CoilButtonVariant.secondary,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        CoilButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Save'),
        ),
      ],
      child: const SizedBox(height: 40),
    );

    final sections = [
      CoilSettingsSection<int>(
        value: 0,
        label: const Text('General'),
        builder: (context) => const Text('General panel'),
      ),
    ];

    final entries = [
      CoilAction(
        label: const Text('Go to inbox'),
        searchText: 'Go to inbox',
        onPressed: () {},
      ),
    ];

    /// The rects of [texts] once [show] has opened, then closes it.
    Future<List<Rect>> layout(
      WidgetTester tester,
      TestScreen screen,
      List<String> texts,
      Future<void> Function(BuildContext context) show,
    ) async {
      await tester.pumpWidget(
        testApp(
          tier: screen.tier,
          home: Builder(
            builder: (context) => Center(
              child: GestureDetector(
                onTap: () => show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final rects = [for (final text in texts) tester.getRect(find.text(text))];
      await _back(tester);
      expect(find.text(texts.first), findsNothing);
      return rects;
    }

    for (final screen in TestScreen.values) {
      testWidgets('a form dialog on a ${screen.name}', (tester) async {
        useScreen(tester, screen);
        const texts = ['Rename', 'Cancel', 'Save'];
        expect(
          await layout(
            tester,
            screen,
            texts,
            (context) => Navigator.of(context).push(
              CoilModalRoute<void>(
                context: context,
                presentation: CoilDialogKind.form.presentation,
                builder: dialog,
              ),
            ),
          ),
          await layout(
            tester,
            screen,
            texts,
            (context) => showCoilDialog<void>(
              context: context,
              kind: CoilDialogKind.form,
              builder: dialog,
            ),
          ),
        );
      });

      testWidgets('a settings dialog on a ${screen.name}', (tester) async {
        useScreen(tester, screen);
        const texts = ['Settings', 'General panel'];
        expect(
          await layout(
            tester,
            screen,
            texts,
            (context) => Navigator.of(context).push(
              CoilModalRoute<void>(
                context: context,
                presentation: CoilDialogKind.form.presentation,
                builder: (context) => CoilSettingsDialog<int>(
                  title: const Text('Settings'),
                  sections: sections,
                  onClose: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          await layout(
            tester,
            screen,
            texts,
            (context) => showCoilSettingsDialog<int>(
              context: context,
              title: const Text('Settings'),
              sections: sections,
            ),
          ),
        );
      });

      testWidgets('a command menu on a ${screen.name}', (tester) async {
        useScreen(tester, screen);
        const texts = ['Go to inbox', 'Type a command or search…'];
        expect(
          await layout(
            tester,
            screen,
            texts,
            (context) => Navigator.of(context).push(
              CoilModalRoute<void>(
                context: context,
                builder: (context) => CoilCommandMenu(entries: entries),
              ),
            ),
          ),
          await layout(
            tester,
            screen,
            texts,
            (context) =>
                showCoilCommandMenu(context: context, entries: entries),
          ),
        );
      });
    }
  });
}
