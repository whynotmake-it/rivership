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
  form;

  /// The [CoilModalRoute] presentation for this kind: centered for a
  /// confirmation, null (sheet or centered, by tier and window) for a form.
  CoilModalPresentation? get presentation => switch (this) {
    confirmation => CoilModalPresentation.centered,
    form => null,
  };
}

/// Shows [builder]'s [CoilDialog] above the current route: pushes a
/// [CoilModalRoute].
///
/// A [CoilDialogKind.confirmation] is centered on every screen. A
/// [CoilDialogKind.form] opens as a sheet on the touch tier in a compact
/// window, and centered elsewhere. With [dismissible] false, the scrim, Esc,
/// back and dragging don't close it. The future completes with the value
/// passed to `Navigator.pop`.
///
/// To open a dialog from `Navigator.pages` or a router, show it in a
/// [CoilModalPage] with the same [CoilDialogKind.presentation].
Future<T?> showCoilDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  CoilDialogKind kind = CoilDialogKind.confirmation,
  bool dismissible = true,
  String? barrierLabel,
  CoilMotion? motion,
}) => showCoilModal<T>(
  context: context,
  presentation: kind.presentation,
  dismissible: dismissible,
  barrierLabel: barrierLabel,
  motion: motion,
  builder: builder,
);

/// A dialog panel: a [title], an optional [description], a [child] body and
/// [actions] trailing at the bottom.
///
/// Open it with [showCoilDialog], or in a [CoilModalRoute] or
/// [CoilModalPage]; the route decides whether it shows centered or as a
/// phone sheet, and the dialog fits itself to that. Put Cancel before the
/// primary action in [actions]. Give [onClose] to show a close button in
/// the corner.
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
    final sheet =
        CoilModalRoute.presentationOf(context) == CoilModalPresentation.sheet;

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

    return CoilDialogFrame(
      onClose: onClose,
      closeLabel: closeLabel,
      size: size,
      style: style,
      child: Padding(padding: EdgeInsets.all(look.padding!), child: body),
    );
  }
}

/// The panel a [CoilDialog] sits in, without its layout: the raised
/// surface, the width for [size], and a close button in the corner when
/// [onClose] is given.
///
/// Use it with [showCoilDialog] for a dialog whose content isn't a title,
/// a body and actions, such as a settings dialog with its own navigation.
/// [child] fills the panel edge to edge. Where [showCoilDialog] opens a
/// phone sheet, the frame is the sheet's panel instead, and [child] lays
/// out below the grabber.
class CoilDialogFrame extends StatelessWidget {
  /// Creates a dialog frame.
  const CoilDialogFrame({
    required this.child,
    super.key,
    this.onClose,
    this.closeLabel = 'Close',
    this.size = CoilDialogSize.sm,
    this.style,
  });

  /// The content, edge to edge.
  final Widget child;

  /// Shows a close button that calls this.
  final VoidCallback? onClose;

  /// The close button's label for screen readers.
  final String closeLabel;

  /// How wide the frame gets.
  final CoilDialogSize size;

  /// Overrides the theme's dialog style.
  final CoilDialogStyle? style;

  @override
  Widget build(BuildContext context) {
    if (CoilModalRoute.presentationOf(context) == CoilModalPresentation.sheet) {
      return CoilSheetPanel(child: child);
    }
    final look = CoilDialogStyle.fallback(
      CoilTheme.of(context),
      CoilTheme.metricsOf(context),
    ).merge(CoilTheme.styleOf<CoilDialogStyle>(context)).merge(style);
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
                  child,
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
