import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/kbd.dart';
import 'package:coil/src/components/sidebar/sidebar_scope.dart';
import 'package:coil/src/components/sidebar/sidebar_text.dart';
import 'package:coil/tooltip.dart';
import 'package:flutter/widgets.dart';

/// The ghost icon button that opens and closes the nearest
/// `CoilSidebarScaffold`'s sidebar, or its drawer on a phone.
///
/// Its tooltip names what a press does and the key that does the same.
/// When the scaffold peeks on hover, resting the pointer on a folded
/// trigger floats the sidebar out too.
class CoilSidebarTrigger extends StatefulWidget {
  /// Creates a trigger.
  const CoilSidebarTrigger({
    required this.icon,
    super.key,
    this.openLabel = const Text('Expand sidebar'),
    this.closeLabel = const Text('Collapse sidebar'),
    this.openSemanticLabel,
    this.closeSemanticLabel,
    this.size,
  });

  /// The icon, such as a panel glyph facing the sidebar's side.
  final Widget icon;

  /// The tooltip while a press would open the sidebar, usually a [Text].
  final Widget openLabel;

  /// The tooltip while a press would close it, usually a [Text].
  final Widget closeLabel;

  /// [openLabel] for screen readers. Null reads the text of a [Text].
  final String? openSemanticLabel;

  /// [closeLabel] for screen readers. Null reads the text of a [Text].
  final String? closeSemanticLabel;

  /// Pins the button to one size step.
  final CoilSize? size;

  @override
  State<CoilSidebarTrigger> createState() => _CoilSidebarTriggerState();
}

class _CoilSidebarTriggerState extends State<CoilSidebarTrigger> {
  final _states = WidgetStatesController();
  CoilSidebarScopeData? _scope;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _states.addListener(_onStates);
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  void _onStates() {
    final hovered = _states.value.contains(WidgetState.hovered);
    if (hovered == _hovered) return;
    _hovered = hovered;
    final scope = _scope;
    if (scope == null || scope.peekMode != CoilSidebarPeek.hover) return;
    hovered ? scope.armPeek() : scope.disarmPeek();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope = CoilSidebarScope.maybeOf(context);
    assert(scope != null, 'CoilSidebarTrigger needs a CoilSidebarScaffold.');
    final open = scope!.drawer || scope.controller.open;
    final label = open ? widget.closeLabel : widget.openLabel;
    final semanticLabel =
        (open ? widget.closeSemanticLabel : widget.openSemanticLabel) ??
        coilSidebarPlainText(label) ??
        '';
    return CoilTooltip(
      semanticLabel: semanticLabel,
      // TODO(coil-sidebar): move the key to CoilTooltip's shortcut slot once
      // it lands.
      message: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          label,
          CoilKbd(scope.shortcutLabel, tone: CoilKbdTone.inverted),
        ],
      ),
      child: CoilButton.icon(
        onPressed: scope.toggle,
        icon: widget.icon,
        semanticLabel: semanticLabel,
        variant: CoilButtonVariant.ghost,
        size: widget.size ?? CoilSize.compact,
        statesController: _states,
      ),
    );
  }
}
