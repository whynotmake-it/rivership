import 'package:fluid_mobile_spike/src/tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// How the user is driving the UI right now. Picks the size step.
enum FluidInputMode {
  /// Mouse, trackpad or stylus hover: the web's 36px step.
  pointer,

  /// A finger: the 44px step.
  touch,
}

/// How an overlay that lists choices is shown.
enum FluidPresentation {
  /// Anchored to its trigger, with the fluid hover highlight.
  popover,

  /// A bottom sheet with touch-sized rows.
  sheet,
}

/// Window widths below this are phone-sized (Material's compact window
/// class, iOS's compact horizontal size class).
const double fluidCompactWidth = 600;

/// Decides input mode and presentation for everything below it.
///
/// Resolution, first match wins:
///
/// * input mode: [inputMode] if set, else the kind of the last pointer that
///   went down anywhere in the app (live, like the web's
///   `matchMedia('(pointer: coarse)')` listener), else the platform default
///   (iOS, Android and Fuchsia are touch; desktop is pointer).
/// * presentation (per component): the component's own `presentation`
///   argument, else [presentation] here, else [FluidPresentation.sheet] when
///   the input mode is touch and the window is narrower than
///   [fluidCompactWidth], else [FluidPresentation.popover].
///
/// Without a scope, components fall back to the platform default and the
/// window size.
class FluidAdaptiveScope extends StatefulWidget {
  /// Creates an adaptive scope.
  const FluidAdaptiveScope({
    required this.child,
    this.inputMode,
    this.presentation,
    super.key,
  });

  /// Pins the input mode (and with it the size step) for this subtree.
  final FluidInputMode? inputMode;

  /// Pins the presentation of every choice overlay in this subtree.
  final FluidPresentation? presentation;

  /// The subtree.
  final Widget child;

  /// The input mode at [context].
  static FluidInputMode inputModeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_FluidAdaptiveData>();
    return scope?.inputMode ?? platformDefaultInputMode();
  }

  /// The size step at [context].
  static FluidMetrics metricsOf(BuildContext context) =>
      switch (inputModeOf(context)) {
        FluidInputMode.pointer => FluidMetrics.pointer,
        FluidInputMode.touch => FluidMetrics.touch,
      };

  /// The presentation a choice overlay at [context] should use, given the
  /// component's own [override].
  static FluidPresentation presentationOf(
    BuildContext context, {
    FluidPresentation? override,
  }) {
    if (override != null) return override;
    final scope = context
        .dependOnInheritedWidgetOfExactType<_FluidAdaptiveData>();
    if (scope?.presentation case final presentation?) return presentation;
    final touch = inputModeOf(context) == FluidInputMode.touch;
    final compact = MediaQuery.sizeOf(context).width < fluidCompactWidth;
    return touch && compact
        ? FluidPresentation.sheet
        : FluidPresentation.popover;
  }

  /// Touch on iOS, Android and Fuchsia; pointer everywhere else.
  static FluidInputMode platformDefaultInputMode() =>
      switch (defaultTargetPlatform) {
        TargetPlatform.iOS ||
        TargetPlatform.android ||
        TargetPlatform.fuchsia => FluidInputMode.touch,
        _ => FluidInputMode.pointer,
      };

  @override
  State<FluidAdaptiveScope> createState() => _FluidAdaptiveScopeState();
}

class _FluidAdaptiveScopeState extends State<FluidAdaptiveScope> {
  FluidInputMode? _observed;

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    super.dispose();
  }

  void _onPointer(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    final mode = switch (event.kind) {
      PointerDeviceKind.touch => FluidInputMode.touch,
      PointerDeviceKind.mouse ||
      PointerDeviceKind.trackpad ||
      PointerDeviceKind.stylus ||
      PointerDeviceKind.invertedStylus => FluidInputMode.pointer,
      PointerDeviceKind.unknown => null,
    };
    if (mode != null && mode != _observed) setState(() => _observed = mode);
  }

  @override
  Widget build(BuildContext context) {
    return _FluidAdaptiveData(
      inputMode:
          widget.inputMode ??
          _observed ??
          FluidAdaptiveScope.platformDefaultInputMode(),
      presentation: widget.presentation,
      child: widget.child,
    );
  }
}

class _FluidAdaptiveData extends InheritedWidget {
  const _FluidAdaptiveData({
    required this.inputMode,
    required this.presentation,
    required super.child,
  });

  final FluidInputMode inputMode;
  final FluidPresentation? presentation;

  @override
  bool updateShouldNotify(_FluidAdaptiveData oldWidget) =>
      inputMode != oldWidget.inputMode ||
      presentation != oldWidget.presentation;
}

/// The colors for everything below it. Defaults to the platform brightness.
class FluidTheme extends InheritedWidget {
  /// Pins [colors] for this subtree.
  const FluidTheme({required this.colors, required super.child, super.key});

  /// The pinned colors.
  final FluidColors colors;

  /// The colors at [context].
  static FluidColors of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<FluidTheme>();
    if (theme != null) return theme.colors;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark
        ? FluidColors.dark
        : FluidColors.light;
  }

  @override
  bool updateShouldNotify(FluidTheme oldWidget) => colors != oldWidget.colors;
}

/// Whether the last thing the user did was press a key (the web's
/// `:focus-visible` heuristic). Focus rings show only while this is true,
/// so a mouse or touch pick that hands focus back draws no ring.
///
/// Flutter's [FocusHighlightMode] counts a mouse click as "traditional", the
/// same as a key press, so it can't tell these apart on desktop.
class FluidKeyboardModality extends ValueNotifier<bool> {
  FluidKeyboardModality._() : super(false) {
    HardwareKeyboard.instance.addHandler(_onKey);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  /// The app-wide instance.
  static final instance = FluidKeyboardModality._();

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) value = true;
    return false;
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) value = false;
  }
}
