import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapper/snapper.dart';

void main() {
  group('FakeDevice', () {
    group('WidgetTesterDevice', () {
      test('throws UnsupportedError when accessing properties', () {
        const device = WidgetTesterDevice();

        expect(() => device.name, throwsUnsupportedError);
        expect(() => device.screenSize, throwsUnsupportedError);
        expect(() => device.pixelRatio, throwsUnsupportedError);
        expect(() => device.safeAreas, throwsUnsupportedError);
      });

      test('can be instantiated', () {
        expect(() => const WidgetTesterDevice(), returnsNormally);
      });
    });

    group('enableRealRenderingForTest', () {
      testWidgets('enables real rendering without errors', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Real Rendering Test'),
              ),
            ),
          ),
        );

        expect(enableRealRenderingForTest, returnsNormally);
        await enableRealRenderingForTest();

        // Pump to ensure rendering takes effect
        await tester.pump();
      });
    });

    group('loadAppFonts', () {
      testWidgets('loads fonts without errors', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text(
                  'Font Loading Test',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(loadAppFonts, returnsNormally);
        await loadAppFonts();

        await tester.pump();
      });
    });

    group('precacheImages', () {
      testWidgets('precaches images without errors', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Image.asset(
                    'assets/test_image.png',
                    width: 100,
                    height: 100,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey,
                        child: const Icon(Icons.error),
                      );
                    },
                  ),
                  const FlutterLogo(size: 50),
                ],
              ),
            ),
          ),
        );

        expect(precacheImages, returnsNormally);
        await precacheImages();

        await tester.pump();
      });

      testWidgets('precaches images from specific finder', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Container(
                    key: const Key('image-container'),
                    child: Image.asset(
                      'assets/test_image.png',
                      width: 100,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 100,
                          color: Colors.blue,
                          child: const Icon(Icons.image),
                        );
                      },
                    ),
                  ),
                  const FlutterLogo(size: 50),
                ],
              ),
            ),
          ),
        );

        final finder = find.byKey(const Key('image-container'));

        expect(() => precacheImages(finder), returnsNormally);
        await precacheImages(finder);

        await tester.pump();
      });

      testWidgets('handles empty image list', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('No Images Here'),
              ),
            ),
          ),
        );

        expect(precacheImages, returnsNormally);
        await precacheImages();

        await tester.pump();
      });
    });
  });
}
