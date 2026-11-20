import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const bannerEntry = CatalogEntry(
  slug: 'banner',
  title: 'Banner',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'A page-level message that can be dismissed.',
  page: BannerPage.new,
);

class BannerPage extends StatefulWidget {
  const BannerPage({super.key});

  @override
  State<BannerPage> createState() => _BannerPageState();
}

class _BannerPageState extends State<BannerPage> {
  var _shown = true;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Banner',
    summary: 'Dismissing it asks the page to remove it.',
    children: [
      DemoSection(
        title: 'Message',
        child: _shown
            ? CoilBanner(
                title: const Text('Scheduled maintenance'),
                description: const Text('Saturday, 02:00 to 04:00 UTC.'),
                onDismissRequested: () => setState(() => _shown = false),
              )
            : CoilButton(
                variant: CoilButtonVariant.secondary,
                onPressed: () => setState(() => _shown = true),
                child: const Text('Show again'),
              ),
      ),
    ],
  );
}
