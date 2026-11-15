import 'dart:async';
import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:merging_dots/merging_dots.dart';
import 'package:merging_dots_example/editor/icons.dart';
import 'package:merging_dots_example/editor/ui.dart';

/// Shows every ready-made loader, live.
Future<void> showLoadersGallery(BuildContext context) => showCoilDialog<void>(
  context: context,
  builder: (context) => const _LoadersGallery(),
);

class _LoadersGallery extends StatefulWidget {
  const _LoadersGallery();

  @override
  State<_LoadersGallery> createState() => _LoadersGalleryState();
}

class _LoadersGalleryState extends State<_LoadersGallery> {
  final _random = math.Random(4);
  Timer? _timer;
  double _progress = 0;
  var _simulate = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  /// Feeds determinate loaders like a download: irregular steps, a pause
  /// at the end, then again.
  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      setState(() {
        _progress = _progress >= 1
            ? 0
            : math.min(1, _progress + 0.02 + _random.nextDouble() * 0.12);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CoilDialog(
      size: CoilDialogSize.xl,
      title: const Text('Loaders'),
      description: const Text(
        'Every ready-made loader in merging_dots. Determinate ones follow '
        'the progress below.',
      ),
      onClose: () => Navigator.of(context).pop(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CoilSwitch(
                  value: _simulate,
                  label: const Text('Simulate a download'),
                  onChanged: (simulate) {
                    setState(() => _simulate = simulate);
                    simulate ? _start() : _timer?.cancel();
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: PropertySlider(
                    label: 'Progress',
                    value: _progress,
                    min: 0,
                    max: 1,
                    format: (v) => '${(v * 100).round()} %',
                    onChanged: (progress) {
                      _timer?.cancel();
                      setState(() {
                        _simulate = false;
                        _progress = progress;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: CoilScrollArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (family, loaders) in DotLoaders.families) ...[
                      const SizedBox(height: 12),
                      RoleText.caption(family),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final loader in loaders)
                            _LoaderCard(loader: loader, progress: _progress),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoaderCard extends StatelessWidget {
  const _LoaderCard({required this.loader, required this.progress});

  final DotLoader loader;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(
          CoilTheme.radiiOf(context).container,
        ),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 88,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Large, and at an icon's size.
                Expanded(
                  child: IconTheme.merge(
                    data: IconThemeData(color: colors.foreground),
                    child: DotLoaderView(loader: loader, progress: progress),
                  ),
                ),
                const SizedBox(width: 8),
                IconTheme.merge(
                  data: IconThemeData(color: colors.foreground),
                  child: SizedBox.square(
                    dimension: 24,
                    child: DotLoaderView(loader: loader, progress: progress),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: RoleText(
                  loader.name,
                  weight: CoilWeight.semibold,
                  maxLines: 1,
                ),
              ),
              if (loader.isDeterminate)
                const SizedBox.square(
                  dimension: 14,
                  child: GlyphIcon(Glyph.gauge),
                ),
            ],
          ),
          const SizedBox(height: 2),
          RoleText.caption(loader.description),
        ],
      ),
    );
  }
}
