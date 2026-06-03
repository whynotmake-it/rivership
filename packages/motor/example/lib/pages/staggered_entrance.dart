import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

/// A staggered list entrance. One track per row, all created in an array and
/// played on a single clock with staggered holds, so the list settles in like
/// a well-timed cascade.
class StaggeredEntrancePage extends StatefulWidget {
  const StaggeredEntrancePage({super.key});
  static const routeName = 'Staggered Entrance';

  static const _rows = [
    (CupertinoIcons.cloud_download, 'Sync complete', '128 files'),
    (CupertinoIcons.checkmark_seal, 'Verified', 'Signature valid'),
    (CupertinoIcons.bolt, 'Optimized', 'Saved 1.2 MB'),
    (CupertinoIcons.lock, 'Encrypted', 'End to end'),
    (CupertinoIcons.paperplane, 'Shared', '3 recipients'),
  ];

  @override
  State<StaggeredEntrancePage> createState() => _StaggeredEntrancePageState();
}

class _StaggeredEntrancePageState extends State<StaggeredEntrancePage> {
  static final _rowTracks = [
    for (var i = 0; i < StaggeredEntrancePage._rows.length; i++)
      Track<double>(.single, origin: 0),
  ];
  static final _header = Track<double>(.single, origin: 0);

  int _replay = 0;

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: StaggeredEntrancePage.routeName,
      description:
          'Each row is its own track in an array. Staggered holds offset their '
          'starts, and a shared clock keeps the cascade coherent — a single '
          'spring shape drives every line.',
      action: Align(
        alignment: Alignment.centerLeft,
        child: NeutralButton(
          onPressed: () => setState(() => _replay++),
          child: const Text('Replay'),
        ),
      ),
      child: Surface(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: MultiTrackMotionBuilder(
          restartTrigger: _replay,
          from: [
            _header.value(0),
            for (final track in _rowTracks) track.value(0),
          ],
          play: [
            _header([
              .to(
                1,
                motion: .smoothSpring(duration: Duration(milliseconds: 420)),
              ),
            ]),
            for (final (i, track) in _rowTracks.indexed)
              track([
                .hold(Duration(milliseconds: 120 + i * 90)),
                .to(
                  1,
                  motion: .bouncySpring(
                    duration: Duration(milliseconds: 520),
                    extraBounce: .04,
                  ),
                ),
              ]),
          ],
          builder: (context, value, child) {
            final h = value(_header).clamp(0.0, 1.0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
                  child: Opacity(
                    opacity: h,
                    child: Transform.translate(
                      offset: Offset(0, (1 - h) * 8),
                      child: Text(
                        'Activity',
                        style: TextStyle(
                          fontFamily: 'Archivo',
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -0.6,
                          color: ExampleTheme.of(context).textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                for (final (i, track) in _rowTracks.indexed)
                  _Row(
                    data: StaggeredEntrancePage._rows[i],
                    progress: value(track).clamp(0.0, 1.0),
                    last: i == _rowTracks.length - 1,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.data, required this.progress, required this.last});

  final (IconData, String, String) data;
  final double progress;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final (icon, title, subtitle) = data;
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, (1 - progress) * 18),
        child: Container(
          decoration: BoxDecoration(
            border: last
                ? null
                : Border(bottom: BorderSide(color: t.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.fog, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: t.textSecondary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: t.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.checkmark, size: 16, color: t.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
