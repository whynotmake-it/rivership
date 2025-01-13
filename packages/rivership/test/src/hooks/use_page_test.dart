// ignore_for_file: prefer_int_literals

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rivership/rivership.dart';

void main() {
  group('usePage', () {
    late PageController controller;
    setUp(() {
      controller = PageController();
      addTearDown(() => controller.dispose());
    });

    Widget build({
      bool showPageView = true,
      int pages = 10,
    }) {
      return MaterialApp(
        home: HookBuilder(
          builder: (context) {
            final page = usePage(controller);
            return Stack(
              children: [
                if (showPageView)
                  PageView.builder(
                    controller: controller,
                    itemCount: pages,
                    itemBuilder: (context, index) => Container(),
                  ),
                SizedBox.expand(
                  key: ValueKey(page),
                ),
              ],
            );
          },
        ),
      );
    }

    test('is exported by package', () async {
      expect(usePage, isA<Function>());
    });

    testWidgets('returns initial page if no clients', (tester) async {
      await tester.pumpWidget(build(showPageView: false));
      expect(find.byKey(const ValueKey(0.0)), findsOneWidget);
    });

    testWidgets('returns initial page if it is a different page',
        (tester) async {
      controller.dispose();
      controller = PageController(initialPage: 1);
      await tester.pumpWidget(build(showPageView: false));
      expect(find.byKey(const ValueKey(1.0)), findsOneWidget);
    });

    testWidgets('updates when mounted', (tester) async {
      // Test page counts from 1 to 100
      for (final pages in List<int>.generate(100, (index) => index + 1)) {
        controller.dispose();
        // Set inital page too high
        controller = PageController(initialPage: pages);
        // Start by not showing the page view
        await tester.pumpWidget(
          build(showPageView: false),
        );
        expect(find.byKey(ValueKey(pages.toDouble())), findsOneWidget);
        // Now show the page view with the correct number of pages
        await tester.pumpWidget(build(pages: pages));
        await tester.pumpAndSettle();
        // The controller should reduce the page by one to match the page view
        expect(controller.page, pages - 1);

        // The page view should show the correct page
        expect(find.byKey(ValueKey(pages.toDouble() - 1)), findsOneWidget);
      }
    });

    testWidgets('returns the current page', (tester) async {
      await tester.pumpWidget(build());
      controller.jumpToPage(1);
      await tester.pump();
      expect(find.byKey(const ValueKey(1.0)), findsOneWidget);
    });
  });

  group('usePageIndex', () {
    late PageController controller;
    setUp(() {
      controller = PageController();
      addTearDown(() => controller.dispose());
    });

    Widget build({
      bool showPageView = true,
      int pages = 10,
    }) {
      return MaterialApp(
        home: HookBuilder(
          builder: (context) {
            final page = usePageIndex(controller);
            return Stack(
              children: [
                if (showPageView)
                  PageView.builder(
                    controller: controller,
                    itemCount: pages,
                    itemBuilder: (context, index) => Container(),
                  ),
                SizedBox.expand(
                  key: ValueKey(page),
                ),
              ],
            );
          },
        ),
      );
    }

    test('is exported by package', () async {
      expect(usePageIndex, isA<Function>());
    });

    testWidgets('returns initial page if no clients', (tester) async {
      await tester.pumpWidget(build(showPageView: false));
      expect(find.byKey(const ValueKey(0)), findsOneWidget);
    });

    testWidgets('returns initial page if it is a different page',
        (tester) async {
      controller.dispose();
      controller = PageController(initialPage: 1);
      await tester.pumpWidget(build(showPageView: false));
      expect(find.byKey(const ValueKey(1)), findsOneWidget);
    });

    testWidgets('updates when mounted', (tester) async {
      // Test page counts from 1 to 1000
      for (final pages in List<int>.generate(1000, (index) => index + 1)) {
        controller.dispose();
        // Set inital page too high
        controller = PageController(initialPage: pages);
        // Start by not showing the page view
        await tester.pumpWidget(
          build(showPageView: false),
        );
        expect(find.byKey(ValueKey(pages)), findsOneWidget);
        // Now show the page view with the correct number of pages
        await tester.pumpWidget(build(pages: pages));
        await tester.pumpAndSettle();
        // The controller should reduce the page by one to match the page view
        expect(controller.page, pages - 1);

        // The page view should show the correct page
        expect(find.byKey(ValueKey(pages - 1)), findsOneWidget);
      }
    });

    testWidgets('returns the current page', (tester) async {
      await tester.pumpWidget(build());
      controller.jumpToPage(1);
      await tester.pump();
      expect(find.byKey(const ValueKey(1)), findsOneWidget);
    });
  });
}
