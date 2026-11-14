import 'dart:math' as math;

import 'package:coil/dialog.dart';
import 'package:coil/foundation.dart';
import 'package:coil/scroll_area.dart';
import 'package:coil/select.dart';
import 'package:coil/sidebar.dart';
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
/// On the touch tier in a compact window it opens as a sheet, like a form
/// dialog. The future completes when the dialog closes.
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
/// section instead. Open it with [showCoilSettingsDialog].
class CoilSettingsDialog<T> extends StatefulWidget {
  /// Creates a settings dialog.
  const CoilSettingsDialog({
    required this.title,
    required this.sections,
    super.key,
    this.initialSection,
    this.onClose,
    this.closeLabel = 'Close',
  });

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

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final window = MediaQuery.sizeOf(context);
    return CoilDialogFrame(
      size: CoilDialogSize.xl,
      onClose: widget.onClose,
      closeLabel: widget.closeLabel,
      child: SizedBox(
        height: math.min(640, window.height - 64),
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
    final theme = CoilTheme.of(context);
    return Semantics(
      header: true,
      namesRoute: true,
      child: DefaultTextStyle(
        style: theme.typography.style(
          const CoilTypeStep(16, 22),
          color: theme.colors.foreground,
        ),
        child: title,
      ),
    );
  }
}

/// The picked section: its heading and description, then its content
/// scrolling below. Compact, the dialog's [title] and a [picker] lead.
class _Panel<T> extends StatelessWidget {
  const _Panel({required this.section, this.picker, this.title});

  final CoilSettingsSection<T> section;
  final Widget? picker;
  final Widget? title;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final description = section.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // The end clears the dialog's close button.
          padding: const EdgeInsetsDirectional.fromSTEB(24, 20, 48, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              if (title case final title?) ...[
                _Title(title),
                const SizedBox(height: 8),
                ?picker,
              ] else ...[
                DefaultTextStyle(
                  style: theme.typography.style(
                    const CoilTypeStep(16, 22),
                    color: theme.colors.foreground,
                  ),
                  child: section.label,
                ),
                if (description != null)
                  DefaultTextStyle(
                    style: theme.typography.style(
                      metrics.body,
                      color: theme.colors.mutedForeground,
                    ),
                    child: description,
                  ),
              ],
            ],
          ),
        ),
        Expanded(
          child: CoilScrollArea(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
            child: Builder(builder: section.builder),
          ),
        ),
      ],
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
class CoilSettingRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        spacing: 24,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                DefaultTextStyle(
                  style: theme.typography.style(
                    metrics.body,
                    color: theme.colors.foreground,
                  ),
                  child: label,
                ),
                if (description case final description?)
                  DefaultTextStyle(
                    style: theme.typography.style(
                      metrics.caption,
                      color: theme.colors.mutedForeground,
                    ),
                    child: description,
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
