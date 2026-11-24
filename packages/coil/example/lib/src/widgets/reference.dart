import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

/// One thing worth knowing about a component, under a short topic such as
/// "Keyboard", "Touch" or "Motion".
@immutable
class CatalogNote {
  const CatalogNote(this.topic, this.text);

  /// One or two words.
  final String topic;

  /// A sentence or two: what happens, never how it's built.
  final String text;
}

/// A page's notes: the topic in a narrow column beside its text on a wide
/// page, above it on a narrow one. No boxes; the rhythm does the work.
class NotesSection extends StatelessWidget {
  const NotesSection({required this.notes, super.key});

  final List<CatalogNote> notes;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final touch = CoilTheme.tierOf(context) == CoilTier.touch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Worth knowing',
            style: text.subtitle.copyWith(fontWeight: text.emphasis),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 520;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, note) in notes.indexed) ...[
                  if (i > 0) SizedBox(height: touch ? 16 : 12),
                  MergeSemantics(
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 128,
                                child: Text(
                                  note.topic,
                                  style: text.body.copyWith(
                                    fontWeight: text.emphasis,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(note.text, style: text.muted.body),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.topic,
                                style: text.body.copyWith(
                                  fontWeight: text.emphasis,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(note.text, style: text.muted.body),
                            ],
                          ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The few lines of code that make a page's hero, in a quiet code block
/// with a copy button. Lines don't wrap; a long one scrolls sideways.
class UsageSnippet extends StatefulWidget {
  const UsageSnippet({required this.code, super.key});

  /// Dart, formatted as `dart format` would.
  final String code;

  @override
  State<UsageSnippet> createState() => _UsageSnippetState();
}

class _UsageSnippetState extends State<UsageSnippet> {
  final _copy = CoilCopyController();

  @override
  void dispose() {
    _copy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final text = CoilTheme.textOf(context);
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).container);
    final code = text.caption.copyWith(
      fontFamily: 'JetBrains Mono',
      // The mono face sets wider than the UI font; one step down keeps
      // the snippet's measure close to the prose around it.
      fontSize: text.caption.fontSize! - 0.5,
      height: 20 / (text.caption.fontSize! - 0.5),
      letterSpacing: 0,
      // Code shows the characters typed: no `=>` drawn as an arrow.
      fontFeatures: const [
        FontFeature.disable('calt'),
        FontFeature.disable('liga'),
      ],
      fontVariations: const [FontVariation('wght', 420)],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Usage',
                  style: text.subtitle.copyWith(fontWeight: text.emphasis),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.muted,
            shape: RoundedSuperellipseBorder(
              borderRadius: radius,
              side: BorderSide(color: colors.border),
            ),
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 56, 14),
                child: Directionality(
                  // Code reads left to right, also in an RTL preview.
                  textDirection: TextDirection.ltr,
                  child: Text(widget.code.trim(), style: code),
                ),
              ),
              PositionedDirectional(
                top: 6,
                end: 6,
                child: CoilTooltip(
                  message: const Text('Copy code'),
                  child: CoilButton.icon(
                    variant: CoilButtonVariant.ghost,
                    size: CoilSize.compact,
                    semanticLabel: 'Copy code',
                    icon: CoilCopyGlyph.listening(controller: _copy),
                    onPressed: () => unawaited(
                      _copy.copy(widget.code.trim(), context: context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The hero: the component at its best, in the place it would live in an
/// app, on a stage with more room than the sections below.
class HeroStage extends StatelessWidget {
  const HeroStage({required this.child, super.key, this.padding});

  final Widget child;

  /// Null: 24 on a wide page, 16 on a phone.
  final double? padding;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return DemoStage(padding: padding ?? (narrow ? 16 : 24), child: child);
  }
}

/// A live control above a demo: a short label and a compact coil control.
/// Use [DemoControls] to lay them out.
class DemoControl extends StatelessWidget {
  const DemoControl({required this.label, required this.child, super.key});

  /// A choice among a few values: compact tabs while the labels are few
  /// and short enough to fit a phone, else a compact select.
  static Widget choice<T extends Object>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T value) labelOf,
    required ValueChanged<T> onChanged,
  }) => DemoControl(
    label: label,
    child:
        values.length <= 4 &&
            values.fold(0, (sum, v) => sum + labelOf(v).length) <= 24
        ? CoilTabs<T>(
            size: CoilSize.compact,
            value: value,
            onChanged: onChanged,
            tabs: [
              for (final v in values)
                CoilTab(value: v, label: Text(labelOf(v))),
            ],
          )
        : ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 140, maxWidth: 180),
            child: CoilSelect<T>(
              size: CoilSize.compact,
              value: value,
              onChanged: onChanged,
              options: [
                for (final v in values)
                  CoilOption(
                    value: v,
                    label: Text(labelOf(v)),
                    searchText: labelOf(v),
                  ),
              ],
            ),
          ),
  );

  /// An on/off option, as a compact switch under its label.
  static Widget toggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => DemoControl(
    label: label,
    child: CoilSwitch(
      size: CoilSize.compact,
      value: value,
      onChanged: onChanged,
      semanticLabel: label,
    ),
  );

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    // Every control sits in a compact control's height, so a row of them
    // lines up whatever each one is.
    final height = CoilTheme.of(context).metrics
        .resolve(CoilTheme.tierOf(context), CoilSize.compact)
        .controlHeight;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.muted.caption),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// A row of [DemoControl]s that wraps on a narrow page.
class DemoControls extends StatelessWidget {
  const DemoControls({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 20,
    runSpacing: 12,
    children: children,
  );
}
