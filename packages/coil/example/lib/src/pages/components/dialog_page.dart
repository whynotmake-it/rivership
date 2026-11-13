import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const dialogEntry = CatalogEntry(
  slug: 'dialog',
  title: 'Dialog',
  group: CatalogGroup.menusAndOverlays,
  summary: 'Confirmations centered everywhere; forms become sheets on phones.',
  page: DialogPage.new,
);

class DialogPage extends StatelessWidget {
  const DialogPage({super.key});

  Future<void> _open(BuildContext context, CoilDialogKind kind) =>
      showCoilDialog<void>(
        context: context,
        kind: kind,
        builder: (context) => CoilDialog(
          title: Text(
            kind == CoilDialogKind.form ? 'Rename project' : 'Delete project?',
          ),
          description: kind == CoilDialogKind.form
              ? null
              : const Text('Its pages and history go with it.'),
          onClose: () => Navigator.pop(context),
          actions: [
            CoilButton(
              variant: CoilButtonVariant.secondary,
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CoilButton(
              onPressed: () => Navigator.pop(context),
              child: Text(kind == CoilDialogKind.form ? 'Save' : 'Delete'),
            ),
          ],
          child: kind == CoilDialogKind.form
              ? const CoilField(label: Text('Name'), child: CoilInput())
              : null,
        ),
      );

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'Dialog',
    summary: 'A panel over a scrim that springs in with a blur-fade.',
    children: [
      DemoSection(
        title: 'Kinds',
        child: DemoWrap(
          children: [
            CoilButton(
              variant: CoilButtonVariant.secondary,
              onPressed: () => _open(context, CoilDialogKind.confirmation),
              child: const Text('Confirmation'),
            ),
            CoilButton(
              variant: CoilButtonVariant.secondary,
              onPressed: () => _open(context, CoilDialogKind.form),
              child: const Text('Form'),
            ),
          ],
        ),
      ),
    ],
  );
}
