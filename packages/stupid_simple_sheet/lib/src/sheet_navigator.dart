part of '../stupid_simple_sheet.dart';

/// Lets sheets that are pushed from within [child] merge into the
/// surrounding sheet, instead of stacking on top of it.
///
/// Wrap the content of a sheet in a [SheetNavigator] to opt in:
///
/// ```dart
/// // Cupertino and glass sheets draw their own chrome around the child
/// StupidSimpleGlassSheetRoute(
///   child: SheetNavigator(child: FirstPage()),
/// );
///
/// // For StupidSimpleSheetRoute, place it inside of your chrome, so that the
/// // chrome stays in place while only the content inside of it changes
/// StupidSimpleSheetRoute(
///   child: SheetBackground(
///     child: SheetNavigator(child: FirstPage()),
///   ),
/// );
/// ```
///
/// This places an auto-sizing, nested [Navigator] around [child], which
/// becomes its first page. A sheet that is pushed through
/// `Navigator.of(context)` from within [child], and agrees to merge via
/// [StupidSimpleSheetTransitionMixin.canMergeInto], is pushed onto that
/// navigator: it replaces the content with a crossfade, while the sheet
/// resizes to fit the new content. Popping it reverses that transition.
///
/// The navigator interpolates its height using each merged sheet's own
/// transition animation. Since that is driven by the merged sheet's
/// [StupidSimpleSheetTransitionMixin.motion], the sheet resizes with exactly
/// the same motion it would otherwise use to slide in. Sheets that are always
/// full height, like the Cupertino and glass sheets, only swap their content.
///
/// Merged sheets reuse the host sheet's chrome, position, drag behavior,
/// snapping configuration and barrier. [SheetBackground] renders nothing but
/// its child inside of merged sheets, so the same content works both as a
/// merged and as a stacked sheet. Dragging the sheet closed, or tapping the
/// barrier, dismisses the whole sheet including all merged sheets, while the
/// system back gesture pops the topmost merged sheet first.
///
/// Everything else keeps working like it does without a [SheetNavigator]:
/// routes that don't merge (pages, dialogs, sheets with
/// [StupidSimpleSheetTransitionMixin.mergeable] set to false, named routes)
/// are forwarded to the navigator that hosts the sheet, and popping [child]
/// itself pops the sheet.
///
/// Note that inside of [child], [ModalRoute.of] returns the first page of the
/// nested navigator, not the sheet. Use [StupidSimpleSheetController.maybeOf]
/// to get a hold of the sheet. Also, overlays such as tooltips that are
/// inserted into the nearest [Overlay] are clipped to the bounds of the sheet.
///
/// Outside of a sheet, or inside of a sheet that was merged into another one,
/// this widget just returns [child]. There can only be one [SheetNavigator]
/// per sheet.
class SheetNavigator extends StatelessWidget {
  /// Creates a [SheetNavigator].
  const SheetNavigator({
    required this.child,
    super.key,
  });

  /// The content of the sheet, which becomes the first page.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return switch (ModalRoute.of(context)) {
      final StupidSimpleSheetTransitionMixin<dynamic> host
          when !host.isMerged =>
        _SheetNavigatorHost(host: host, child: child),
      _ => child,
    };
  }
}

/// Implementation of [SheetNavigator].
///
/// Inspired by `NavigatorResizable` from the `navigator_resizable` package:
/// the nested navigator is laid out with an unbounded height so that it
/// shrink-wraps its pages, while each page is measured by a
/// [_SheetPageBoundary] that lays it out with the constraints the sheet
/// actually gives to its content.
class _SheetNavigatorHost extends StatefulWidget {
  const _SheetNavigatorHost({
    required this.host,
    required this.child,
  });

  final StupidSimpleSheetTransitionMixin<dynamic> host;

  final Widget child;

  @override
  State<_SheetNavigatorHost> createState() => _SheetNavigatorHostState();
}

class _SheetNavigatorHostState extends State<_SheetNavigatorHost> {
  final _navigatorKey = GlobalKey<_NestedSheetNavigatorState>();

  late final _content = ValueNotifier<Widget>(widget.child);

  late final _SheetNavigatorController _controller =
      _SheetNavigatorController();

  late final _SheetNavigatorRootRoute _rootRoute = _SheetNavigatorRootRoute(
    host: widget.host,
    content: _content,
  );

  /// The nested navigator, if it is mounted.
  _NestedSheetNavigatorState? get _navigator => _navigatorKey.currentState;

  /// All routes in the nested navigator that are still installed, from bottom
  /// to top. This includes routes that are currently animating out.
  Iterable<ModalRoute<dynamic>> get _routes =>
      _controller.entries.map((e) => e.route);

  /// Whether the nested navigator currently shows any merged sheets on top of
  /// the host's own content.
  bool get _canPopNested => _navigator?._canPopNested ?? false;

  @override
  void initState() {
    super.initState();
    assert(
      widget.host._sheetNavigator == null,
      'There can only be one SheetNavigator per sheet.',
    );
    widget.host._sheetNavigator = this;
    _controller.register(_rootRoute, kAlwaysCompleteAnimation);
  }

  @override
  void didUpdateWidget(covariant _SheetNavigatorHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _content.value = widget.child;
    if (oldWidget.host != widget.host) {
      if (oldWidget.host._sheetNavigator == this) {
        oldWidget.host._sheetNavigator = null;
      }
      widget.host._sheetNavigator = this;
    }
  }

  @override
  void dispose() {
    if (widget.host._sheetNavigator == this) {
      widget.host._sheetNavigator = null;
    }
    _controller.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetNavigatorScope(
      controller: _controller,
      child: _SheetNavigatorLayout(
        controller: _controller,
        child: _NestedSheetNavigator(
          key: _navigatorKey,
          host: widget.host,
          rootRoute: _rootRoute,
        ),
      ),
    );
  }
}

/// Shared state between the [_RenderSheetNavigator] and the
/// [_RenderSheetPageBoundary]s of the pages inside it.
class _SheetNavigatorController {
  /// The installed routes of the nested navigator, from bottom to top, with
  /// the animation that describes how far each one has transitioned in.
  final entries = <({ModalRoute<dynamic> route, Animation<double> progress})>[];

  /// The measured page boundaries, by route.
  final boundaries = <ModalRoute<dynamic>, _RenderSheetPageBoundary>{};

  /// The constraints pages should be laid out with.
  ///
  /// These are the constraints the sheet gives to the [SheetNavigator], with
  /// the width made tight so that pages always span the whole sheet.
  BoxConstraints? contentConstraints;

  _RenderSheetNavigator? renderObject;

  void register(ModalRoute<dynamic> route, Animation<double> progress) {
    entries.add((route: route, progress: progress));
    progress.addListener(_markNeedsLayout);
    _markNeedsLayout();
  }

  void unregister(ModalRoute<dynamic> route) {
    entries.removeWhere((entry) {
      if (entry.route != route) return false;
      entry.progress.removeListener(_markNeedsLayout);
      return true;
    });
    _markNeedsLayout();
  }

  /// Called by a page boundary whenever its measured height changed.
  void didMeasure() {
    final renderObject = this.renderObject;
    // If the host is laying out right now, it will read the new value after
    // laying out its child anyway.
    if (renderObject == null || renderObject._isLayingOutChild) return;
    renderObject.markNeedsLayout();
  }

  /// Folds the heights of all measured pages, from bottom to top, by
  /// interpolating towards each page by its transition progress.
  ///
  /// Since this composes, interrupted or overlapping transitions never cause
  /// the height to jump.
  double? resolveHeight() {
    double? height;
    for (final (:route, :progress) in entries) {
      final pageHeight = boundaries[route]?.measuredHeight;
      if (pageHeight == null) continue;
      height = switch (height) {
        null => pageHeight,
        final from => from + (pageHeight - from) * progress.value,
      };
    }
    return height;
  }

  void _markNeedsLayout() {
    final renderObject = this.renderObject;
    if (renderObject == null || !renderObject.attached) return;
    renderObject.markNeedsLayout();
  }

  void dispose() {
    for (final entry in entries) {
      entry.progress.removeListener(_markNeedsLayout);
    }
    entries.clear();
    boundaries.clear();
    renderObject = null;
  }
}

class _SheetNavigatorScope extends InheritedWidget {
  const _SheetNavigatorScope({
    required this.controller,
    required super.child,
  });

  final _SheetNavigatorController controller;

  @override
  bool updateShouldNotify(_SheetNavigatorScope oldWidget) =>
      controller != oldWidget.controller;
}

class _SheetNavigatorLayout extends SingleChildRenderObjectWidget {
  const _SheetNavigatorLayout({
    required this.controller,
    required super.child,
  });

  final _SheetNavigatorController controller;

  @override
  _RenderSheetNavigator createRenderObject(BuildContext context) {
    return _RenderSheetNavigator(controller);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSheetNavigator renderObject,
  ) {
    renderObject.controller = controller;
  }
}

/// Lays out the nested navigator with an unbounded height, so it shrink-wraps
/// the current page, and sizes itself to the interpolated height of all pages.
///
/// Anything that overflows that height (e.g. a taller page that is fading out)
/// is clipped.
class _RenderSheetNavigator extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _RenderSheetNavigator(this._controller) {
    _controller.renderObject = this;
  }

  _SheetNavigatorController _controller;
  _SheetNavigatorController get controller => _controller;
  set controller(_SheetNavigatorController value) {
    if (value == _controller) return;
    if (_controller.renderObject == this) _controller.renderObject = null;
    _controller = value..renderObject = this;
    markNeedsLayout();
  }

  /// The interpolated height before applying our own constraints.
  double _naturalHeight = 0;

  bool _isLayingOutChild = false;

  final _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  void performLayout() {
    final child = this.child;
    assert(
      constraints.hasBoundedWidth,
      'A sheet with nested navigation needs a bounded width.',
    );
    final width = constraints.maxWidth;
    final contentConstraints = BoxConstraints(
      minWidth: width,
      maxWidth: width,
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight,
    );
    if (contentConstraints != _controller.contentConstraints) {
      _controller.contentConstraints = contentConstraints;
      // Pages are laid out with these constraints, but they aren't passed
      // through the navigator, so we need to tell pages about the change.
      invokeLayoutCallback<BoxConstraints>((_) {
        for (final boundary in _controller.boundaries.values) {
          boundary.markNeedsLayout();
        }
      });
    }

    if (child == null) {
      _naturalHeight = 0;
      size = constraints.constrain(Size(width, 0));
      return;
    }

    _isLayingOutChild = true;
    try {
      child.layout(
        BoxConstraints.tightFor(width: width),
        parentUsesSize: true,
      );
    } finally {
      _isLayingOutChild = false;
    }

    _naturalHeight = _controller.resolveHeight() ?? child.size.height;
    size = constraints.constrain(Size(width, _naturalHeight));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return constraints.constrain(Size(constraints.maxWidth, _naturalHeight));
  }

  // The intrinsic height is whatever height we currently want to be. This
  // makes e.g. ShrinkTransition treat us like content that cannot be squished.
  @override
  double computeMinIntrinsicHeight(double width) => _naturalHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _naturalHeight;

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: _clipLayer.layer,
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    return super.hitTest(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return child?.hitTest(result, position: position) ?? false;
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    if (_controller.renderObject == this) _controller.renderObject = null;
    super.dispose();
  }
}

/// Wraps the content of each page inside a [SheetNavigator] and measures it.
///
/// The content is laid out with the constraints the sheet gives to its content
/// instead of the (possibly tight or unbounded) constraints of the navigator.
class _SheetPageBoundary extends SingleChildRenderObjectWidget {
  const _SheetPageBoundary({
    required this.route,
    required super.child,
  });

  final ModalRoute<dynamic> route;

  @override
  _RenderSheetPageBoundary createRenderObject(BuildContext context) {
    return _RenderSheetPageBoundary(
      controller: _controllerOf(context),
      route: route,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSheetPageBoundary renderObject,
  ) {
    renderObject
      ..controller = _controllerOf(context)
      ..route = route;
  }

  static _SheetNavigatorController _controllerOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_SheetNavigatorScope>();
    assert(scope != null, 'A sheet page must be inside a _SheetNavigator.');
    return scope!.controller;
  }
}

class _RenderSheetPageBoundary extends RenderShiftedBox {
  _RenderSheetPageBoundary({
    required _SheetNavigatorController controller,
    required ModalRoute<dynamic> route,
  })  : _controller = controller,
        _route = route,
        super(null);

  _SheetNavigatorController _controller;
  _SheetNavigatorController get controller => _controller;
  set controller(_SheetNavigatorController value) {
    if (value == _controller) return;
    _unregister();
    _controller = value;
    _register();
    markNeedsLayout();
  }

  ModalRoute<dynamic> _route;
  ModalRoute<dynamic> get route => _route;
  set route(ModalRoute<dynamic> value) {
    if (value == _route) return;
    _unregister();
    _route = value;
    _register();
    markNeedsLayout();
  }

  /// The height of the content, as determined in the last layout pass.
  double? measuredHeight;

  void _register() {
    if (attached) _controller.boundaries[_route] = this;
  }

  void _unregister() {
    if (_controller.boundaries[_route] == this) {
      _controller.boundaries.remove(_route);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _register();
  }

  @override
  void detach() {
    _unregister();
    super.detach();
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final contentConstraints = _controller.contentConstraints ?? constraints;
    return constraints.constrain(child.getDryLayout(contentConstraints));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      _controller.contentConstraints ?? constraints,
      parentUsesSize: true,
    );
    (child.parentData! as BoxParentData).offset = Offset.zero;

    final height = child.size.height;
    if (height != measuredHeight) {
      measuredHeight = height;
      _controller.didMeasure();
    }

    // When this page doesn't determine the navigator's size, the navigator
    // forces it to match the current page. The content keeps its own size and
    // may overflow, which the _RenderSheetNavigator clips.
    size = constraints.constrain(child.size);
  }
}

/// The first page of a [SheetNavigator], which shows the host's own content.
class _SheetNavigatorRootRoute extends PageRoute<void> {
  _SheetNavigatorRootRoute({
    required this.host,
    required this.content,
  });

  final StupidSimpleSheetTransitionMixin<dynamic> host;

  final ValueListenable<Widget> content;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  // From the content's point of view, this page can always be popped, since
  // popping it pops the host sheet.
  @override
  bool get canPop => host.canPop;

  @override
  bool get impliesAppBarDismissal => host.impliesAppBarDismissal;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is StupidSimpleSheetTransitionMixin && nextRoute.isMerged;

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    super.didChangeNext(nextRoute);
    // Merged sheets never transition the page below them via delegation.
    // ignore: invalid_use_of_visible_for_testing_member
    receivedTransition = null;
  }

  @override
  void didPopNext(Route<dynamic> nextRoute) {
    super.didPopNext(nextRoute);
    // ignore: invalid_use_of_visible_for_testing_member
    receivedTransition = null;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _SheetPageBoundary(
      route: this,
      child: ValueListenableBuilder(
        valueListenable: content,
        builder: (context, content, _) => content,
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return host.buildMergedTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

class _NestedSheetNavigator extends Navigator {
  _NestedSheetNavigator({
    required this.host,
    required _SheetNavigatorRootRoute rootRoute,
    super.key,
  }) : super(
          // Pages that are fading out may be taller than the navigator.
          // _RenderSheetNavigator clips to the right bounds instead.
          clipBehavior: Clip.none,
          onGenerateInitialRoutes: (_, __) => [rootRoute],
        );

  final StupidSimpleSheetTransitionMixin<dynamic> host;

  @override
  NavigatorState createState() => _NestedSheetNavigatorState();
}

/// A [NavigatorState] that only keeps merged sheets and forwards everything
/// else to the navigator that hosts the sheet.
///
/// This keeps the behavior of code inside the sheet identical to a sheet
/// without nested navigation: pushing a page, a dialog, or a sheet that does
/// not merge still happens on the outer navigator, and popping the host's own
/// content still pops the whole sheet.
class _NestedSheetNavigatorState extends NavigatorState {
  StupidSimpleSheetTransitionMixin<dynamic> get _host =>
      (widget as _NestedSheetNavigator).host;

  NavigatorState get _parent => _host.navigator!;

  /// Whether this navigator itself can pop, without forwarding to [_parent].
  bool get _canPopNested => super.canPop();

  bool _adopt(Route<dynamic> route) {
    if (route is! StupidSimpleSheetTransitionMixin) return false;
    if (route._mergeHost != null || route.navigator != null) return false;
    if (!route.canMergeInto(_host)) return false;
    route._mergeHost = _host;
    return true;
  }

  @override
  Future<T?> push<T extends Object?>(Route<T> route) {
    if (_adopt(route)) return super.push(route);
    return _parent.push(route);
  }

  @override
  Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    Route<T> newRoute, {
    TO? result,
  }) {
    if (_adopt(newRoute)) {
      return super.pushReplacement(newRoute, result: result);
    }
    return _parent.pushReplacement(newRoute, result: result);
  }

  @override
  Future<T?> pushAndRemoveUntil<T extends Object?>(
    Route<T> newRoute,
    RoutePredicate predicate,
  ) {
    if (_adopt(newRoute)) return super.pushAndRemoveUntil(newRoute, predicate);
    return _parent.pushAndRemoveUntil(newRoute, predicate);
  }

  // Named routes are always resolved by the outer navigator.

  @override
  Future<T?> pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return _parent.pushNamed(routeName, arguments: arguments);
  }

  @override
  String restorablePushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) {
    return _parent.restorablePushNamed(routeName, arguments: arguments);
  }

  @override
  Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    return _parent.pushReplacementNamed(
      routeName,
      result: result,
      arguments: arguments,
    );
  }

  @override
  String restorablePushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    return _parent.restorablePushReplacementNamed(
      routeName,
      result: result,
      arguments: arguments,
    );
  }

  @override
  Future<T?> popAndPushNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    return _parent.popAndPushNamed(
      routeName,
      result: result,
      arguments: arguments,
    );
  }

  @override
  String restorablePopAndPushNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    return _parent.restorablePopAndPushNamed(
      routeName,
      result: result,
      arguments: arguments,
    );
  }

  @override
  Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    String newRouteName,
    RoutePredicate predicate, {
    Object? arguments,
  }) {
    return _parent.pushNamedAndRemoveUntil(
      newRouteName,
      predicate,
      arguments: arguments,
    );
  }

  @override
  String restorablePushNamedAndRemoveUntil<T extends Object?>(
    String newRouteName,
    RoutePredicate predicate, {
    Object? arguments,
  }) {
    return _parent.restorablePushNamedAndRemoveUntil(
      newRouteName,
      predicate,
      arguments: arguments,
    );
  }

  // Restorable pushes create their routes from static builders, so they can't
  // be adopted and always go to the outer navigator.

  @override
  String restorablePush<T extends Object?>(
    RestorableRouteBuilder<T> routeBuilder, {
    Object? arguments,
  }) {
    return _parent.restorablePush(routeBuilder, arguments: arguments);
  }

  @override
  String restorablePushReplacement<T extends Object?, TO extends Object?>(
    RestorableRouteBuilder<T> routeBuilder, {
    TO? result,
    Object? arguments,
  }) {
    return _parent.restorablePushReplacement(
      routeBuilder,
      result: result,
      arguments: arguments,
    );
  }

  @override
  String restorablePushAndRemoveUntil<T extends Object?>(
    RestorableRouteBuilder<T> newRouteBuilder,
    RoutePredicate predicate, {
    Object? arguments,
  }) {
    return _parent.restorablePushAndRemoveUntil(
      newRouteBuilder,
      predicate,
      arguments: arguments,
    );
  }

  @override
  bool canPop() => super.canPop() || _parent.canPop();

  @override
  Future<bool> maybePop<T extends Object?>([T? result]) {
    if (super.canPop()) return super.maybePop(result);
    return _parent.maybePop(result);
  }

  @override
  void pop<T extends Object?>([T? result]) {
    if (super.canPop()) return super.pop(result);
    return _parent.pop(result);
  }

  @override
  void popUntil(RoutePredicate predicate) {
    var found = false;
    super.popUntil((route) {
      if (predicate(route)) return found = true;
      // Never pop the last page here, the outer navigator does that below.
      return !super.canPop();
    });
    if (!found) _parent.popUntil(predicate);
  }

  @override
  void popUntilWithResult<T extends Object?>(
    RoutePredicate predicate,
    T? result,
  ) {
    var found = false;
    super.popUntil((route) {
      if (predicate(route)) return found = true;
      return !super.canPop();
    });
    if (!found) _parent.popUntilWithResult(predicate, result);
  }

  @override
  void removeRoute<T extends Object?>(Route<T> route, [T? result]) {
    if (route.navigator != this) return _parent.removeRoute(route, result);
    if (route is _SheetNavigatorRootRoute) {
      // The root page is the host's content, so removing it removes the host.
      return _parent.removeRoute(_host);
    }
    super.removeRoute(route, result);
  }
}
