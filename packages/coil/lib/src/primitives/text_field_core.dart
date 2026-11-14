import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/focus_within.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show
        CupertinoColors,
        CupertinoLocalizations,
        CupertinoTheme,
        DefaultCupertinoLocalizations,
        cupertinoDesktopTextSelectionHandleControls,
        cupertinoTextSelectionHandleControls;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart'
    show
        AdaptiveTextSelectionToolbar,
        DefaultMaterialLocalizations,
        MaterialLocalizations,
        TextMagnifier,
        TextSelectionTheme,
        desktopTextSelectionHandleControls,
        iOSHorizontalOffset,
        materialTextSelectionHandleControls;

/// Wraps the editable text of a [CoilTextFieldCore] in a component's chrome
/// (border, padding, leading and trailing slots).
///
/// `field` is the editable text with its placeholder. The selection
/// gestures cover everything returned, so a tap in the padding lands in the
/// field, as in Flutter's `TextField`.
typedef CoilTextFieldDecorationBuilder =
    Widget Function(BuildContext context, Widget field);

/// The one text-editing primitive in coil: an [EditableText] with the
/// platform's gestures, selection handles, magnifier and context menu.
///
/// Components (`CoilInput`, and later the combobox and search fields) draw
/// their look around it with [decorationBuilder] and never build an
/// [EditableText] themselves.
///
/// Platform behavior, chosen like Flutter's `TextField`:
///
/// * Gestures come from a [TextSelectionGestureDetectorBuilder]: tap to
///   place the caret, double-tap / long-press / drag to select, per
///   platform.
/// * Selection handles: iOS-style on iOS, Material on Android and Fuchsia,
///   macOS desktop style on macOS, desktop style on Windows and Linux. The
///   magnifier shows on iOS and Android.
/// * Context menu, native first: the iOS system edit menu
///   ([SystemContextMenu]) where the field supports it, the browser's own
///   menu on web (while [BrowserContextMenu.enabled]), and the platform's
///   Flutter-drawn toolbar otherwise. Under a plain [WidgetsApp] without
///   Material or Cupertino localizations, the toolbar's labels are English.
///
/// ## Shortcuts
///
/// [shortcuts] map keys to intents for the field's owner, such as Enter to
/// pick a combobox option or arrows to move its active item. Each intent
/// goes to its action in [actions], or else to the nearest ancestor
/// [Actions]. During an IME composition these shortcuts are off; see below.
///
/// ## Enter and IME composition
///
/// * Single-line ([maxLines] 1): Return is the keyboard's action
///   ([textInputAction], `done` by default) and calls [onSubmitted].
/// * Multi-line: Return inserts a newline. [onSubmitted] isn't called. A
///   composer that sends on Enter maps Enter in [shortcuts].
/// * While an IME composition is in progress, every shortcut reports
///   itself disabled, so Enter and the arrows reach the IME: Enter commits
///   the composition and nothing else, and arrows move in the candidate
///   list. [onSubmitted] only ever comes from the platform's text input
///   action, so it can't fire for an Enter the IME consumed.
class CoilTextFieldCore extends StatefulWidget {
  /// Creates a text field core.
  const CoilTextFieldCore({
    super.key,
    this.controller,
    this.focusNode,
    this.undoController,
    this.placeholder,
    this.placeholderColor,
    this.style,
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.cursorColor,
    this.cursorWidth = 2,
    this.cursorHeight,
    this.cursorRadius,
    this.selectionColor,
    this.selectionHandleColor,
    this.keyboardType,
    this.textInputAction,
    this.keyboardAppearance,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.obscuringCharacter = '•',
    this.scrollPadding = const EdgeInsets.all(20),
    this.scrollController,
    this.inputFormatters,
    this.autofillHints,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.shortcuts = const <ShortcutActivator, Intent>{},
    this.actions = const <Type, Action<Intent>>{},
    this.decorationBuilder,
  });

  /// The text controller; one is created if null.
  final TextEditingController? controller;

  /// The focus node; one is created if null.
  final FocusNode? focusNode;

  /// The undo history controller; [EditableText] creates one if null.
  final UndoHistoryController? undoController;

  /// Shown while the text is empty, in [style] with [placeholderColor].
  /// Usually a [Text].
  final Widget? placeholder;

  /// The placeholder's color. Defaults to the theme's
  /// `colors.mutedForeground`.
  final Color? placeholderColor;

  /// The text style. Defaults to the ambient [DefaultTextStyle].
  final TextStyle? style;

  /// The strut style of the text.
  final StrutStyle? strutStyle;

  /// How the text, and the placeholder, align horizontally.
  final TextAlign textAlign;

  /// The caret color. Defaults to the theme's `colors.foreground`.
  final Color? cursorColor;

  /// The caret width.
  final double cursorWidth;

  /// The caret height. Defaults to the height of the text itself (the
  /// font's ascent plus descent at this size), not the line box, so a caret
  /// in a roomy line stays as tall as the letters beside it.
  final double? cursorHeight;

  /// The caret's corner radius. Defaults to the platform's (rounded on
  /// Apple platforms).
  final Radius? cursorRadius;

  /// The selection highlight. Defaults to the theme's `colors.brand` at
  /// 30%. Painted only while the field has focus.
  final Color? selectionColor;

  /// The color of the touch selection handles. Defaults to [cursorColor].
  final Color? selectionHandleColor;

  /// The software keyboard type.
  final TextInputType? keyboardType;

  /// The software keyboard's action button.
  final TextInputAction? textInputAction;

  /// The software keyboard's brightness. Defaults to the theme's.
  final Brightness? keyboardAppearance;

  /// How the software keyboard capitalizes.
  final TextCapitalization textCapitalization;

  /// Whether the platform autocorrects. Off for obscured fields regardless.
  final bool autocorrect;

  /// Whether the keyboard offers suggestions. Off for obscured fields
  /// regardless.
  final bool enableSuggestions;

  /// The character shown for each obscured character.
  final String obscuringCharacter;

  /// The space kept between the field and the screen edges (and the
  /// software keyboard) when the field scrolls itself into view.
  final EdgeInsets scrollPadding;

  /// Scrolls a multi-line field's text. One is created if null.
  final ScrollController? scrollController;

  /// Input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// Autofill hints.
  final Iterable<String>? autofillHints;

  /// Hides the text (passwords).
  final bool obscureText;

  /// Whether the text can be selected but not changed.
  final bool readOnly;

  /// Whether the field accepts input, gestures and focus.
  final bool enabled;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// The minimum number of lines to size for.
  final int? minLines;

  /// The maximum number of lines; null for unlimited. 1 is single-line.
  ///
  /// A multi-line field grows from [minLines] to [maxLines] with its text
  /// and then scrolls. It defaults to the multi-line keyboard, and the
  /// keyboard's Return key inserts a newline ([TextInputAction.newline]).
  final int? maxLines;

  /// Called when the text changes, including during an IME composition.
  final ValueChanged<String>? onChanged;

  /// Called when the platform's text input action submits the field.
  final ValueChanged<String>? onSubmitted;

  /// Called when the user finishes editing, before [onSubmitted].
  final VoidCallback? onEditingComplete;

  /// Keys mapped to intents, disabled while an IME composition is in
  /// progress. See the class docs.
  final Map<ShortcutActivator, Intent> shortcuts;

  /// Actions for the intents in [shortcuts], by intent type. An intent
  /// without one here goes to the nearest ancestor [Actions].
  final Map<Type, Action<Intent>> actions;

  /// Draws the component's chrome around the field. Null shows the field
  /// alone.
  final CoilTextFieldDecorationBuilder? decorationBuilder;

  @override
  State<CoilTextFieldCore> createState() => _CoilTextFieldCoreState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('controller', controller, defaultValue: null))
      ..add(DiagnosticsProperty('focusNode', focusNode, defaultValue: null))
      ..add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'))
      ..add(FlagProperty('readOnly', value: readOnly, ifTrue: 'readOnly'))
      ..add(
        FlagProperty('obscureText', value: obscureText, ifTrue: 'obscured'),
      )
      ..add(IntProperty('maxLines', maxLines, defaultValue: 1));
  }
}

class _CoilTextFieldCoreState extends State<CoilTextFieldCore>
    implements TextSelectionGestureDetectorBuilderDelegate {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  late final _selectionGestures = TextSelectionGestureDetectorBuilder(
    delegate: this,
  );

  /// One composing-aware action per intent type in
  /// [CoilTextFieldCore.shortcuts].
  final _guards = <Type, _ComposingAwareAction>{};
  bool _composing = false;
  bool _showSelectionHandles = false;

  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool get selectionEnabled => widget.enabled;

  EditableTextState? get _editableText => editableTextKey.currentState;

  @override
  void initState() {
    super.initState();
    _focusNode
      ..addListener(_onFocusChanged)
      ..canRequestFocus = widget.enabled;
    _controller.addListener(_onValueChanged);
    _composing = _controller.value.composing.isValid;
  }

  @override
  void didUpdateWidget(CoilTextFieldCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onValueChanged);
      if (widget.controller != null) {
        _ownController?.dispose();
        _ownController = null;
      }
      _controller.addListener(_onValueChanged);
      _onValueChanged();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocusChanged);
      if (widget.focusNode != null) {
        _ownFocusNode?.dispose();
        _ownFocusNode = null;
      }
      _focusNode.addListener(_onFocusChanged);
    }
    _focusNode.canRequestFocus = widget.enabled;
    if (_focusNode.hasFocus &&
        widget.readOnly != oldWidget.readOnly &&
        widget.enabled &&
        _controller.selection.isCollapsed) {
      _showSelectionHandles = !widget.readOnly;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.removeListener(_onValueChanged);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    // The selection highlight shows only while focused.
    setState(() {});
  }

  void _onValueChanged() {
    final composing = _controller.value.composing.isValid;
    if (composing == _composing) return;
    _composing = composing;
    for (final guard in _guards.values) {
      guard.enabledChanged();
    }
  }

  bool _isComposing() => _controller.value.composing.isValid;

  Action<Intent>? _actionFor(Intent intent) =>
      widget.actions[intent.runtimeType] ??
      Actions.maybeFind<Intent>(context, intent: intent);

  Map<Type, Action<Intent>> _composingAwareActions() {
    final types = {
      for (final intent in widget.shortcuts.values) intent.runtimeType,
    };
    _guards.removeWhere((type, _) => !types.contains(type));
    for (final type in types) {
      _guards.putIfAbsent(
        type,
        () => _ComposingAwareAction(
          isComposing: _isComposing,
          resolve: _actionFor,
        ),
      );
    }
    return _guards;
  }

  // Mirrors TextField's rules for when touch handles show.
  bool _shouldShowSelectionHandles(SelectionChangedCause? cause) {
    if (!_selectionGestures.shouldShowSelectionToolbar ||
        !_selectionGestures.shouldShowSelectionHandles) {
      return false;
    }
    if (cause == SelectionChangedCause.keyboard) return false;
    if (widget.readOnly && _controller.selection.isCollapsed) return false;
    if (!widget.enabled) return false;
    if (cause == SelectionChangedCause.longPress ||
        cause == SelectionChangedCause.stylusHandwriting) {
      return true;
    }
    return _controller.text.isNotEmpty;
  }

  void _handleSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    final show = _shouldShowSelectionHandles(cause);
    if (show != _showSelectionHandles) {
      setState(() => _showSelectionHandles = show);
    }
    if (cause == SelectionChangedCause.longPress) {
      _editableText?.bringIntoView(selection.extent);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        if (cause == SelectionChangedCause.drag) _editableText?.hideToolbar();
      case TargetPlatform.iOS:
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        break;
    }
  }

  void _handleSelectionHandleTapped() {
    if (_controller.selection.isCollapsed) _editableText!.toggleToolbar();
  }

  void _requestKeyboard() {
    if (!_controller.selection.isValid) {
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
    _editableText?.requestKeyboard();
  }

  /// The height of [style]'s text without its line height: the font's own
  /// ascent plus descent, as the text engine reports it.
  static double _textHeight(TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(
        text: ' ',
        style: TextStyle(
          inherit: false,
          fontFamily: style.fontFamily,
          fontFamilyFallback: style.fontFamilyFallback,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          fontVariations: style.fontVariations,
        ),
      ),
      textScaler: scaler,
      textDirection: TextDirection.ltr,
    )..layout();
    final height = painter.preferredLineHeight;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final cursorColor = widget.cursorColor ?? colors.foreground;
    final selectionColor =
        widget.selectionColor ?? colors.brand.withValues(alpha: 0.3);
    final platform = _PlatformText.of(defaultTargetPlatform, context);

    Widget editable = EditableText(
      key: editableTextKey,
      controller: _controller,
      focusNode: _focusNode,
      undoController: widget.undoController,
      readOnly: widget.readOnly || !widget.enabled,
      obscureText: widget.obscureText,
      autofocus: widget.autofocus,
      style: style,
      strutStyle: widget.strutStyle,
      textAlign: widget.textAlign,
      textCapitalization: widget.textCapitalization,
      autocorrect: widget.autocorrect && !widget.obscureText,
      enableSuggestions: widget.enableSuggestions && !widget.obscureText,
      obscuringCharacter: widget.obscuringCharacter,
      scrollPadding: widget.scrollPadding,
      scrollController: widget.scrollController,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      cursorColor: cursorColor,
      backgroundCursorColor: CupertinoColors.inactiveGray,
      cursorWidth: widget.cursorWidth,
      cursorHeight:
          widget.cursorHeight ??
          _textHeight(style, MediaQuery.textScalerOf(context)),
      cursorRadius: widget.cursorRadius ?? platform.cursorRadius,
      cursorOffset: platform.cursorOffset,
      cursorOpacityAnimates: platform.cursorOpacityAnimates,
      paintCursorAboveText: platform.paintCursorAboveText,
      autocorrectionTextRectColor: platform.isApple ? selectionColor : null,
      selectionColor: _focusNode.hasFocus ? selectionColor : null,
      selectionControls: widget.enabled ? platform.selectionControls : null,
      showSelectionHandles: _showSelectionHandles,
      onSelectionChanged: _handleSelectionChanged,
      onSelectionHandleTapped: _handleSelectionHandleTapped,
      contextMenuBuilder: _buildContextMenu,
      magnifierConfiguration: TextMagnifier.adaptiveMagnifierConfiguration,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      keyboardAppearance: widget.keyboardAppearance ?? theme.brightness,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingComplete,
      rendererIgnoresPointer: true,
      mouseCursor: MouseCursor.defer,
      enableInteractiveSelection: widget.enabled,
    );

    // The handles are built in the overlay with the themes captured here
    // (InheritedTheme), so this tints them.
    final handleColor = widget.selectionHandleColor ?? cursorColor;
    editable = TextSelectionTheme(
      data: TextSelectionTheme.of(
        context,
      ).copyWith(selectionHandleColor: handleColor),
      child: CupertinoTheme(
        data: CupertinoTheme.of(
          context,
        ).copyWith(selectionHandleColor: handleColor),
        child: editable,
      ),
    );

    // Between the field's focus node and the app's text-editing shortcuts,
    // so these keys reach the owner first, and pass on to the IME while
    // composing.
    editable = Shortcuts(
      shortcuts: widget.shortcuts,
      child: Actions(actions: _composingAwareActions(), child: editable),
    );
    // Containers show focus inside a text field however it got there.
    editable = CoilFocusAlwaysVisible(child: editable);

    final placeholder = widget.placeholder;
    final singleLine = widget.maxLines == 1;
    final field = Stack(
      fit: StackFit.passthrough,
      alignment: singleLine
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.topStart,
      children: [
        if (placeholder != null)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, child) =>
                value.text.isEmpty ? child! : const SizedBox.shrink(),
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: DefaultTextStyle(
                  style: style.copyWith(
                    color: widget.placeholderColor ?? colors.mutedForeground,
                  ),
                  textAlign: widget.textAlign,
                  maxLines: widget.maxLines,
                  overflow: TextOverflow.ellipsis,
                  child: placeholder,
                ),
              ),
            ),
          ),
        editable,
      ],
    );

    return TextFieldTapRegion(
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.text : MouseCursor.defer,
        child: IgnorePointer(
          ignoring: !widget.enabled,
          child: Semantics(
            enabled: widget.enabled,
            onTap: widget.enabled && !widget.readOnly ? _requestKeyboard : null,
            onDidGainAccessibilityFocus: platform.isDesktop
                ? _focusOnAccessibilityFocus
                : null,
            onDidLoseAccessibilityFocus: platform.isDesktop
                ? _focusNode.unfocus
                : null,
            child: _selectionGestures.buildGestureDetector(
              behavior: HitTestBehavior.translucent,
              child: widget.decorationBuilder?.call(context, field) ?? field,
            ),
          ),
        ),
      ),
    );
  }

  void _focusOnAccessibilityFocus() {
    if (!_focusNode.hasFocus && _focusNode.canRequestFocus) {
      _focusNode.requestFocus();
    }
  }
}

/// Native first: the iOS system edit menu where the field supports it,
/// else the platform's Flutter toolbar. On web, [EditableText] never calls
/// this while the browser's own menu is enabled.
Widget _buildContextMenu(BuildContext context, EditableTextState state) {
  if (SystemContextMenu.isSupportedByField(state)) {
    return SystemContextMenu.editableText(editableTextState: state);
  }
  return _withDefaultLocalizations(
    context,
    AdaptiveTextSelectionToolbar.editableText(editableTextState: state),
  );
}

/// The Material and Cupertino toolbars read their button labels from
/// [MaterialLocalizations] / [CupertinoLocalizations]. A plain [WidgetsApp]
/// has neither, so English defaults are supplied, around the toolbar only,
/// for whichever is missing. An app that configures them keeps its own.
Widget _withDefaultLocalizations(BuildContext context, Widget child) {
  final missing = <LocalizationsDelegate<Object?>>[
    if (Localizations.of<MaterialLocalizations>(
          context,
          MaterialLocalizations,
        ) ==
        null)
      const _DefaultLocalizationsDelegate<MaterialLocalizations>(
        DefaultMaterialLocalizations(),
      ),
    if (Localizations.of<CupertinoLocalizations>(
          context,
          CupertinoLocalizations,
        ) ==
        null)
      const _DefaultLocalizationsDelegate<CupertinoLocalizations>(
        DefaultCupertinoLocalizations(),
      ),
  ];
  if (missing.isEmpty) return child;
  return Localizations.override(
    context: context,
    delegates: missing,
    child: child,
  );
}

/// Supplies [value] for every locale. The stock
/// `DefaultMaterialLocalizations.delegate` only supports `en`, so in an app
/// with any other locale and no Material localizations it would load
/// nothing and the toolbar would assert.
class _DefaultLocalizationsDelegate<T> extends LocalizationsDelegate<T> {
  const _DefaultLocalizationsDelegate(this.value);

  final T value;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<T> load(Locale locale) => SynchronousFuture<T>(value);

  @override
  bool shouldReload(_DefaultLocalizationsDelegate<T> old) => false;
}

/// Disables the action for an intent while the controller has an active
/// IME composition, so [Shortcuts] leaves the key to the IME. Otherwise
/// forwards to the action [resolve] finds.
class _ComposingAwareAction extends ContextAction<Intent> {
  _ComposingAwareAction({required this.isComposing, required this.resolve});

  final bool Function() isComposing;
  final Action<Intent>? Function(Intent intent) resolve;

  @override
  bool isEnabled(Intent intent, [BuildContext? context]) {
    if (isComposing()) return false;
    return switch (resolve(intent)) {
      null => false,
      final ContextAction<Intent> action => action.isEnabled(intent, context),
      final action => action.isEnabled(intent),
    };
  }

  @override
  bool consumesKey(Intent intent) =>
      resolve(intent)?.consumesKey(intent) ?? false;

  @override
  KeyEventResult toKeyEventResult(Intent intent, Object? invokeResult) =>
      resolve(intent)?.toKeyEventResult(intent, invokeResult) ??
      super.toKeyEventResult(intent, invokeResult);

  @override
  Object? invoke(Intent intent, [BuildContext? context]) =>
      switch (resolve(intent)) {
        null => null,
        final ContextAction<Intent> action => action.invoke(intent, context),
        final action => action.invoke(intent),
      };

  /// Tells listeners (e.g. [ActionListener]) that [isEnabled] changed.
  void enabledChanged() => notifyActionListeners();
}

/// The per-platform caret and handle settings `TextField` uses.
class _PlatformText {
  const _PlatformText({
    required this.selectionControls,
    required this.paintCursorAboveText,
    required this.cursorOpacityAnimates,
    required this.isApple,
    required this.isDesktop,
    this.cursorRadius,
    this.cursorOffset,
  });

  factory _PlatformText.of(TargetPlatform platform, BuildContext context) {
    // The iOS caret sits 2 physical pixels left of the glyph edge.
    Offset appleOffset() => Offset(
      iOSHorizontalOffset / MediaQuery.devicePixelRatioOf(context),
      0,
    );
    return switch (platform) {
      TargetPlatform.iOS => _PlatformText(
        selectionControls: cupertinoTextSelectionHandleControls,
        paintCursorAboveText: true,
        cursorOpacityAnimates: true,
        cursorRadius: const Radius.circular(2),
        cursorOffset: appleOffset(),
        isApple: true,
        isDesktop: false,
      ),
      TargetPlatform.macOS => _PlatformText(
        selectionControls: cupertinoDesktopTextSelectionHandleControls,
        paintCursorAboveText: true,
        cursorOpacityAnimates: false,
        cursorRadius: const Radius.circular(2),
        cursorOffset: appleOffset(),
        isApple: true,
        isDesktop: true,
      ),
      TargetPlatform.android || TargetPlatform.fuchsia => _PlatformText(
        selectionControls: materialTextSelectionHandleControls,
        paintCursorAboveText: false,
        cursorOpacityAnimates: false,
        isApple: false,
        isDesktop: false,
      ),
      TargetPlatform.linux || TargetPlatform.windows => _PlatformText(
        selectionControls: desktopTextSelectionHandleControls,
        paintCursorAboveText: false,
        cursorOpacityAnimates: false,
        isApple: false,
        isDesktop: true,
      ),
    };
  }

  final TextSelectionControls selectionControls;
  final bool paintCursorAboveText;
  final bool cursorOpacityAnimates;
  final Radius? cursorRadius;
  final Offset? cursorOffset;
  final bool isApple;
  final bool isDesktop;
}
