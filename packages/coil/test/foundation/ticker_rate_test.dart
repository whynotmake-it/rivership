import 'package:coil/coil.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../src/select_harness.dart';

/// A switch and a banner, which drive their own controllers.
class _Page extends StatefulWidget {
  const _Page();

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  bool on = false;
  bool visible = true;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoilSwitch(value: on, onChanged: (v) => setState(() => on = v)),
        CoilBanner(
          title: const Text('Saved'),
          visible: visible,
          onDismissRequested: () => setState(() => visible = false),
        ),
      ],
    ),
  );
}

/// How many 16 ms frames the switch thumb and the banner changed in, after
/// toggling the switch and dismissing the banner.
Future<({int switchThumb, int banner})> _changes(
  WidgetTester tester, {
  TickerRate? rate,
}) async {
  useScreen(tester, TestScreen.desktop);
  Widget home = const Center(child: _Page());
  if (rate != null) home = TickerRateScope(rate: rate, child: home);
  await tester.pumpWidget(testApp(tier: CoilTier.pointer, home: home));
  await tester.pumpAndSettle();

  List<double> thumb() => [
    for (final w in tester.widgetList<PositionedDirectional>(
      find.descendant(
        of: find.byType(CoilSwitch),
        matching: find.byType(PositionedDirectional),
      ),
    ))
      w.start ?? 0,
  ];
  double bannerHeight() => tester.getSize(find.byType(CoilBanner)).height;

  await tester.tap(find.byType(CoilSwitch));
  await tester.tap(find.byType(CoilButton));

  var thumbChanges = 0;
  var bannerChanges = 0;
  var lastThumb = thumb();
  var lastBanner = bannerHeight();
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (!listEquals(thumb(), lastThumb)) thumbChanges++;
    if (bannerHeight() != lastBanner) bannerChanges++;
    lastThumb = thumb();
    lastBanner = bannerHeight();
  }
  return (switchThumb: thumbChanges, banner: bannerChanges);
}

void main() {
  group('coil motion', () {
    testWidgets('advances every frame without a TickerRateScope', (
      tester,
    ) async {
      final changes = await _changes(tester);
      expect(changes.switchThumb, greaterThan(10));
      expect(changes.banner, greaterThan(10));
    });

    testWidgets('only advances on the ticks of a TickerRateScope', (
      tester,
    ) async {
      // 25 frames of 16 ms is 400 ms: at 10 fps that is about 4 ticks.
      final changes = await _changes(tester, rate: TickerRate.fps(10));
      expect(changes.switchThumb, inInclusiveRange(1, 6));
      expect(changes.banner, inInclusiveRange(1, 6));
    });
  });
}
