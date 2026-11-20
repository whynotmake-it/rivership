import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/radio_group/radio_group.dart';
import 'package:coil/src/components/radio_group/radio_group_style.dart';
import 'package:coil/src/components/radio_group/radio_indicator.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// One radio, for layouts a [CoilRadioGroup]'s rows don't cover, such as
/// radio choice cards.
///
/// Put it under a `CoilRadioGroup.custom`, which selects the radio whose
/// [value] it holds and gives the radios its keyboard model. A tap, Space
/// or Enter selects it.
///
/// It works under Flutter's [RadioGroup] too, which `CoilRadioGroup.custom`
/// builds on.
class CoilRadio<T> extends StatefulWidget {
  /// Creates a radio for [value].
  const CoilRadio({
    required this.value,
    super.key,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.size,
    this.motion,
    this.motions,
    this.style,
    this.semanticLabel,
  });

  /// The value this radio selects.
  final T value;

  /// Whether the radio can be selected. A disabled group disables it too.
  final bool enabled;

  /// The focus node.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// Pins the circle to one size step. Null follows the group, then
  /// [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens. Null follows the group.
  final CoilMotion? motion;

  /// Per-track motions; the `border` and `dot` tracks apply. Null follows
  /// the group.
  final Map<CoilRadioGroupTrack<Object>, Motion>? motions;

  /// Overrides for the circle's look. Null follows the group.
  final CoilRadioGroupStyle? style;

  /// A label for assistive technology, when nothing labels the radio.
  final String? semanticLabel;

  @override
  State<CoilRadio<T>> createState() => _CoilRadioState<T>();
}

class _CoilRadioState<T> extends State<CoilRadio<T>> with RadioClient<T> {
  FocusNode? _ownFocusNode;

  @override
  FocusNode get focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'CoilRadio'));

  @override
  T get radioValue => widget.value;

  @override
  bool get tristate => false;

  @override
  bool get enabled =>
      widget.enabled &&
      registry != null &&
      (context.getInheritedWidgetOfExactType<CoilRadioScope>()?.enabled ??
          true);

  CoilRadioClients? _clients;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    registry = RadioGroup.maybeOf<T>(context);
    final clients = CoilRadioScope.maybeOf(context)?.clients;
    if (clients != _clients) {
      _clients?._clients.remove(this);
      _clients = clients?.._clients.add(this);
    }
  }

  @override
  void dispose() {
    _clients?._clients.remove(this);
    registry = null;
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _select() {
    final registry = this.registry;
    if (registry == null || registry.groupValue == widget.value) return;
    registry.onChanged(widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final group = CoilRadioScope.maybeOf(context);
    final field = CoilFieldScope.maybeOf(context);
    final framed = field?.framed ?? false;
    final size = widget.size ?? group?.size;
    final sizes = CoilTheme.metricsOf(context, size: size);
    final selected = registry?.groupValue == widget.value;
    final enabled = this.enabled;
    final box = MediaQuery.textScalerOf(context).scale(
      CoilRadioGroupStyle.fallback(CoilTheme.of(context), sizes)
          .merge(CoilTheme.styleOf<CoilRadioGroupStyle>(context))
          .merge(widget.style ?? group?.style)
          .size!,
    );

    return CoilFieldControl(
      onLabelTap: enabled ? _select : null,
      tapArea: CoilFieldTapArea.row,
      child: Semantics(
        container: true,
        inMutuallyExclusiveGroup: true,
        checked: selected,
        enabled: enabled,
        label: widget.semanticLabel,
        child: CoilInteraction(
          onPressed: enabled ? _select : null,
          focusNode: focusNode,
          autofocus: widget.autofocus,
          // A framing container (a choice card) is the target.
          minHitTarget: framed ? 0 : sizes.minHitTarget,
          builder: (context, states, _) => Opacity(
            opacity: enabled ? 1 : sizes.disabledOpacity,
            child: CoilFocusRing(
              visible: states.contains(WidgetState.focused) && !framed,
              borderRadius: BorderRadius.circular(box / 2),
              child: CoilRadioIndicator(
                selected: selected,
                states: {
                  if (enabled && (field?.containerHovered ?? false))
                    WidgetState.hovered,
                  if (enabled && (field?.containerPressed ?? false))
                    WidgetState.pressed,
                  ...states,
                },
                size: size,
                motion: widget.motion ?? group?.motion,
                motions: widget.motions ?? group?.motions,
                style: widget.style ?? group?.style,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What a `CoilRadioGroup.custom` tells the [CoilRadio]s below it: whether
/// the group is enabled, and the look they share.
class CoilRadioScope extends InheritedWidget {
  /// Creates a radio scope.
  const CoilRadioScope({
    required this.enabled,
    required this.clients,
    required super.child,
    super.key,
    this.size,
    this.motion,
    this.motions,
    this.style,
  });

  /// Whether the group can change. False disables every radio.
  final bool enabled;

  /// Where the radios below register, so the group can find them.
  final CoilRadioClients clients;

  /// The radios' size step.
  final CoilSize? size;

  /// The radios' motion tokens.
  final CoilMotion? motion;

  /// The radios' per-track motions.
  final Map<CoilRadioGroupTrack<Object>, Motion>? motions;

  /// The radios' look.
  final CoilRadioGroupStyle? style;

  /// The nearest scope, if any.
  static CoilRadioScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoilRadioScope>();

  @override
  bool updateShouldNotify(CoilRadioScope oldWidget) =>
      oldWidget.enabled != enabled ||
      oldWidget.clients != clients ||
      oldWidget.size != size ||
      oldWidget.motion != motion ||
      oldWidget.motions != motions ||
      oldWidget.style != style;
}

/// The [CoilRadio]s under a `CoilRadioGroup.custom`, for the keys Flutter's
/// [RadioGroup] doesn't handle (Home and End).
class CoilRadioClients {
  final _clients = <RadioClient<Object?>>{};

  /// The registered radios that can be selected.
  Iterable<RadioClient<Object?>> get enabled =>
      _clients.where((client) => client.enabled);
}
