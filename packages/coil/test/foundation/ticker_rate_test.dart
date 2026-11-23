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

const _frame = Duration(milliseconds: 16);
const _frames = 25;

/// The most ticks a [fps] rate can fit into the frames [_changes] pumps:
/// one per interval, plus one for where the first lands.
int _ticksAt(double fps) =>
    (_frame.inMicroseconds * _frames / (1e6 / fps)).ceil() + 1;

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
  for (var i = 0; i < _frames; i++) {
    await tester.pump(_frame);
    if (!listEquals(thumb(), lastThumb)) thumbChanges++;
    if (bannerHeight() != lastBanner) bannerChanges++;
    lastThumb = thumb();
    lastBanner = bannerHeight();
  }
  return (switchThumb: thumbChanges, banner: bannerChanges);
}

void main() {
  group('coil motion', () {
    testWidgets('advances more often than a slow rate allows without a '
        'TickerRateScope', (tester) async {
      final changes = await _changes(tester);
      expect(changes.switchThumb, greaterThan(_ticksAt(10)));
      expect(changes.banner, greaterThan(_ticksAt(10)));
    });

    testWidgets('only advances on the ticks of a TickerRateScope', (
      tester,
    ) async {
      final changes = await _changes(tester, rate: TickerRate.fps(10));
      expect(changes.switchThumb, inInclusiveRange(1, _ticksAt(10)));
      expect(changes.banner, inInclusiveRange(1, _ticksAt(10)));
    });
  });
}
