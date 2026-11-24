// Internal to the combobox; not exported.
// The render object's fields sit behind setters that mark layout dirty.
// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/input.dart';
import 'package:coil/primitives.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// The height of a combobox chip at a size step: it leaves the field's
/// vertical padding on each side of one row.
double comboboxChipExtent(CoilMetrics metrics) => switch ((
  metrics.tier,
  metrics.size,
)) {
  (CoilTier.pointer, CoilSize.regular) => 24,
  (CoilTier.pointer, CoilSize.compact) => 20,
  (CoilTier.touch, CoilSize.regular) => 28,
  (CoilTier.touch, CoilSize.compact) => 24,
};

/// The field of a multi-select combobox: the picks as chips **inside** the
/// field's chrome, before the text, which takes the rest of the chips' last
/// row and wraps with them.
///
/// It draws a `CoilInput`'s chrome (the same [CoilInputStyle], fill, border
/// and relief) around the one text-editing primitive, and lays the chips
/// and the text out in runs with [ComboboxChipsRun]. The field's height
/// springs as chips wrap.
class ComboboxChipsField extends StatefulWidget {
  /// Creates the chips field.
  const ComboboxChipsField({
    required this.chips,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.shortcuts,
    super.key,
    this.placeholder,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.size,
    this.motion,
  });

  /// One chip per pick, in the options' order, before the text.
  final List<Widget> chips;

  /// The query's controller.
  final TextEditingController controller;

  /// The field's focus node.
  final FocusNode focusNode;

  /// Whether the field takes input and focus.
  final bool enabled;

  /// Keys mapped to the combobox's intents.
  final Map<ShortcutActivator, Intent> shortcuts;

  /// Shown, muted, while nothing is picked and nothing is typed.
  final Widget? placeholder;

  /// A slot at the end of the first row, usually the chevron.
  final Widget? trailing;

  /// Called when the query changes.
  final ValueChanged<String>? onChanged;

  /// Called when the keyboard's action button submits.
  final ValueChanged<String>? onSubmitted;

  /// Called when a pointer or a finger taps the field.
  final VoidCallback? onTap;

  /// Pins the field's size step.
  final CoilSize? size;

  /// Motion tokens for the field.
  final CoilMotion? motion;

  @override
  State<ComboboxChipsField> createState() => _ComboboxChipsFieldState();
}

class _ComboboxChipsFieldState extends State<ComboboxChipsField> {
  final _states = WidgetStatesController();

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
    _onFocus();
  }

  @override
  void didUpdateWidget(ComboboxChipsField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
      _onFocus();
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    _states.dispose();
    super.dispose();
  }

  void _onFocus() =>
      _states.update(WidgetState.focused, widget.focusNode.hasFocus);

  void _focusFromLabel() {
    if (widget.focusNode.canRequestFocus) widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final look = CoilInputStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilInputStyle>(context));
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final textStyle = look.textStyle!;
    final radius = BorderRadius.circular(look.radius!);
    final radii = CoilTheme.radiiOf(context);
    final invalid = CoilFieldScope.maybeOf(context)?.invalid ?? false;
    final lineHeight = textStyle.lineHeight;
    // A row is as tall as a chip once there is one, so the padding that
    // centers it in the field's height is smaller than a bare line's.
    final rowExtent = widget.chips.isEmpty
        ? lineHeight
        : math.max(lineHeight, comboboxChipExtent(metrics));
    final padY = math.max(0, (look.minHeight! - rowExtent) / 2).toDouble();
    // A leading chip sits as far from the field's leading edge as from its
    // top and bottom; text first keeps the text's padding, and so does text
    // on a row of its own after chips. A chip's corner is concentric with
    // the field's, but never sharper than an item's: a tight field would
    // otherwise nest it almost square.
    final chipsFirst = widget.chips.isNotEmpty;
    final padStart = chipsFirst ? padY : metrics.controlPaddingX;
    final chipRadius = math.max(
      radii.item,
      CoilShape.nested(math.min(look.radius!, look.minHeight! / 2), padY),
    );

    Motion colorMotion(CoilInputTrack<Object> track) => CoilTheme.trackMotionOf(
      context,
      track,
      instance: null,
      styled: look.motions,
      token: motion.fade,
      spatial: false,
    );

    Widget decorate(BuildContext context, Widget field) => ListenableBuilder(
      listenable: _states,
      builder: (context, child) {
        final states = _states.value;
        final focused = states.contains(WidgetState.focused);
        final hovered = widget.enabled && states.contains(WidgetState.hovered);
        final resolved = {
          if (focused) WidgetState.focused,
          if (hovered) WidgetState.hovered,
          if (invalid) WidgetState.error,
        };
        final border = look.border!.resolve(resolved)!;
        final fill = look.fill!.resolve(resolved)!;
        return TrackBuilder(
          initialValues: [
            CoilInputTrack.border.value(border),
            CoilInputTrack.fill.value(fill),
          ],
          animations: [
            CoilInputTrack.border([
              .to(border, motion: colorMotion(CoilInputTrack.border)),
            ]),
            CoilInputTrack.fill([
              .to(fill, motion: colorMotion(CoilInputTrack.fill)),
            ]),
          ],
          builder: (context, value, child) => Container(
            constraints: BoxConstraints(minHeight: look.minHeight!),
            decoration: CoilRelief.decorate(
              ShapeDecoration(
                color: value(CoilInputTrack.fill),
                shape: RoundedSuperellipseBorder(
                  borderRadius: radius,
                  side: BorderSide(color: value(CoilInputTrack.border)),
                ),
              ),
              CoilTheme.reliefOf(
                context,
                CoilReliefRole.field,
                override: look.plasticity,
                hover: hovered ? 1 : 0,
                enabled: widget.enabled,
              ),
            ),
            child: child,
          ),
          child: child,
        );
      },
      // Every edge measure loses the 1 px border it sits inside.
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: math.max(0, padStart - 1),
          end: metrics.controlPaddingX - 1,
          top: math.max(0, padY - 1),
          bottom: math.max(0, padY - 1),
        ),
        // The height springs as a chip wraps onto a new row; a window
        // resize that rewraps the chips snaps (MotionSize).
        child: MotionSize(
          motion: motion.quick,
          alignment: AlignmentDirectional.topStart,
          debugLabel: 'CoilMultiCombobox.height',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: metrics.gap,
            children: [
              Expanded(
                child: ComboboxChipScope(
                  radius: chipRadius,
                  child: ComboboxChipsRun(
                    spacing: metrics.size == CoilSize.compact ? 4 : 6,
                    runSpacing: metrics.size == CoilSize.compact ? 4 : 6,
                    // Below this the text starts a row of its own.
                    minFieldExtent: lineHeight * 1.5,
                    rowExtent: rowExtent,
                    fieldIndent: metrics.controlPaddingX - padStart,
                    children: [...widget.chips, field],
                  ),
                ),
              ),
              if (widget.trailing case final trailing?)
                // A box as tall as the first row keeps the chevron
                // centered on it while the chips below it wrap.
                SizedBox(
                  height: rowExtent,
                  child: Center(
                    child: IconTheme(
                      data: IconThemeData(
                        size: metrics.iconSize,
                        applyTextScaling: true,
                        color: look.placeholder,
                        weight: CoilIconWeight.rest,
                      ),
                      child: trailing,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return CoilFieldControl(
      onLabelTap: widget.enabled ? _focusFromLabel : null,
      child: CoilInteractionDetector(
        states: _states,
        enabled: widget.enabled,
        trackPress: false,
        child: Opacity(
          opacity: widget.enabled ? 1 : metrics.disabledOpacity,
          child: CoilTextFieldCore(
            controller: widget.controller,
            focusNode: widget.focusNode,
            placeholder: widget.placeholder,
            placeholderColor: look.placeholder,
            style: textStyle,
            strutStyle: StrutStyle.fromTextStyle(
              textStyle,
              forceStrutHeight: true,
            ),
            cursorColor: look.cursorColor,
            cursorWidth: look.cursorWidth!,
            selectionColor: look.selectionColor,
            enabled: widget.enabled,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            keyboardAppearance: theme.brightness,
            scrollPadding: const EdgeInsets.all(16),
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onTap: widget.onTap,
            shortcuts: widget.shortcuts,
            decorationBuilder: decorate,
          ),
        ),
      ),
    );
  }
}

/// The corner radius of the chips in a [ComboboxChipsField].
class ComboboxChipScope extends InheritedWidget {
  /// Gives the chips below a corner radius.
  const ComboboxChipScope({
    required this.radius,
    required super.child,
    super.key,
  });

  /// The chips' corner radius.
  final double radius;

  /// The radius of the chips in the field around [context], if any.
  static double? radiusOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ComboboxChipScope>()?.radius;

  @override
  bool updateShouldNotify(ComboboxChipScope oldWidget) =>
      oldWidget.radius != radius;
}

/// Lays chips out in runs and gives the text the rest of the last run.
///
/// The children are the chips in order, then the text. A chip that doesn't
/// fit the row starts a new one; the text follows the last chip and takes
/// the width that's left, unless less than [minFieldExtent] is left, when it
/// starts a row of its own, [fieldIndent] in from its start. Every run is
/// at least [rowExtent] tall and its children center in it.
class ComboboxChipsRun extends MultiChildRenderObjectWidget {
  /// Creates the run layout.
  const ComboboxChipsRun({
    required this.spacing,
    required this.runSpacing,
    required this.minFieldExtent,
    required this.rowExtent,
    required super.children,
    super.key,
    this.fieldIndent = 0,
  });

  /// How far in the text starts when it starts a row of its own.
  final double fieldIndent;

  /// The gap between two children on a row.
  final double spacing;

  /// The gap between two rows.
  final double runSpacing;

  /// The narrowest the text gets before it starts its own row.
  final double minFieldExtent;

  /// The least a row is tall.
  final double rowExtent;

  @override
  RenderComboboxChipsRun createRenderObject(BuildContext context) =>
      RenderComboboxChipsRun(
        spacing: spacing,
        runSpacing: runSpacing,
        minFieldExtent: minFieldExtent,
        rowExtent: rowExtent,
        fieldIndent: fieldIndent,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderComboboxChipsRun renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..minFieldExtent = minFieldExtent
      ..rowExtent = rowExtent
      ..fieldIndent = fieldIndent
      ..textDirection = Directionality.of(context);
  }
}

/// The parent data of a [RenderComboboxChipsRun]'s child.
class ComboboxChipsParentData extends ContainerBoxParentData<RenderBox> {}

/// A run of chips with the text last. See [ComboboxChipsRun].
class RenderComboboxChipsRun extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, ComboboxChipsParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, ComboboxChipsParentData> {
  /// Creates the render object.
  RenderComboboxChipsRun({
    required double spacing,
    required double runSpacing,
    required double minFieldExtent,
    required double rowExtent,
    required TextDirection textDirection,
    double fieldIndent = 0,
  }) : _fieldIndent = fieldIndent,
       _spacing = spacing,
       _runSpacing = runSpacing,
       _minFieldExtent = minFieldExtent,
       _rowExtent = rowExtent,
       _textDirection = textDirection;

  double _spacing;

  /// The gap between two children on a row.
  double get spacing => _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  double _runSpacing;

  /// The gap between two rows.
  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (value == _runSpacing) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  double _minFieldExtent;

  /// The narrowest the text gets before it starts its own row.
  double get minFieldExtent => _minFieldExtent;
  set minFieldExtent(double value) {
    if (value == _minFieldExtent) return;
    _minFieldExtent = value;
    markNeedsLayout();
  }

  double _rowExtent;

  /// The least a row is tall.
  double get rowExtent => _rowExtent;
  set rowExtent(double value) {
    if (value == _rowExtent) return;
    _rowExtent = value;
    markNeedsLayout();
  }

  double _fieldIndent;

  /// How far in the text starts when it starts a row of its own.
  double get fieldIndent => _fieldIndent;
  set fieldIndent(double value) {
    if (value == _fieldIndent) return;
    _fieldIndent = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;

  /// The reading direction the rows run in.
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ComboboxChipsParentData) {
      child.parentData = ComboboxChipsParentData();
    }
  }

  List<RenderBox> get _children {
    final children = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      children.add(child);
      child = childAfter(child);
    }
    return children;
  }

  /// The widest a chip gets: below that every row holds one chip.
  @override
  double computeMinIntrinsicWidth(double height) {
    var widest = minFieldExtent;
    for (final chip in _children..removeLast()) {
      widest = math.max(widest, chip.getMaxIntrinsicWidth(double.infinity));
    }
    return widest;
  }

  /// Every chip and the text on one row.
  @override
  double computeMaxIntrinsicWidth(double height) {
    final children = _children;
    final field = children.removeLast();
    var width = math.max(
      minFieldExtent,
      field.getMaxIntrinsicWidth(double.infinity),
    );
    for (final chip in children) {
      width += chip.getMaxIntrinsicWidth(double.infinity) + spacing;
    }
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _layout(
    BoxConstraints(maxWidth: width),
    ChildLayoutHelper.dryLayoutChild,
  ).size.height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _layout(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  void performLayout() {
    final layout = _layout(constraints, ChildLayoutHelper.layoutChild);
    size = layout.size;
    final rtl = textDirection == TextDirection.rtl;
    for (final (child, offset) in layout.offsets) {
      (child.parentData! as ComboboxChipsParentData).offset = rtl
          ? Offset(size.width - offset.dx - child.size.width, offset.dy)
          : offset;
    }
  }

  /// Lays the chips out in runs, then the text in what's left of the last
  /// one. Offsets run left to right; [performLayout] mirrors them.
  ({Size size, List<(RenderBox, Offset)> offsets}) _layout(
    BoxConstraints constraints,
    Size Function(RenderBox, BoxConstraints) layoutChild,
  ) {
    final children = _children;
    final field = children.removeLast();
    final bounded = constraints.hasBoundedWidth;
    final maxWidth = bounded ? constraints.maxWidth : double.infinity;

    // The chips, in runs. A run holds its children's widths; the text joins
    // the last one.
    final runs = <List<(RenderBox, Size)>>[<(RenderBox, Size)>[]];
    var x = 0.0;
    for (final chip in children) {
      final size = layoutChild(chip, BoxConstraints(maxWidth: maxWidth));
      final start = runs.last.isEmpty ? 0.0 : x + spacing;
      if (runs.last.isNotEmpty && start + size.width > maxWidth) {
        runs.add([(chip, size)]);
        x = size.width;
      } else {
        runs.last.add((chip, size));
        x = start + size.width;
      }
    }

    // The text takes the rest of the last run, or a run of its own when too
    // little is left of it.
    final used = runs.last.isEmpty ? fieldIndent : x + spacing;
    var fieldWidth = bounded
        ? math.max(0, maxWidth - used).toDouble()
        : minFieldExtent;
    if (bounded && fieldWidth < minFieldExtent && runs.last.isNotEmpty) {
      runs.add([]);
      fieldWidth = math.max(0, maxWidth - fieldIndent).toDouble();
    }
    final fieldSize = layoutChild(
      field,
      BoxConstraints.tightFor(width: fieldWidth),
    );
    runs.last.add((field, fieldSize));

    // Place every run, its children centered in it.
    final offsets = <(RenderBox, Offset)>[];
    var y = 0.0;
    var width = 0.0;
    for (final run in runs) {
      var runExtent = rowExtent;
      var runWidth = 0.0;
      for (final (_, size) in run) {
        runExtent = math.max(runExtent, size.height);
        runWidth += size.width + spacing;
      }
      // Text alone on its row starts [fieldIndent] in.
      final indent = run.length == 1 && run.first.$1 == field
          ? fieldIndent
          : 0.0;
      width = math.max(width, math.max(0, indent + runWidth - spacing));
      var runX = indent;
      for (final (child, size) in run) {
        offsets.add((child, Offset(runX, y + (runExtent - size.height) / 2)));
        runX += size.width + spacing;
      }
      y += runExtent + runSpacing;
    }
    final height = math.max(0, y - runSpacing).toDouble();
    return (
      size: constraints.constrain(
        Size(bounded ? maxWidth : width, height),
      ),
      offsets: offsets,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
