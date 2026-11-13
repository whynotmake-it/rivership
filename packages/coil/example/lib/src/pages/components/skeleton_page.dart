import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/type_roles.dart';
import 'package:flutter/widgets.dart';

const skeletonEntry = CatalogEntry(
  slug: 'skeleton',
  title: 'Skeleton',
  group: CatalogGroup.leafControls,
  summary: 'Placeholders that appear after a grace period and pulse.',
  page: SkeletonPage.new,
);

class SkeletonPage extends StatefulWidget {
  const SkeletonPage({super.key});

  @override
  State<SkeletonPage> createState() => _SkeletonPageState();
}

class _SkeletonPageState extends State<SkeletonPage> {
  var _loading = true;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reload() {
    _timer?.cancel();
    setState(() => _loading = true);
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Skeleton',
    summary:
        'Skeletons wait 160 ms, so fast loads never flash, then fade in and '
        'pulse. Reduced motion keeps the fade and drops the pulse.',
    children: [
      DemoSection(
        title: 'Loading a profile',
        description: 'Reload shows the skeleton for 3 s.',
        child: DemoColumn(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CoilButton(
                variant: CoilButtonVariant.secondary,
                onPressed: _loading
                    ? () => setState(() => _loading = false)
                    : _reload,
                child: Text(_loading ? 'Finish loading' : 'Reload'),
              ),
            ),
            if (_loading)
              const CoilSkeletonRegion(
                label: 'Loading profile',
                child: _ProfileSkeleton(),
              )
            else
              const _Profile(),
          ],
        ),
      ),
      const DemoSection(
        title: 'Text lines',
        description: 'Lines vary in width, like real text.',
        child: CoilSkeletonText(lines: 4),
      ),
    ],
  );
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CoilSkeleton(width: 48, height: 48),
      SizedBox(width: 12),
      Expanded(child: CoilSkeletonText(lines: 2)),
    ],
  );
}

class _Profile extends StatelessWidget {
  const _Profile();

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: 48,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: colors.accent,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(
                  CoilTheme.radiiOf(context).item,
                ),
              ),
            ),
            child: const Center(child: RoleText('AL', role: TypeRole.body)),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RoleText(
                'Ada Lovelace',
                role: TypeRole.body,
                weight: CoilWeight.semibold,
              ),
              RoleText(
                'Writes the first published algorithm for a machine.',
                role: TypeRole.body,
                muted: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
