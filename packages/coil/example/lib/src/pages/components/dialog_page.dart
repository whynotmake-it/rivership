import 'dart:async';

import 'package:auto_route/auto_route.dart';
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

/// A dialog that is a route of its own, declared in the router like any
/// page: its URL opens it, and back or the scrim pops it.
final dialogRouteDef = NamedRouteDef(
  name: 'coil:dialog-rename',
  path: '${dialogEntry.path}/rename',
  type: RouteType.custom(
    customRouteBuilder: <T>(context, child, page) => CoilModalRoute<T>(
      context: context,
      settings: page,
      presentation: CoilDialogKind.form.presentation,
      builder: (_) => child,
    ),
  ),
  builder: (context, data) => const _RenameDialog(),
);

class _RenameDialog extends StatelessWidget {
  const _RenameDialog();

  @override
  Widget build(BuildContext context) => CoilDialog(
    title: const Text('Rename project'),
    onClose: () => Navigator.pop(context),
    actions: [
      CoilButton(
        variant: CoilButtonVariant.secondary,
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      CoilButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Save'),
      ),
    ],
    child: const CoilField(label: Text('Name'), child: CoilInput()),
  );
}

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
      DemoSection(
        title: 'As a route',
        child: DemoWrap(
          children: [
            CoilButton(
              variant: CoilButtonVariant.secondary,
              onPressed: () => unawaited(
                context.router.push(NamedRoute(dialogRouteDef.name)),
              ),
              child: const Text('Rename'),
            ),
          ],
        ),
      ),
    ],
  );
}
