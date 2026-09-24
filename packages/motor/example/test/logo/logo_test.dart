import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor_example/widgets/style.dart';
import 'package:snaptest/snaptest.dart';

import 'logo_options.dart';

/// Renders every logo option in light and dark to `build/logo/`, plus one
/// comparison sheet.
void main() {
  const key = ValueKey('logo');
  const palettes = [Palette.light, Palette.dark];
  final out = Directory('build/logo')..createSync(recursive: true);

  Future<void> render(WidgetTester tester, String name, Widget child) async {
    tester.view
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Center(
          child: RepaintBoundary(key: key, child: child),
        ),
      ),
    );
    final [file] = await snap(name: name, from: find.byKey(key));
    file
      ..copySync('${out.path}/$name.png')
      ..deleteSync();
  }

  for (final (index, option) in logoOptions.indexed) {
    final name = '${index + 1}-${option.name}';
    testWidgets('render logo option $name', (tester) async {
      await render(
        tester,
        name,
        Row(
          mainAxisSize: .min,
          children: [
            for (final palette in palettes)
              ColoredBox(
                color: palette.canvas,
                child: Padding(
                  padding: const .all(48),
                  child: LogoTile(option: option, palette: palette),
                ),
              ),
          ],
        ),
      );
    });
  }

  testWidgets('render logo comparison sheet', (tester) async {
    await render(
      tester,
      'comparison',
      Column(
        mainAxisSize: .min,
        children: [
          for (final palette in palettes)
            ColoredBox(
              color: palette.canvas,
              child: Padding(
                padding: const .symmetric(horizontal: 32, vertical: 40),
                child: Row(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    for (final (index, option) in logoOptions.indexed)
                      _SheetColumn(
                        index: index,
                        option: option,
                        palette: palette,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  });
}

class _SheetColumn extends StatelessWidget {
  const _SheetColumn({
    required this.index,
    required this.option,
    required this.palette,
  });

  final int index;
  final LogoOption option;
  final Palette palette;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 232,
    child: Column(
      children: [
        LogoTile(option: option, palette: palette, size: 160),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: .center,
          crossAxisAlignment: .end,
          spacing: 16,
          children: [
            for (final size in [56.0, 32.0, 20.0])
              LogoTile(option: option, palette: palette, size: size),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          '${index + 1}  ${option.name}',
          style: mono(13, weight: 500, color: palette.text),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 190,
          child: Text(
            option.description,
            textAlign: .center,
            style: palette.caption,
          ),
        ),
      ],
    ),
  );
}
