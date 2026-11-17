import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil_glass/src/glass.dart';
import 'package:coil_glass/src/glass_scope.dart';
import 'package:coil_glass/src/on_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:motor/motor.dart';

/// One tab of a [CoilGlassTabBar].
@immutable
class CoilGlassTab<T> {
  /// Creates a tab.
  const CoilGlassTab({
    required this.value,
    required this.label,
    this.icon,
    this.semanticLabel,
  });

  /// The value [CoilGlassTabBar.onChanged] reports.
  final T value;

  /// What the tab shows, usually a [Text].
  final Widget label;

  /// An icon above ([CoilGlassTabLayout.stacked]) or before the label.
  final Widget? icon;

  /// A name for screen readers when [label] can't give one.
  final String? semanticLabel;
}

/// How a [CoilGlassTabBar] lays out a tab.
enum CoilGlassTabLayout {
  /// Icon over a small label: a phone's bottom bar.
  stacked,

  /// Icon and label in a row: a toolbar's segmented control.
  inline,
}

/// What the bar is made of.
enum CoilGlassTabChrome {
  /// A glass capsule.
  glass,

  /// coil's raised surface. Only the lens is glass, and only while the
  /// selection moves: glass as a moment, not a material.
  flat,
}

/// How the selection travels.
enum CoilGlassIndicator {
  /// A platter that glides between tabs on the theme's `standard` spring.
  platter,

  /// The platter, plus a clear glass lens that lifts off it while it
  /// travels, is dragged or is held, and settles back into the platter on
  /// arrival. Apple's tab bar does the same.
  lens,
}

/// A segmented control / tab bar built for the floating control layer.
///
/// The selection is a [CoilGlassIndicator]: a platter painted on the bar,
/// and with [CoilGlassIndicator.lens] a glass lens in its own small layer
/// over the bar, so it refracts the bar and the labels beneath it. Drag
/// across the bar to scrub the selection; it lands on release.
///
/// The selection travels on the theme's `standard` spring (`motion:`
/// overrides it) and follows the finger on an interactive spring. Under
/// reduced motion it jumps and the lens never shows.
class CoilGlassTabBar<T> extends StatefulWidget {
  /// Creates a tab bar.
  const CoilGlassTabBar({
    required this.tabs,
    required this.value,
    required this.onChanged,
    super.key,
    this.layout = CoilGlassTabLayout.stacked,
    this.chrome = CoilGlassTabChrome.glass,
    this.indicator = CoilGlassIndicator.lens,
    this.motion,
  }) : assert(tabs.length > 0, 'a tab bar needs tabs');

  /// The tabs, in order.
  final List<CoilGlassTab<T>> tabs;

  /// The selected tab's value.
  final T value;

  /// Called with the newly selected value. Null disables the bar.
  final ValueChanged<T>? onChanged;

  /// Stacked (phone) or inline (toolbar).
  final CoilGlassTabLayout layout;

  /// Glass or flat.
  final CoilGlassTabChrome chrome;

  /// Platter only, or platter and lens.
  final CoilGlassIndicator indicator;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  @override
  State<CoilGlassTabBar<T>> createState() => _CoilGlassTabBarState<T>();
}

class _CoilGlassTabBarState<T> extends State<CoilGlassTabBar<T>> {
  static const _inset = 4.0;

  /// The lens: clear, unfrosted, bending only near its rim, after the
  /// renderer's iOS 27 tab bar loupe.
  static const _lensSettings = LiquidGlassSettings(
    refractionHeight: 14,
    refractionAmount: 12,
    refractionFitsShape: false,
    dispersion: -.25,
    frost: 0,
    contourStrength: .3,
    backdropShrink: 0.06,
  );

  /// Where the finger is, in tabs, while scrubbing.
  double? _scrub;
  bool _held = false;

  int get _selected =>
      math.max(0, widget.tabs.indexWhere((tab) => tab.value == widget.value));

  double get _height => switch (widget.layout) {
    CoilGlassTabLayout.stacked => 62,
    CoilGlassTabLayout.inline =>
      CoilTheme.metricsOf(context).controlHeight + 2 * _inset,
  };

  double _tabAt(double dx, double slot) =>
      ((dx - _inset) / slot - 0.5).clamp(0, widget.tabs.length - 1).toDouble();

  void _land() {
    final scrub = _scrub;
    setState(() => _scrub = null);
    if (scrub == null) return;
    widget.onChanged?.call(widget.tabs[scrub.round()].value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final lensAllowed =
        widget.indicator == CoilGlassIndicator.lens &&
        !reduced &&
        CoilGlassScope.modeOf(context) != CoilGlassMode.solid;
    final target = _scrub ?? _selected.toDouble();
    final height = _height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = (constraints.maxWidth - 2 * _inset) / widget.tabs.length;
        final enabled = widget.onChanged != null;
        return Listener(
          onPointerDown: enabled ? (_) => setState(() => _held = true) : null,
          onPointerUp: (_) => setState(() => _held = false),
          onPointerCancel: (_) => setState(() => _held = false),
          child: GestureDetector(
            onHorizontalDragStart: enabled
                ? (d) => setState(
                    () => _scrub = _tabAt(d.localPosition.dx, slot),
                  )
                : null,
            onHorizontalDragUpdate: enabled
                ? (d) => setState(
                    () => _scrub = _tabAt(d.localPosition.dx, slot),
                  )
                : null,
            onHorizontalDragEnd: enabled ? (_) => _land() : null,
            onHorizontalDragCancel: enabled ? _land : null,
            child: SingleMotionBuilder(
              value: _held && lensAllowed ? 1 : 0,
              motion: motion.quick,
              builder: (context, held, _) => SingleMotionBuilder(
                value: target,
                motion: _scrub != null
                    ? const Motion.interactiveSpring()
                    : motion.standard,
                builder: (context, position, _) {
                  final travel = ((position - target).abs() * 2).clamp(
                    0.0,
                    1.0,
                  );
                  final lens = lensAllowed ? math.max(held, travel) : 0.0;
                  return _bar(context, theme, slot, height, position, lens);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bar(
    BuildContext context,
    CoilThemeData theme,
    double slot,
    double height,
    double position,
    double lens,
  ) {
    final colors = theme.colors;
    final platterRadius = BorderRadius.circular(height);
    final content = SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(_inset),
        child: Stack(
          children: [
            Positioned(
              left: position * slot,
              top: 0,
              bottom: 0,
              width: slot,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: CoilOnGlass.platterOf(colors),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: platterRadius,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final (i, tab) in widget.tabs.indexed)
                  Expanded(
                    child: _TabSlot(
                      tab: tab,
                      layout: widget.layout,
                      selected: i == _selected,
                      // 1 under the platter, 0 a tab away.
                      emphasis: 1 - (position - i).abs().clamp(0.0, 1.0),
                      onPressed: widget.onChanged == null
                          ? null
                          : () => widget.onChanged!(tab.value),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    final bar = switch (widget.chrome) {
      CoilGlassTabChrome.glass => CoilGlass(
        shape: CoilGlassShape.pill,
        child: content,
      ),
      CoilGlassTabChrome.flat => CoilSurface(
        offset: CoilSurface.popoverOffset,
        shadowLevel: 3,
        borderRadius: platterRadius,
        child: CoilOnGlass(child: content),
      ),
    };
    if (lens <= 0.001) return bar;

    // The lens lifts off the platter: a little taller than the bar, so it
    // reads as a separate piece of glass riding over it.
    final grow = 6 * lens;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        bar,
        Positioned(
          left: _inset + position * slot - grow,
          top: _inset - grow,
          width: slot + 2 * grow,
          height: height - 2 * _inset + 2 * grow,
          child: IgnorePointer(
            child: LiquidGlassVisibility(
              visibility: lens,
              child: LiquidGlass.withOwnLayer(
                settings: _lensSettings,
                fake: CoilGlassScope.modeOf(context) == CoilGlassMode.frosted,
                shape: const LiquidRoundedSuperellipse(borderRadius: 1000),
                appearance: const LiquidGlassAppearance.ios27Clear(),
                shadows: [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, .14 * lens),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ],
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabSlot extends StatelessWidget {
  const _TabSlot({
    required this.tab,
    required this.layout,
    required this.selected,
    required this.emphasis,
    required this.onPressed,
  });

  final CoilGlassTab<Object?> tab;
  final CoilGlassTabLayout layout;
  final bool selected;
  final double emphasis;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    // coil keeps labels neutral: the platter and the weight mark the
    // selection, so the label holds its contrast over any backdrop. (Apple
    // tints the selected tab; coil's brand is reserved for actions.)
    final color = Color.lerp(
      colors.foreground.withValues(alpha: 0.72),
      colors.foreground,
      emphasis,
    )!;
    final stacked = layout == CoilGlassTabLayout.stacked;
    final label = DefaultTextStyle.merge(
      style: (stacked ? text.micro : text.body).copyWith(
        color: color,
        fontWeight: FontWeight.lerp(
          FontWeight.w500,
          FontWeight.w600,
          emphasis,
        ),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: tab.label,
    );
    final icon = tab.icon == null
        ? null
        : IconTheme.merge(
            data: IconThemeData(
              color: color,
              size: stacked ? 22 : 16,
              applyTextScaling: true,
            ),
            child: tab.icon!,
          );
    return Semantics(
      button: true,
      selected: selected,
      label: tab.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Center(
          child: stacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [?icon, label],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [?icon, label],
                ),
        ),
      ),
    );
  }
}
