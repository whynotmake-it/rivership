import 'dart:math' as math;

import 'package:coil/dialog.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/scroll_area.dart';
import 'package:coil/select.dart';
import 'package:coil/sidebar.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// One section of a [CoilSettingsDialog]: an entry in its sidebar and the
/// panel it shows.
@immutable
class CoilSettingsSection<T> {
  /// Describes a section.
  const CoilSettingsSection({
    required this.value,
    required this.label,
    required this.builder,
    this.semanticLabel,
    this.icon,
    this.description,
  });

  /// Identifies the section.
  final T value;

  /// The section's name, in the sidebar and as the panel's heading;
  /// usually a [Text].
  final Widget label;

  /// The section's name as text, for screen readers and the compact
  /// select. Null reads the text of a [Text] [label]; give it for any
  /// other widget.
  final String? semanticLabel;

  String get _text => switch (semanticLabel ?? label) {
    final String text => text,
    Text(:final data?) => data,
    Text(:final textSpan?) => textSpan.toPlainText(),
    RichText(:final text) => text.toPlainText(),
    _ => '',
  };

  /// A glyph before the label, styled by [IconTheme].
  final Widget? icon;

  /// A line under the panel's heading, styled by [DefaultTextStyle].
  final Widget? description;

  /// Builds the panel's content, usually a [CoilSettingsList].
  final WidgetBuilder builder;
}

/// Shows a [CoilSettingsDialog] above the current route.
///
/// It's a form dialog: on the touch tier in a compact window it opens as a
/// sheet. The close button pops it. The future completes when it closes.
Future<void> showCoilSettingsDialog<T>({
  required BuildContext context,
  required Widget title,
  required List<CoilSettingsSection<T>> sections,
  T? initialSection,
  String closeLabel = 'Close',
  CoilMotion? motion,
}) => showCoilDialog<void>(
  context: context,
  kind: CoilDialogKind.form,
  motion: motion,
  builder: (context) => CoilSettingsDialog<T>(
    title: title,
    sections: sections,
    initialSection: initialSection,
    closeLabel: closeLabel,
    onClose: () => Navigator.of(context).pop(),
  ),
);

/// A settings dialog: a sidebar of [sections] beside a scrolling panel
/// for the picked one.
///
/// The sidebar is a [CoilSidebarScaffold] that doesn't fold. Below 600
/// wide it hides and a [CoilSelect] at the top of the panel picks the
/// section instead. Open it with [showCoilSettingsDialog], or from
/// `Navigator.pages` in a [CoilModalPage], with [onClose] popping it.
class CoilSettingsDialog<T> extends StatefulWidget {
  /// Creates a settings dialog.
  const CoilSettingsDialog({
    required this.title,
    required this.sections,
    super.key,
    this.initialSection,
    this.onClose,
    this.closeLabel = 'Close',
  }) : assert(sections.length > 0, 'CoilSettingsDialog needs a section');

  /// The dialog's title, above the sections; usually a [Text]. It names
  /// the dialog for screen readers.
  final Widget title;

  /// The sections, in order.
  final List<CoilSettingsSection<T>> sections;

  /// The section shown first; the first one when null.
  final T? initialSection;

  /// Shows a close button that calls this.
  final VoidCallback? onClose;

  /// The close button's label for screen readers.
  final String closeLabel;

  /// Below this width the sidebar gives way to a select.
  static const compactWidth = 600.0;

  @override
  State<CoilSettingsDialog<T>> createState() => _CoilSettingsDialogState<T>();
}

class _CoilSettingsDialogState<T> extends State<CoilSettingsDialog<T>> {
  late T _section = widget.initialSection ?? widget.sections.first.value;
  final _sidebar = CoilSidebarController(width: 208);

  @override
  void dispose() {
    _sidebar.dispose();
    super.dispose();
  }

  CoilSettingsSection<T> get _current => widget.sections.firstWhere(
    (section) => section.value == _section,
    orElse: () => widget.sections.first,
  );

  void _pick(T value) => setState(() => _section = value);

  /// Up to 640 tall, leaving 32 above and below in a short window.
  double _height(Size window) => math.max(0, math.min(640, window.height - 64));

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final window = MediaQuery.sizeOf(context);
    if (CoilModalRoute.presentationOf(context)?.usesSheetPanel ?? false) {
      // The title goes in the sheet's header, on the close button's line.
      return CoilSheetPanel(
        title: Semantics(namesRoute: true, child: widget.title),
        close: CoilSheetCloseButton(
          onPressed: widget.onClose,
          semanticLabel: widget.closeLabel,
        ),
        child: SizedBox(
          height: _height(window),
          child: _Panel(section: _current, picker: _picker(), sheet: true),
        ),
      );
    }
    return CoilDialogFrame(
      size: CoilDialogSize.xl,
      onClose: widget.onClose,
      closeLabel: widget.closeLabel,
      child: SizedBox(
        height: _height(window),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < CoilSettingsDialog.compactWidth) {
              return _Panel(
                section: _current,
                picker: _picker(),
                title: widget.title,
              );
            }
            return CoilSidebarScaffold(
              controller: _sidebar,
              collapsible: CoilSidebarCollapsible.none,
              style: CoilSidebarStyle(
                background: CoilColorMix.withTransparent(
                  theme.colors.overlay,
                  0.03,
                ),
                edgeColor: const Color(0x00000000),
              ),
              sidebar: CoilSidebar(
                header: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 12, 8, 0),
                  child: _Title(widget.title),
                ),
                children: [
                  CoilSidebarGroup(
                    child: CoilSidebarMenu(
                      focus: CoilSidebarMenuFocus.highlight,
                      items: [
                        for (final section in widget.sections)
                          CoilSidebarItem(
                            label: section.label,
                            semanticLabel: section._text,
                            leading: section.icon,
                            selected: section.value == _section,
                            onPressed: () => _pick(section.value),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              body: _Panel(section: _current),
            );
          },
        ),
      ),
    );
  }

  Widget _picker() => CoilSelect<T>(
    options: [
      for (final section in widget.sections)
        CoilOption(
          value: section.value,
          label: section.label,
          searchText: section._text,
          icon: section.icon,
        ),
    ],
    value: _section,
    onChanged: _pick,
  );
}

class _Title extends StatelessWidget {
  const _Title(this.title);

  final Widget title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      namesRoute: true,
      child: DefaultTextStyle(
        style: _heading(CoilTheme.textOf(context)),
        child: title,
      ),
    );
  }
}

/// The dialog's and a section's heading: the title role, at the body's
/// weight.
TextStyle _heading(CoilTextTheme text) =>
    text.title.copyWith(fontWeight: text.body.fontWeight);

/// The picked section: its heading and description, then its content, all
/// scrolling. Compact, the dialog's [title] and a [picker] lead.
class _Panel<T> extends StatelessWidget {
  const _Panel({
    required this.section,
    this.picker,
    this.title,
    this.sheet = false,
  });

  final CoilSettingsSection<T> section;
  final Widget? picker;
  final Widget? title;

  /// In a sheet, under its header: the rows' text inset (16) and no room
  /// for a close button.
  final bool sheet;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final description = section.description;
    // The heading scrolls with the content, so a long title, a long
    // description or large text never pushes the content out of a short
    // window.
    return CoilScrollArea(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(
          sheet ? 16 : 24,
          0,
          sheet ? 16 : 24,
          24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              // The end clears the dialog's close button; a sheet's is in
              // its header.
              padding: sheet
                  ? const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 16)
                  : const EdgeInsetsDirectional.fromSTEB(0, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  if (title case final title?) ...[
                    _Title(title),
                    const SizedBox(height: 8),
                  ],
                  if (picker case final picker?)
                    picker
                  else ...[
                    DefaultTextStyle(
                      style: _heading(text),
                      child: section.label,
                    ),
                    if (description != null)
                      DefaultTextStyle(
                        style: text.muted.body,
                        child: description,
                      ),
                  ],
                ],
              ),
            ),
            Builder(builder: section.builder),
          ],
        ),
      ),
    );
  }
}

/// Settings rows separated by hairlines.
class CoilSettingsList extends StatelessWidget {
  /// Creates a list of [children], usually [CoilSettingRow]s.
  const CoilSettingsList({required this.children, super.key});

  /// The rows.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final border = CoilTheme.of(context).colors.border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) SizedBox(height: 1, child: ColoredBox(color: border)),
          child,
        ],
      ],
    );
  }
}

/// One setting: a [label] and an optional [description] at the start, and
/// its control at the end.
///
/// Like a native settings row, a row with a toggle (a switch, a checkbox)
/// is one tap target: a tap anywhere in it toggles the control, and the
/// control shows hover and press while the row has them. A row with a
/// select, a slider or a button responds only on the control. Screen
/// readers hear the label and description with the control, so it needs no
/// `semanticLabel`. Put one control in a row.
class CoilSettingRow extends StatefulWidget {
  /// Creates a setting row.
  const CoilSettingRow({
    required this.label,
    required this.trailing,
    super.key,
    this.description,
  });

  /// The setting's name.
  final Widget label;

  /// A line under the label, muted.
  final Widget? description;

  /// The control, such as a switch or a select.
  final Widget trailing;

  @override
  State<CoilSettingRow> createState() => _CoilSettingRowState();
}

class _CoilSettingRowState extends State<CoilSettingRow> {
  final _target = CoilFieldLabelTarget();

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final description = widget.description;
    return CoilFieldScope(
      invalid: false,
      isRequired: false,
      labelTarget: _target,
      // One node: the control's role and value, read with the label and
      // description.
      child: MergeSemantics(
        child: CoilFieldRow(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            // The control keeps its natural width up to half the row; a
            // wider one (a long button label) ellipsizes there.
            child: _SettingRowLayout(
              spacing: 24,
              label: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  DefaultTextStyle(style: text.body, child: widget.label),
                  if (description != null)
                    DefaultTextStyle(
                      style: text.muted.caption,
                      child: description,
                    ),
                ],
              ),
              control: widget.trailing,
            ),
          ),
        ),
      ),
    );
  }
}

enum _SettingRowSlot { label, control }

/// A setting row's label and control: the control at the end, at its
/// natural width up to half the row, and the label filling the rest, both
/// centered vertically.
///
/// A render object rather than a `LayoutBuilder`, so the row answers
/// intrinsic sizes (inside an `IntrinsicHeight`, a dialog that sizes to
/// its content).
class _SettingRowLayout
    extends SlottedMultiChildRenderObjectWidget<_SettingRowSlot, RenderBox> {
  const _SettingRowLayout({
    required this.label,
    required this.control,
    required this.spacing,
  });

  final Widget label;
  final Widget control;
  final double spacing;

  @override
  Iterable<_SettingRowSlot> get slots => _SettingRowSlot.values;

  @override
  Widget childForSlot(_SettingRowSlot slot) => switch (slot) {
    _SettingRowSlot.label => label,
    _SettingRowSlot.control => control,
  };

  @override
  _RenderSettingRow createRenderObject(BuildContext context) =>
      _RenderSettingRow(spacing, Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSettingRow renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..textDirection = Directionality.of(context);
  }
}

class _RenderSettingRow extends RenderBox
    with SlottedContainerRenderObjectMixin<_SettingRowSlot, RenderBox> {
  _RenderSettingRow(this._spacing, this._textDirection);

  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _label => childForSlot(_SettingRowSlot.label)!;
  RenderBox get _control => childForSlot(_SettingRowSlot.control)!;

  /// The widest the control gets in a row [width] wide.
  static double _controlMax(double width) => width / 2;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _label.getMinIntrinsicWidth(height) +
      spacing +
      _control.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _label.getMaxIntrinsicWidth(height) +
      spacing +
      _control.getMaxIntrinsicWidth(height);

  /// The height at [width] from the children's intrinsic heights.
  double _intrinsicHeight(
    double width,
    double Function(RenderBox child, double width) heightAt,
  ) {
    if (!width.isFinite) {
      return math.max(
        heightAt(_label, double.infinity),
        heightAt(_control, double.infinity),
      );
    }
    final control = math.min(
      _control.getMaxIntrinsicWidth(double.infinity),
      _controlMax(width),
    );
    final label = math.max(0, width - control - spacing).toDouble();
    return math.max(heightAt(_label, label), heightAt(_control, control));
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (child, w) => child.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (child, w) => child.getMaxIntrinsicHeight(w));

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _layout(constraints, ChildLayoutHelper.dryLayoutChild);

  @override
  void performLayout() {
    size = _layout(constraints, ChildLayoutHelper.layoutChild, place: true);
  }

  Size _layout(
    BoxConstraints constraints,
    ChildLayouter layoutChild, {
    bool place = false,
  }) {
    final width = constraints.maxWidth;
    final controlSize = layoutChild(
      _control,
      BoxConstraints(
        maxWidth: width.isFinite ? _controlMax(width) : double.infinity,
      ),
    );
    final labelWidth = width.isFinite
        ? math.max(0, width - controlSize.width - spacing).toDouble()
        : null;
    final labelSize = layoutChild(
      _label,
      labelWidth == null
          ? const BoxConstraints()
          : BoxConstraints.tightFor(width: labelWidth),
    );
    final size = constraints.constrain(
      Size(
        labelSize.width + spacing + controlSize.width,
        math.max(labelSize.height, controlSize.height),
      ),
    );
    if (!place) return size;
    final rtl = textDirection == TextDirection.rtl;
    void put(RenderBox child, Size childSize, double start) {
      (child.parentData! as BoxParentData).offset = Offset(
        rtl ? size.width - start - childSize.width : start,
        (size.height - childSize.height) / 2,
      );
    }

    put(_label, labelSize, 0);
    put(_control, controlSize, size.width - controlSize.width);
    return size;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final offset = (child.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, local) => child.hitTest(result, position: local),
      );
      if (hit) return true;
    }
    return false;
  }
}
