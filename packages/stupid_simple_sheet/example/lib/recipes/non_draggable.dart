import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';

/// Preview for the home page card — "Modal Overlay" style mockup.
///
/// Shows a dimmed overlay with a centered modal containing a lock icon,
/// suggesting a non-dismissable blocking view.
class NonDraggablePreview extends StatelessWidget {
  const NonDraggablePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Stack(
      children: [
        // Dim overlay
        Positioned.fill(
          child: Container(
            color: CupertinoColors.black.withValues(alpha: .15),
          ),
        ),
        // Centered modal
        Center(
          child: Container(
            width: 140,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: t.previewMiniSurface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: t.previewMiniShadow,
                  blurRadius: 48,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon circle
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: t.previewLine,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.lock_fill,
                    size: 16,
                    color: t.textTertiary,
                  ),
                ),
                const SizedBox(height: 10),
                // Title placeholder
                Container(
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(
                    color: t.previewHandle,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 6),
                // Subtitle placeholder
                Container(
                  width: 44,
                  height: 6,
                  decoration: BoxDecoration(
                    color: t.previewLine,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 14),
                // Button placeholder
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: t.textPrimary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Opens a non-draggable sheet directly.
void showNonDraggableSheet(BuildContext context) {
  Navigator.of(context).push(
    _CustomDraggabilityRoute(
      child: const _NonDraggableSheet(),
    ),
  );
}

class _NonDraggableSheet extends StatefulWidget {
  const _NonDraggableSheet();

  @override
  State<_NonDraggableSheet> createState() => __NonDraggableSheetState();
}

class __NonDraggableSheetState extends State<_NonDraggableSheet> {
  bool _canPop = false;
  @override
  Widget build(BuildContext context) {
    // We do this so the you can toggle the draggable parameter after the route
    // has been pushed.
    final draggableNotifier =
        (ModalRoute.of(context) as _CustomDraggabilityRoute)._draggableNotifier;
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: PopScope(
        canPop: _canPop,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CupertinoNavigationBar(
                automaticallyImplyLeading: false,
                middle: Text('Draggability'),
              ),
              CupertinoFormSection.insetGrouped(
                children: [
                  CupertinoListTile(
                    onTap: () => setState(() => _canPop = !_canPop),
                    title: const Text('PopScope.canPop'),
                    trailing: CupertinoSwitch(
                      value: _canPop,
                      onChanged: (v) => setState(() => _canPop = v),
                    ),
                  ),
                ],
                footer: Text(
                  'When a route contains a PopScope with canPop false, '
                  'the sheet will not be draggable below its lowest snap point '
                  'to dismiss.',
                ),
              ),
              CupertinoFormSection.insetGrouped(
                children: [
                  ListenableBuilder(
                      listenable: draggableNotifier,
                      builder: (context, child) {
                        return CupertinoListTile(
                          onTap: () => draggableNotifier.value =
                              !draggableNotifier.value,
                          title: const Text('Route draggable'),
                          trailing: CupertinoSwitch(
                            value: draggableNotifier.value,
                            onChanged: (v) => draggableNotifier.value = v,
                          ),
                        );
                      }),
                ],
                footer: Text(
                  'You can also control whether the sheet should be draggable '
                  'via the draggable parameter/getter on the route itself.',
                ),
              ),
              Spacer(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: CupertinoButton.filled(
                  child: const Text('Force Close'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomDraggabilityRoute extends StupidSimpleGlassSheetRoute<void> {
  _CustomDraggabilityRoute({required super.child})
      : super(
          snappingConfig: SheetSnappingConfig([.5, 1]),
          dismissalMode: DismissalMode.shrink,
        );

  final _draggableNotifier = ValueNotifier<bool>(true);

  @override
  bool get draggable => _draggableNotifier.value;

  @override
  void dispose() {
    _draggableNotifier.dispose();
    super.dispose();
  }
}
