import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_logo.dart';

void main() {
  testWidgets('build sheet logo for README', (tester) async {
    final t = ExampleTheme.dark;
    const key = ValueKey('sheet_logo');
    // Golden test for the SheetLogo widget.
    // Verifies that the logo renders correctly and matches the expected design.
    const dpr = 4.0;
    await tester.pumpWidget(Center(
      child: RepaintBoundary(
        key: key,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Transform.rotate(
            angle: 0.05,
            child: Container(
              decoration: ShapeDecoration(
                color: t.surface,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(16 * dpr),
                  side: BorderSide(color: t.pillBorder),
                ),
                shadows: [
                  BoxShadow(
                    color: t.pillShadow,
                    blurRadius: 4 * dpr,
                    offset: Offset(0, 2 * dpr),
                  ),
                ],
              ),
              child: SheetLogo(
                size: 56 * dpr,
              ),
            ),
          ),
        ),
      ),
    ));
    final [logoFile] = (await snap(
      from: find.byKey(key),
    ));

    // Move file to docs
    final dir = Directory('../doc/');
    logoFile.copySync(dir.path + 'logo.png');
    logoFile.deleteSync();
  });
}
