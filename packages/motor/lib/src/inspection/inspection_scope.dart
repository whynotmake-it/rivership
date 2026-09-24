import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// Decides how inspection tools show the controllers that motor's builders
/// create below it.
///
/// [group] gathers the controllers into one group, such as all controllers
/// of a design system's buttons. [inspectable] set to false hides them.
/// Values that are null come from the nearest enclosing scope that sets
/// them. A controller's own `inspectable` and `inspectionGroup` win over
/// any scope.
///
/// ```dart
/// MotorInspectionScope(
///   group: 'Button press',
///   child: SingleMotionBuilder(value: pressed ? 0.96 : 1, …),
/// )
/// ```
@experimental
class MotorInspectionScope extends StatelessWidget {
  /// Applies [group] and [inspectable] to the builders below.
  const MotorInspectionScope({
    required this.child,
    this.group,
    this.inspectable,
    super.key,
  });

  /// The group for controllers created below, or null to keep the
  /// enclosing scope's.
  final String? group;

  /// Whether controllers created below are shown, or null to keep the
  /// enclosing scope's.
  final bool? inspectable;

  /// The subtree.
  final Widget child;

  /// The scope in effect at [context], merged from all enclosing scopes.
  @internal
  static ({String? group, bool? inspectable})? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ScopeData>()?.values;

  @override
  Widget build(BuildContext context) {
    final parent = of(context);
    return _ScopeData(
      values: (
        group: group ?? parent?.group,
        inspectable: inspectable ?? parent?.inspectable,
      ),
      child: child,
    );
  }
}

class _ScopeData extends InheritedWidget {
  const _ScopeData({required this.values, required super.child});

  final ({String? group, bool? inspectable}) values;

  @override
  bool updateShouldNotify(_ScopeData oldWidget) => oldWidget.values != values;
}
