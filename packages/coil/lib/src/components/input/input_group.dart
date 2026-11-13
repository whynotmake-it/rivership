import 'package:coil/field.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:flutter/widgets.dart';

/// A stack of labeled fields that share one hover.
///
/// The field nearest the mouse shows the hover fill, even when the pointer
/// is in the gap between fields, so the hover never flickers off. Touch
/// shows focus only. Each child is usually a `CoilField` around a
/// `CoilInput`.
///
/// ```dart
/// CoilInputGroup(
///   children: [
///     CoilField(label: Text('Name'), child: CoilInput()),
///     CoilField(
///       label: Text('Email'),
///       error: Text('Enter an email address like ada@example.com'),
///       child: CoilInput(),
///     ),
///   ],
/// )
/// ```
class CoilInputGroup extends StatelessWidget {
  /// Creates an input group.
  const CoilInputGroup({required this.children, super.key, this.size});

  /// The fields, top to bottom.
  final List<Widget> children;

  /// Pins every field to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  @override
  Widget build(BuildContext context) {
    final gap = CoilFieldStyle.resolve(context, size: size).fieldGap!;
    Widget group = CoilHoverRegion(
      nearest: true,
      highlight: false,
      // Focus shows as the field's focus border, not as hover.
      followFocus: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: [
          for (final (index, child) in children.indexed)
            CoilHoverItem(
              index: index,
              child: InputGroupSlot(index: index, child: child),
            ),
        ],
      ),
    );
    if (size case final size?) {
      group = CoilAdaptiveScope(size: size, child: group);
    }
    return group;
  }
}

/// Marks one field of a [CoilInputGroup], so its input takes hover from the
/// group (the field nearest the pointer) instead of from its own box.
class InputGroupSlot extends InheritedWidget {
  /// Creates a slot for the group item at [index].
  const InputGroupSlot({required this.index, required super.child, super.key});

  /// The field's index in the group's hover region.
  final int index;

  /// The slot above [context], if the field is in an input group.
  static InputGroupSlot? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<InputGroupSlot>();

  @override
  bool updateShouldNotify(InputGroupSlot oldWidget) => oldWidget.index != index;
}
