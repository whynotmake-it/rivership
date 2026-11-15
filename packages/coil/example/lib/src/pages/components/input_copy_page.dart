import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:coil_example/src/widgets/type_roles.dart';
import 'package:flutter/widgets.dart';

const inputCopyEntry = CatalogEntry(
  slug: 'input-copy',
  title: 'InputCopy',
  group: CatalogGroup.groupedControls,
  summary: 'A read-only value with a copy action and inline feedback.',
  page: InputCopyPage.new,
);

class InputCopyPage extends StatefulWidget {
  const InputCopyPage({super.key});

  @override
  State<InputCopyPage> createState() => _InputCopyPageState();
}

class _InputCopyPageState extends State<InputCopyPage> {
  var _copies = 0;

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'InputCopy',
    summary:
        'Feedback is inline on every platform: the icon draws a check, the '
        'button reads "Copied", for 2 s. Tap the label to copy too.',
    children: [
      DemoSection(
        title: 'Icon action',
        child: DemoColumn(
          children: [
            CoilField(
              label: const Text('API key'),
              description: const Text('Keep it secret; rotate it if it leaks.'),
              child: CoilInputCopy(
                value: 'demo_key_7f3a91bc0e2d4a58',
                onCopied: () => setState(() => _copies++),
              ),
            ),
            CoilField(
              label: const Text('Clone URL'),
              child: CoilInputCopy(
                value: 'git@github.com:whynotmake-it/rivership.git',
                align: CoilInputCopyAlign.start,
                onCopied: () => setState(() => _copies++),
              ),
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'Button action',
        child: DemoColumn(
          children: [
            CoilField(
              label: const Text('Invite link'),
              child: CoilInputCopy(
                value: 'https://coil.dev/join/7f3a-91bc',
                variant: CoilInputCopyVariant.button,
                onCopied: () => setState(() => _copies++),
              ),
            ),
            const CoilField(
              label: Text('Disabled'),
              child: CoilInputCopy(
                value: 'Available after verification',
                variant: CoilInputCopyVariant.button,
                enabled: false,
              ),
            ),
            CoilField(
              label: const Text('Compact'),
              child: CoilInputCopy(
                value: 'v0.0.1-dev.0',
                size: CoilSize.compact,
                onCopied: () => setState(() => _copies++),
              ),
            ),
          ],
        ),
      ),
      RoleText(
        'Copied $_copies ${_copies == 1 ? 'time' : 'times'} on this page.',
        role: TypeRole.caption,
        muted: true,
      ),
    ],
  );
}
