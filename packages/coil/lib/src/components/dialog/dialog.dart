import 'dart:math' as math;

import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/dialog/dialog_style.dart';
import 'package:flutter/widgets.dart';

/// What a dialog asks of the user, which decides how it opens on a phone.
enum CoilDialogKind {
  /// A short decision: a title, a sentence and buttons. Centered everywhere.
  confirmation,

  /// A dialog with fields. On a phone it opens as a sheet that can be dragged
  /// away, with the actions stacked full width.
  form,
}

/// Shows [builder]'s [CoilDialog] above the current route.
///
/// A [CoilDialogKind.confirmation] is centered on every screen. A
/// [CoilDialogKind.form] opens as a sheet on the touch tier in a compact
/// window, and centered elsewhere. With [dismissible] false, the scrim, Esc,
/// back and dragging don't close it. The future completes with the value
/// passed to `Navigator.pop`.
Future<T?> showCoilDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  CoilDialogKind kind = CoilDialogKind.confirmation,
  bool dismissible = true,
  String? barrierLabel,
  CoilMotion? motion,
}) {
  final sheet =
      kind == CoilDialogKind.form &&
      CoilTheme.tierOf(context) == CoilTier.touch &&
      MediaQuery.sizeOf(context).width < CoilAdaptivePopup.compactWidth;
  return showCoilModal<T>(
    context: context,
    presentation: sheet
        ? CoilModalPresentation.sheet
        : CoilModalPresentation.centered,
    dismissible: dismissible,
    barrierLabel: barrierLabel,
    motion: motion,
    builder: (context) => _CoilDialogPresentation(
      sheet: sheet,
      child: Builder(builder: builder),
    ),
  );
}

/// A dialog panel: a [title], an optional [description], a [child] body and
/// [actions] trailing at the bottom.
///
/// Open it with [showCoilDialog], which also decides whether it shows
/// centered or as a phone sheet. Put Cancel before the primary action in
/// [actions]. Give [onClose] to show a close button in the corner.
class CoilDialog extends StatelessWidget {
  /// Creates a dialog.
  const CoilDialog({
    required this.title,
    super.key,
    this.description,
    this.child,
    this.actions = const [],
    this.onClose,
    this.closeLabel = 'Close',
    this.size = CoilDialogSize.sm,
    this.style,
  });

  /// The title; also the dialog's name for screen readers.
  final Widget title;

  /// One or two sentences under the title.
  final Widget? description;

  /// The body.
  final Widget? child;

  /// The buttons, Cancel first and the primary action last.
  final List<Widget> actions;

  /// Shows a close button that calls this.
  final VoidCallback? onClose;

  /// The close button's label for screen readers.
  final String closeLabel;

  /// How wide the dialog gets.
  final CoilDialogSize size;

  /// Overrides the theme's dialog style.
  final CoilDialogStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final look = CoilDialogStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilDialogStyle>(context)).merge(style);
    final sheet = _CoilDialogPresentation.isSheet(context);

    final titleText = Semantics(
      header: true,
      namesRoute: true,
      child: DefaultTextStyle(style: look.titleStyle!, child: title),
    );
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: look.headerGap!,
      children: [
        if (!sheet) titleText,
        if (description case final description?)
          DefaultTextStyle(style: look.descriptionStyle!, child: description),
      ],
    );
    final hasHeader = !sheet || description != null;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: look.headerSpacing!,
      children: [
        if (hasHeader) header,
        ?child,
        // A phone sheet stacks the actions full width, primary first.
        if (actions.isNotEmpty && sheet)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: look.actionGap!,
            children: actions.reversed.toList(),
          ),
        if (actions.isNotEmpty && !sheet)
          Wrap(
            alignment: WrapAlignment.end,
            spacing: look.actionGap!,
            runSpacing: look.actionGap!,
            children: actions,
          ),
      ],
    );

    if (sheet) {
      return CoilSheetPanel(
        title: titleText,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(look.padding!),
          child: body,
        ),
      );
    }

    final radius = BorderRadius.circular(look.radius!);
    final window = MediaQuery.sizeOf(context);
    final width = math.min(
      size.maxWidth,
      window.width - 2 * look.windowMargin!,
    );
    return SafeArea(
      child: Center(
        child: SizedBox(
          width: width,
          child: CoilSurface(
            offset: CoilSurface.dialogOffset,
            borderRadius: radius,
            child: ClipRSuperellipse(
              borderRadius: radius,
              child: Stack(
                children: [
                  Padding(padding: EdgeInsets.all(look.padding!), child: body),
                  if (onClose case final onClose?)
                    PositionedDirectional(
                      top: 12,
                      end: 12,
                      child: CoilButton.icon(
                        variant: CoilButtonVariant.ghost,
                        size: CoilSize.compact,
                        onPressed: onClose,
                        semanticLabel: closeLabel,
                        icon: const CoilDrawnGlyph(CoilGlyph.cross),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tells a [CoilDialog] whether it shows as a phone sheet.
class _CoilDialogPresentation extends InheritedWidget {
  const _CoilDialogPresentation({required this.sheet, required super.child});

  final bool sheet;

  static bool isSheet(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_CoilDialogPresentation>()
          ?.sheet ??
      false;

  @override
  bool updateShouldNotify(_CoilDialogPresentation oldWidget) =>
      oldWidget.sheet != sheet;
}
