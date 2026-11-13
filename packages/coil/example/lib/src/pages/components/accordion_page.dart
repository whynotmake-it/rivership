import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const accordionEntry = CatalogEntry(
  slug: 'accordion',
  title: 'Accordion',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'Panels that unfold on a spring, one or several at a time.',
  page: AccordionPage.new,
);

class AccordionPage extends StatefulWidget {
  const AccordionPage({super.key});

  @override
  State<AccordionPage> createState() => _AccordionPageState();
}

class _AccordionPageState extends State<AccordionPage> {
  String? _open = 'shipping';

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Accordion',
    summary: 'Opening one closes the other in single mode.',
    children: [
      DemoSection(
        title: 'Single',
        child: CoilAccordion<String>.single(
          value: _open,
          onChanged: (v) => setState(() => _open = v),
          items: const [
            CoilAccordionItem(
              value: 'shipping',
              label: 'Shipping',
              panel: Text('Orders ship within two working days.'),
            ),
            CoilAccordionItem(
              value: 'returns',
              label: 'Returns',
              panel: Text('Send it back within 30 days for a refund.'),
            ),
            CoilAccordionItem(
              value: 'warranty',
              label: 'Warranty',
              panel: Text('Two years on every part.'),
            ),
          ],
        ),
      ),
    ],
  );
}
