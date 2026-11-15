import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/select_harness.dart';

void main() {
  testWidgets('without a preview it shows the extension and announces the '
      'name', (tester) async {
    await tester.pumpWidget(
      testApp(
        home: const Center(child: CoilFileThumbnail(name: 'brief.pdf')),
      ),
    );
    expect(find.text('PDF'), findsOneWidget);
    expect(find.bySemanticsLabel('brief.pdf'), findsOneWidget);
  });

  testWidgets('the remove button calls onRemove', (tester) async {
    var removed = 0;
    await tester.pumpWidget(
      testApp(
        home: Center(
          child: CoilFileThumbnail(
            name: 'photo.png',
            onRemove: () => removed++,
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Remove'));
    expect(removed, 1);
  });
}
