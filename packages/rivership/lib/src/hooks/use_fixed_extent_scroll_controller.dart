import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Creates [FixedExtentScrollController] that will be disposed automatically.
///
/// See also:
/// - [FixedExtentScrollController]
///
// TODO(timcreatedit): remove when merged, https://github.com/rrousselGit/flutter_hooks/pull/437
FixedExtentScrollController useFixedExtentScrollController({
  int initialItem = 0,
  ScrollControllerCallback? onAttach,
  ScrollControllerCallback? onDetach,
  List<Object?>? keys,
}) {
  return use(
    _FixedExtentScrollControllerHook(
      initialItem: initialItem,
      onAttach: onAttach,
      onDetach: onDetach,
      keys: keys,
    ),
  );
}

class _FixedExtentScrollControllerHook
    extends Hook<FixedExtentScrollController> {
  const _FixedExtentScrollControllerHook({
    required this.initialItem,
    this.onAttach,
    this.onDetach,
    super.keys,
  });

  final int initialItem;
  final ScrollControllerCallback? onAttach;
  final ScrollControllerCallback? onDetach;

  @override
  HookState<FixedExtentScrollController, Hook<FixedExtentScrollController>>
      createState() => _FixedExtentScrollControllerHookState();
}

class _FixedExtentScrollControllerHookState extends HookState<
    FixedExtentScrollController, _FixedExtentScrollControllerHook> {
  late final controller = FixedExtentScrollController(
    initialItem: hook.initialItem,
    onAttach: hook.onAttach,
    onDetach: hook.onDetach,
  );

  @override
  FixedExtentScrollController build(BuildContext context) => controller;

  @override
  void dispose() => controller.dispose();

  @override
  String get debugLabel => 'useFixedExtentScrollController';
}
