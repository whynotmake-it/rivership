import 'dart:typed_data';

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

        await loadAppFonts();

        await tester.pump();
      });
    });

    group('precacheImages', () {
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

        await precacheImages();

        await tester.pump();
      });
    });
  });
}
