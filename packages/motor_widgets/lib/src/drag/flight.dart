import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/drag/motion_draggable.dart';
import 'package:motor_widgets/src/painted_position.dart';
import 'package:motor_widgets/src/ticker_rate.dart';

/// Where a [DragFlight] can land: a `MotionLayoutItem` with the flight's
/// id, or a [MotionDraggable] that isn't inside one.
abstract interface class LandingSite {
  /// The site's element.
  BuildContext get context;

  /// Whether a flight that has reached this site waits there instead of
  /// ending, because the item it stands in for hasn't arrived yet.
  ///
  /// A `MotionReorderable`'s gap holds a landing while its insert is pending:
  /// see [LandingHold].
  bool get holdsLanding;

  /// The site's rect in global coordinates where it was last painted, or
  /// null while it isn't laid out.
  ///
  /// It includes offsets that only move the painting, such as a
  /// `MotionLayoutItem`'s flight, which hit testing and `localToGlobal`
  /// leave out.
  Rect? get globalRect;

  /// The link that the site leads while a flight lands on its id, so the
  /// flight can follow where the site is painted in every frame.
  LayerLink get landingLink;

  /// The receiver in the tree that can take the rest of a landing on this
  /// site, or null when there is none.
  FlightReceiver? get flightReceiver;

  /// Where the site can be seen: the intersection of its scrollables'
  /// painted rects in global coordinates, or null when it has none.
  Rect? get visibleRect;

  /// Continues a handed-off landing's scale, rotation and opacity in the
  /// tree, from [values] with their velocities, back to rest.
  void receiveVisuals(List<TrackValue<double>> values);

  /// Called when a flight starts or stops landing on this site's id, so
  /// that the site hides or shows its child.
  void landingChanged();

  /// Starts recognizing a drag of this site for [event], which hit [flight]
  /// while it lands here. Returns whether the site took the pointer.
  bool grab(PointerDownEvent event, DragFlight flight);

  /// Forgets a [grab] of [flight] whose pointer went up before a drag
  /// started.
  void endGrab(DragFlight flight);
}

/// Makes the `MotionLayoutItem`s below it hold a landing: the flight waits
/// over them in the overlay, and keeps waiting after it arrives, until a
/// site that doesn't hold takes the id over.
///
/// A `MotionReorderable`'s gap holds the landing of a drop whose insert is
/// pending, and gives way to the item once it arrives.
class LandingHold extends InheritedWidget {
  /// Makes the items below hold landings while [holds].
  const LandingHold({required this.holds, required super.child, super.key});

  /// Whether the items below hold landings.
  final bool holds;

  /// Whether the items at [context] hold landings. Read by flights, outside
  /// a build, so it doesn't make [context] depend on the hold.
  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LandingHold>()?.holds ?? false;

  @override
  bool updateShouldNotify(LandingHold oldWidget) => holds != oldWidget.holds;
}

/// The box of a landing scope: an accepted drop over it lands in its
/// [landingRegistry], unless the target named another.
///
/// A `MotionLayoutGroup`'s render object is one, and is in [mounted] while
/// it is attached.
abstract interface class LandingScopeBox implements RenderBox {
  /// The registry of the scope.
  LandingRegistry get landingRegistry;

  /// The scope boxes that are attached.
  static final Set<LandingScopeBox> mounted = {};
}

/// Gives the widgets below it their own [LandingRegistry], so ids only need
/// to be unique below it.
///
/// Every `MotionLayoutGroup` is one.
class LandingScope extends InheritedWidget {
  /// Scopes the landings below to [registry].
  const LandingScope({required this.registry, required super.child, super.key});

  /// The registry of the scope.
  final LandingRegistry registry;

  @override
  bool updateShouldNotify(LandingScope oldWidget) =>
      !identical(registry, oldWidget.registry);
}

/// The [LandingSite]s of one scope, by id, and the ids that flights are
/// landing on.
///
/// A scope is the nearest [LandingScope], such as a `MotionLayoutGroup`, or
/// else the [Overlay] the flights fly in.
class LandingRegistry {
  /// An empty registry, for a [LandingScope].
  LandingRegistry();

  static final _overlays = Expando<LandingRegistry>('LandingRegistry');

  /// The registry of [context]'s scope, or null when it has none.
  ///
  /// With [listen], [context] rebuilds when the scope changes.
  static LandingRegistry? maybeOf(
    BuildContext context, {
    bool listen = true,
    bool rootOverlay = false,
  }) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<LandingScope>()
        : context.getInheritedWidgetOfExactType<LandingScope>();
    if (scope != null) return scope.registry;
    final overlay = Overlay.maybeOf(context, rootOverlay: rootOverlay);
    return overlay == null ? null : _overlays[overlay] ??= LandingRegistry();
  }

  final _sites = <Object, List<LandingSite>>{};
  final _landing = <Object, int>{};
  final _fading = <Object, int>{};

  /// Registers [site] under [id].
  void add(Object id, LandingSite site) => (_sites[id] ??= []).add(site);

  /// Unregisters [site] from [id].
  void remove(Object id, LandingSite site) {
    final sites = _sites[id];
    if (sites == null) return;
    sites.remove(site);
    if (sites.isEmpty) _sites.remove(id);
  }

  /// The sites registered under [id].
  List<LandingSite> sitesFor(Object id) => List.of(_sites[id] ?? const []);

  /// Whether a flight is landing on [id], so its sites hide their child.
  bool isLanding(Object id) => _landing.containsKey(id);

  /// Whether a handed-off flight's overlay copy is fading out over [id], so
  /// its sites keep leading the flight without hiding their child.
  bool isFading(Object id) => _fading.containsKey(id);

  /// Marks [id] as fading until a matching [endFade].
  void beginFade(Object id) {
    final count = _fading[id] ?? 0;
    _fading[id] = count + 1;
    if (count == 0) _notify(id);
  }

  /// Ends one [beginFade] of [id].
  void endFade(Object id) {
    final count = _fading[id];
    if (count == null) return;
    if (count > 1) {
      _fading[id] = count - 1;
      return;
    }
    _fading.remove(id);
    _notify(id);
  }

  /// Marks [id] as landing until a matching [endLanding].
  void beginLanding(Object id) {
    final count = _landing[id] ?? 0;
    _landing[id] = count + 1;
    if (count == 0) _notify(id);
  }

  /// Ends one [beginLanding] of [id].
  void endLanding(Object id) {
    final count = _landing[id];
    if (count == null) return;
    if (count > 1) {
      _landing[id] = count - 1;
      return;
    }
    _landing.remove(id);
    _notify(id);
  }

  void _notify(Object id) {
    // Sites rebuild with setState, which isn't allowed while the tree is
    // being built or torn down, for example when an overlay unmounts.
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => _notifyNow(id));
      return;
    }
    _notifyNow(id);
  }

  void _notifyNow(Object id) {
    for (final site in sitesFor(id)) {
      site.landingChanged();
    }
  }
}

/// Smooths the pointer's velocity while dragging.
///
/// Each pointer sample retargets it to the tracked estimate. Once that
/// spring has ended without a new sample, it heads back to zero, so a
/// resting pointer reads as still.
final _velocity = Track<Offset>(
  MotionConverter.offset,
  initial: Offset.zero,
  debugLabel: 'MotionDraggable.velocity',
);

const _smoothing = CupertinoMotion(duration: Duration(milliseconds: 100));

/// Learns when any [MotionDraggable]'s drag starts and ends.
abstract interface class DragFlightObserver {
  /// [flight] started a drag from [DragFlight.source].
  void flightStarted(DragFlight flight);

  /// The pointer moved [flight]'s drag.
  void flightMoved(DragFlight flight);

  /// [flight]'s drag ended, with [DragFlight.phase] set to its outcome, or
  /// its outcome changed, when an accepted drop was rejected after all.
  void flightReleased(DragFlight flight);

  /// [flight] has landed, finished its exit, or lost its overlay.
  void flightFinished(DragFlight flight);
}

/// The feedback's visual tracks, which `MotionDraggable.transitions` may
/// animate, with the value each springs back to when a transition doesn't
/// mention it.
final feedbackRests = <MotionDraggableTrack<double>, double>{
  MotionDraggableTrack.scale: 1,
  MotionDraggableTrack.rotation: 0,
  MotionDraggableTrack.opacity: 1,
};

/// The feedback's visual tracks springing back to rest, each on the motion
/// that [motionFor] gives it.
List<TrackAnimation<double>> feedbackToRest(
  Motion Function(MotionDraggableTrack<double> track) motionFor,
) => [
  for (final MapEntry(key: track, value: rest) in feedbackRests.entries)
    track([TrackStep.to(rest, motion: motionFor(track))]),
];

/// One drag's feedback, from the moment it is picked up until it has landed
/// or finished its exit.
///
/// It lives in its own [OverlayEntry] and owns its controller there, so it
/// outlives the [MotionDraggable] that started it. That draggable is
/// disposed, for example, when a drop moves the item to another column.
class DragFlight {
  /// Creates a flight for a drag that starts at [pointer], with the
  /// feedback's top-left [anchor] away from it.
  DragFlight({
    required this.overlay,
    required this.registry,
    required this.id,
    required this.data,
    required MotionDraggable<Object> widget,
    required Offset pointer,
    required Offset anchor,
    required Size size,
    this.source,
  }) : _widget = widget,
       _pointer = pointer,
       _anchor = anchor,
       _initialSize = size,
       _sourceRegistry = registry;

  /// The overlay the flight flies in.
  final OverlayState overlay;

  /// The registry the flight looks up its destination in.
  ///
  /// While dragging, the scope it was dragged from. An accepted drop lands
  /// in the scope the target names with [landIn], as a `MotionReorderable`
  /// does, else in the innermost scope under the pointer, else where it
  /// came from. A rejected drop lands where it came from.
  LandingRegistry registry;
  bool _registryNamed = false;

  /// The scope the current drag started in, where a rejected drop lands.
  LandingRegistry _sourceRegistry;

  /// Makes an accepted drop land in [registry]. Called by the target while
  /// it accepts the drop.
  void landIn(LandingRegistry registry) {
    this.registry = registry;
    _registryNamed = true;
  }

  /// The registry of the innermost landing scope whose box contains
  /// [position], or null.
  static LandingRegistry? _registryUnder(Offset position) {
    LandingScopeBox? innermost;
    for (final box in LandingScopeBox.mounted) {
      if (!box.attached || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (!rect.contains(position)) continue;
      if (innermost == null || box.depth > innermost.depth) innermost = box;
    }
    return innermost?.landingRegistry;
  }

  /// The data the drag drops: the draggable's, or its slot's item.
  Object? data;

  /// The id the flight lands on.
  final Object id;

  /// The site the current drag started from: the draggable, or the
  /// destination a landing was grabbed from again.
  LandingSite? source;

  static final _active = <DragFlight>{};
  static final _observers = <DragFlightObserver>[];

  /// Starts telling [observer] about every drag.
  static void addObserver(DragFlightObserver observer) =>
      _observers.add(observer);

  /// Stops telling [observer] about drags.
  static void removeObserver(DragFlightObserver observer) =>
      _observers.remove(observer);

  /// The flights that are dragged or landing.
  static Iterable<DragFlight> get activeFlights => _active;

  /// The flight that is landing on [id] in [registry], or null.
  static DragFlight? landingOn(Object id, LandingRegistry registry) {
    for (final flight in _active) {
      if (flight.isRegrabbable &&
          flight.id == id &&
          identical(flight.registry, registry)) {
        return flight;
      }
    }
    return null;
  }

  /// The flight that is being dragged with [data], or null.
  static DragFlight? draggingWith(Object? data) {
    DragFlight? found;
    for (final flight in _active) {
      if (flight.isDragging && flight.data == data) found = flight;
    }
    return found;
  }

  void _notifyStarted() {
    _active.add(this);
    for (final observer in List.of(_observers)) {
      observer.flightStarted(this);
    }
  }

  void _notifyMoved() {
    for (final observer in List.of(_observers)) {
      observer.flightMoved(this);
    }
  }

  void _notifyReleased() {
    for (final observer in List.of(_observers)) {
      observer.flightReleased(this);
    }
  }

  void _notifyFinished() {
    for (final observer in List.of(_observers)) {
      observer.flightFinished(this);
    }
  }

  /// The draggable the flight was last dragged from.
  MotionDraggable<Object> get widget => _widget;
  MotionDraggable<Object> _widget;
  set widget(MotionDraggable<Object> value) {
    if (identical(value, _widget)) return;
    _widget = value;
    // The draggable updates while it builds, when the flight's entry can't
    // be marked for a rebuild yet.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!isDone) _entry.markNeedsBuild();
    });
  }

  late final OverlayEntry _entry = OverlayEntry(
    builder: (context) => _FlightView(flight: this),
  );

  _FlightViewState? _view;
  TrackController? get _controller => _view?._controller;

  /// What happened to the drag.
  MotionDragPhase phase = MotionDragPhase.dragging;

  /// Whether a target accepted the drop, set while the drag ends.
  bool accepted = false;

  /// Whether the flight has landed, finished its exit, or lost its overlay.
  bool get isDone => _done;
  var _done = false;

  Offset _pointer;
  Offset _anchor;
  final Size _initialSize;
  Offset _releaseVelocity = Offset.zero;

  /// Whether the destination has been looked up since the drop.
  var _resolved = false;
  var _landingMarked = false;

  /// Whether the flight has handed off to the tree and its overlay copy is
  /// fading out over the destination.
  var _fadingOut = false;

  /// Whether the landing has entered its destination's visible area, so the
  /// overlay copy is clipped to it until the landing ends.
  var _clippedToSite = false;
  var _finishScheduled = false;

  /// The destination, and its rect as last measured. While there is one,
  /// the offset track holds the distance from its top-left.
  LandingSite? _site;
  Rect? _siteRect;

  /// A link no leader ever leads: following it paints the feedback where it
  /// is laid out, as while dragging or exiting.
  final _unlinked = LayerLink();
  var _lossScheduled = false;
  var _resizeScheduled = false;

  /// Whether a new drag can pick up the landing: it is landing on a site,
  /// and hasn't handed off to the tree yet.
  bool get isRegrabbable =>
      !_done &&
      phase != MotionDragPhase.dragging &&
      !_fadingOut &&
      _site != null;

  /// Whether the pointer is still dragging the feedback.
  bool get isDragging => !_done && phase == MotionDragPhase.dragging;

  /// Makes the drag look for its target under the pointer again, set by
  /// the draggable whose drag this is.
  VoidCallback? retarget;

  /// Looks for the drag's target under the pointer again, after content
  /// moved under a pointer that didn't, such as during an edge scroll.
  ///
  /// Flutter's drag only looks when the pointer moves.
  void nudge() {
    if (isDragging) retarget?.call();
  }

  /// Where the pointer is, in global coordinates, restricted to
  /// [MotionDraggable.axis] like the feedback.
  Offset get pointer => _pointer;

  /// The feedback's rect in global coordinates, without its scale and
  /// rotation.
  Rect get feedbackRect {
    final controller = _controller;
    final size = controller == null
        ? _initialSize
        : controller.value(MotionDraggableTrack.size);
    return globalTopLeft & size;
  }

  /// The feedback's top-left in global coordinates.
  Offset get globalTopLeft {
    final controller = _controller;
    if (controller == null) return _pointer - _anchor;
    final offset = controller.value(MotionDraggableTrack.offset);
    return switch (_siteRect) {
      final rect? when _site != null => rect.topLeft + offset,
      _ => offset,
    };
  }

  /// The live drag, as the builder and the transitions see it.
  MotionDragDetails get details {
    final controller = _controller!;
    return MotionDragDetails(
      phase: phase,
      destination: _site == null ? null : _siteRect,
      velocity: phase == MotionDragPhase.dragging
          ? controller.value(_velocity)
          : controller.velocity(MotionDraggableTrack.offset),
      size: controller.value(MotionDraggableTrack.size),
      values: controller.value,
    );
  }

  Motion _motionFor(Track<Object> track) =>
      widget.motions?[track] ?? widget.motion;

  Offset _restrict(Offset offset) => switch (widget.axis) {
    Axis.horizontal => Offset(offset.dx, 0),
    Axis.vertical => Offset(0, offset.dy),
    null => offset,
  };

  /// Shows the flight.
  void start() {
    overlay.insert(_entry);
    _notifyStarted();
  }

  /// Moves the feedback with the pointer.
  void moveBy(Offset delta) {
    if (_done || phase != MotionDragPhase.dragging) return;
    _pointer += _restrict(delta);
    final controller = _controller;
    if (controller == null) {
      _notifyMoved();
      return;
    }
    controller.set([MotionDraggableTrack.offset.value(_pointer - _anchor)]);
    // Observers see the feedback where the pointer put it.
    _notifyMoved();
    final estimate =
        controller
            .trackedVelocityEstimate(MotionDraggableTrack.offset)
            ?.perSecond ??
        Offset.zero;
    controller.animate([
      _velocity([
        TrackStep.to(estimate, motion: _smoothing, until: WaitUntil.ended),
        const TrackStep.to(Offset.zero, motion: _smoothing),
      ]),
    ]);
  }

  /// Ends the drag with the pointer's [velocity], and starts landing.
  void release(Offset velocity) {
    if (_done) return;
    phase = accepted ? MotionDragPhase.accepted : MotionDragPhase.rejected;
    if (accepted && !_registryNamed) {
      registry = _registryUnder(_pointer) ?? registry;
    }
    _registryNamed = false;
    _releaseVelocity = _restrict(velocity);
    registry.beginLanding(id);
    _landingMarked = true;
    _coast();
    _notifyReleased();
    // The drop rebuilds the item in its new place in the next frame. It is
    // laid out after that frame, so look for it then.
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _resolve())
      ..scheduleFrame();
  }

  /// Starts a drag of the landing feedback from its destination.
  void regrab(
    MotionDraggable<Object> widget,
    Offset pointer,
    Offset anchor, {
    required LandingSite source,
    required LandingRegistry registry,
    required Object? data,
  }) {
    final controller = _controller;
    final global = globalTopLeft;
    final velocity = controller?.velocity(MotionDraggableTrack.offset);
    // Ends the landing in the scope it was marked in.
    _endLanding();
    _widget = widget;
    phase = MotionDragPhase.dragging;
    accepted = false;
    _resolved = false;
    _site = null;
    _siteRect = null;
    _pointer = pointer;
    _anchor = anchor;
    this.source = source;
    this.registry = registry;
    _sourceRegistry = registry;
    this.data = data;
    _notifyStarted();
    if (controller == null) return;
    controller.set([
      MotionDraggableTrack.offset.value(global, velocity: velocity),
    ]);
    _applyTransitions();
  }

  /// Takes a drop that no [DragTarget] accepted, and returns whether it
  /// did: set by a `MotionReorderable` that keeps the drop after the drag
  /// left it, so letting go drops where its gap shows. Called while the
  /// drag ends, before [release].
  bool Function()? takeUnaccepted;

  /// Where an accepted drop lands and waits, until [relocate], while the
  /// item it stands for isn't there yet: a `MotionReorderable`'s gap while
  /// its move is pending.
  LandingSite? hold;

  /// Looks for where to land again after this frame, because the site it
  /// lands on is going away, such as a drop zone's gap whose item arrives.
  ///
  /// A flight that rests on a site doesn't rebuild, so it wouldn't notice.
  void relocate() {
    hold = null;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        final site = _site;
        if (site != null && !_done) _loseSite(site);
      })
      ..scheduleFrame();
  }

  /// Turns an accepted drop into a rejected one, because the target couldn't
  /// take the item after all, for example when a `MotionReorderable`'s insert
  /// failed. The flight then lands back on the item where it still is, or
  /// plays the rejected exit.
  void reject() {
    if (_done || phase != MotionDragPhase.accepted) return;
    phase = MotionDragPhase.rejected;
    accepted = false;
    // The target may have named another scope: land back where the drag
    // came from.
    if (!identical(registry, _sourceRegistry)) {
      _endLanding();
      registry = _sourceRegistry;
      registry.beginLanding(id);
      _landingMarked = true;
    }
    _notifyReleased();
    if (_view == null) return;
    _applyTransitions();
  }

  /// Lets the feedback carry on from the release while the destination
  /// isn't known, and while it exits without one.
  void _coast({Offset? velocity}) {
    final controller = _controller;
    if (controller == null) return;
    controller
      ..stop(tracks: [_velocity], canceled: true)
      ..set([_velocity.value(Offset.zero)])
      ..animate([
        MotionDraggableTrack.offset(
          [
            TrackStep.to(
              globalTopLeft,
              motion: _motionFor(MotionDraggableTrack.offset),
            ),
          ],
          withVelocity: velocity ?? _releaseVelocity,
        ),
      ]);
  }

  void _resolve() {
    if (_done || phase == MotionDragPhase.dragging || _resolved) return;
    final controller = _controller;
    if (controller == null) {
      // The entry never built, because its overlay went away.
      _finish(landed: false);
      return;
    }
    _resolved = true;
    if (_findSite() case final found?) _landOn(found.site, found.rect);
    _applyTransitions();
    _checkSettled();
  }

  /// Where to land now: the nearest site with the id, or null when there is
  /// none.
  ({LandingSite site, Rect rect})? _findSite() {
    final controller = _controller!;
    if (hold case final site? when accepted) {
      if (site.globalRect case final rect?) return (site: site, rect: rect);
    }
    final candidates = [
      for (final site in registry.sitesFor(id))
        if (site.globalRect case final rect?) (site: site, rect: rect),
    ];
    assert(() {
      if (candidates.length > 1) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError.fromParts([
              ErrorSummary(
                '${candidates.length} landing sites have the id $id.',
              ),
              ErrorDescription(
                'A MotionDraggable lands on the MotionLayoutItem with its id, '
                'so only one of them may have it at a time in a '
                'MotionLayoutGroup. '
                'The feedback lands on the nearest one.',
              ),
              ErrorHint(
                'Give each item a unique id.',
              ),
            ]),
            library: 'motor_widgets',
            context: ErrorDescription('while landing a MotionDraggable'),
          ),
        );
      }
      return true;
    }(), 'never fails: it only reports duplicate ids');
    if (candidates.isEmpty) return null;
    final center = globalTopLeft & controller.value(MotionDraggableTrack.size);
    return candidates.reduce(
      (a, b) =>
          (a.rect.center - center.center).distanceSquared <=
              (b.rect.center - center.center).distanceSquared
          ? a
          : b,
    );
  }

  void _landOn(LandingSite site, Rect rect) {
    final controller = _controller!;
    final global = globalTopLeft;
    final velocity = controller.velocity(MotionDraggableTrack.offset);
    if (!identical(site, _site)) _clippedToSite = false;
    _site = site;
    _siteRect = rect;
    controller.animate([
      MotionDraggableTrack.offset(
        [
          TrackStep.to(
            Offset.zero,
            motion: _motionFor(MotionDraggableTrack.offset),
          ),
        ],
        from: global - rect.topLeft,
        withVelocity: velocity,
      ),
      MotionDraggableTrack.size([
        TrackStep.to(
          rect.size,
          motion: _motionFor(MotionDraggableTrack.size),
        ),
      ]),
    ]);
  }

  /// Follows the destination: called on every build of the flight.
  void _measure() {
    final site = _site;
    if (site == null || _done) return;
    final rect = site.globalRect;
    final binding = SchedulerBinding.instance;
    if (rect == null) {
      if (!_lossScheduled) {
        _lossScheduled = true;
        binding.addPostFrameCallback((_) => _loseSite(site));
      }
      return;
    }
    if (rect.size != _siteRect?.size && !_resizeScheduled) {
      _resizeScheduled = true;
      binding.addPostFrameCallback((_) => _resize());
    }
    _siteRect = rect;
  }

  /// Hands the rest of the landing to the destination's [FlightReceiver]
  /// and leaves the overlay, when [MotionDraggable.handoff] allows. With
  /// [MotionDragHandoff.onEnter], that is as soon as the item is "in" its
  /// destination: the feedback's center is inside the destination's visible
  /// area, and the destination's slot is painted there. With
  /// [MotionDragHandoff.immediate] it is the first tick it can, and with
  /// [MotionDragHandoff.never] never.
  ///
  /// For most drops that is the first frame after the drop, because the
  /// pointer drops the feedback where the destination can be seen. From then
  /// on the item flies in the tree: clipped by its scrollables, stacked like
  /// itself, and redirected by a reorder. The receiver takes the position;
  /// the destination takes the scale, rotation and opacity, each with its
  /// velocity. Only [MotionDraggable.feedback]'s decoration ends.
  ///
  /// A list doesn't paint an item whose slot is out of view, so while the
  /// slot is outside the visible area, the flight stays in the overlay,
  /// clipped to that area as the list would clip it (see [_clip]), and
  /// hands off once the slot is in view.
  ///
  /// It waits for the size to reach the destination's, within half a pixel,
  /// since the item in the tree has its own layout.
  ///
  /// It runs on the flight's own tick, during a frame, so the receiver's
  /// spring starts at this frame's time and moves on in the next one
  /// (a ticker started between frames would stand still for a frame). The
  /// rects it checks are where the last frame painted them.
  void _tryHandOff() {
    final site = _site;
    final controller = _controller;
    if (_done || site == null || controller == null) return;
    if (_fadingOut) {
      // The copy is gone once faded, even if the flight's other springs
      // are still settling: the destination carries those on. Removing the
      // entry disposes this controller, so not from inside its own tick.
      if (controller.value(MotionDraggableTrack.handoffFade) <= 0.01 &&
          !_finishScheduled) {
        _finishScheduled = true;
        SchedulerBinding.instance.addPostFrameCallback(
          (_) => _finish(landed: true),
        );
      }
      return;
    }
    if (phase == MotionDragPhase.dragging || !_resolved) return;
    final receiver = site.flightReceiver;
    final rect = site.globalRect;
    final slot = receiver?.layoutRect;
    if (receiver == null || rect == null || slot == null) return;
    final handoff = widget.handoff;
    if (handoff == MotionDragHandoff.never) return;
    final size = controller.value(MotionDraggableTrack.size);
    if ((size.width - rect.width).abs() > 0.5 ||
        (size.height - rect.height).abs() > 0.5) {
      return;
    }
    final offset = controller.value(MotionDraggableTrack.offset);
    if (handoff == MotionDragHandoff.onEnter) {
      final visible = _visibleRect(site);
      if (visible == null) return;
      final center = (rect.topLeft + offset) & rect.size;
      if (!visible.contains(center.center) || !visible.overlaps(slot)) return;
    }
    receiver.receiveFlight(
      offset: offset,
      velocity: controller.velocity(MotionDraggableTrack.offset),
    );
    site.receiveVisuals([
      for (final track in feedbackRests.keys)
        track.value(
          controller.value(track),
          velocity: controller.velocity(track),
        ),
    ]);
    // The overlay copy fades out on top while the destination, now drawn in
    // the tree, carries on, so the change of layer reads as a transition.
    // It keeps following where the destination is painted.
    final fade =
        widget.motions?[MotionDraggableTrack.handoffFade] ??
        const CupertinoMotion.smooth(duration: Duration(milliseconds: 150));
    if (fade == const Motion.instant()) {
      _finish(landed: true);
      return;
    }
    _fadingOut = true;
    registry.beginFade(id);
    _endLanding();
    controller.animate([
      MotionDraggableTrack.handoffFade([TrackStep.to(0, motion: fade)]),
    ]);
  }

  /// Where the destination can be seen, in global coordinates.
  Rect? _visibleRect(LandingSite site) => site.visibleRect ?? _overlayRect();

  /// The rect to clip the feedback to, in global coordinates, or null.
  ///
  /// Once the feedback's center is inside the destination's visible area,
  /// it belongs to the destination, which clips it. The flight is still in
  /// the overlay only because the destination's slot is out of view, so it
  /// clips itself to the same area.
  Rect? _clip() {
    final site = _site;
    final controller = _controller;
    if (_fadingOut) return site?.visibleRect;
    if (site == null ||
        controller == null ||
        widget.handoff != MotionDragHandoff.onEnter ||
        site.flightReceiver == null ||
        site.visibleRect == null) {
      return null;
    }
    final visible = site.visibleRect!;
    if (_clippedToSite) return visible;
    final center = globalTopLeft & controller.value(MotionDraggableTrack.size);
    // Once the card has entered the destination's visible area, it stays
    // clipped there for the rest of the landing, even as it flies on toward
    // a slot out of view and its center leaves that area.
    _clippedToSite = visible.contains(center.center);
    return _clippedToSite ? visible : null;
  }

  Rect? _overlayRect() {
    final box = overlay.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _loseSite(LandingSite site) {
    _lossScheduled = false;
    final controller = _controller;
    if (_done || controller == null || _site != site) return;
    final global = globalTopLeft;
    final velocity = controller.velocity(MotionDraggableTrack.offset);
    _site = null;
    controller.set([
      MotionDraggableTrack.offset.value(global, velocity: velocity),
    ]);
    // Another site may have taken over the id, such as the item that
    // replaces a drop zone's gap, or a lazy list's rebuilt destination.
    if (_findSite() case final found?) {
      _landOn(found.site, found.rect);
      _applyTransitions();
    } else {
      // The exit starts before the coast, which may settle at once when the
      // flight was at rest, so that it doesn't end the flight first.
      _applyTransitions();
      _coast(velocity: velocity);
    }
    _checkSettled();
  }

  void _resize() {
    _resizeScheduled = false;
    final controller = _controller;
    final rect = _siteRect;
    if (_done || controller == null || _site == null || rect == null) return;
    controller.animate([
      MotionDraggableTrack.size([
        TrackStep.to(
          rect.size,
          motion: _motionFor(MotionDraggableTrack.size),
        ),
      ]),
    ]);
  }

  void _applyTransitions() {
    final controller = _controller;
    if (controller == null) return;
    final details = this.details;
    final animations =
        widget.transitions?.call(details) ?? _defaultTransitions(details);
    final mentioned = <Track<Object>>{};
    final resolved = <TrackAnimation<Object>>[
      for (final animation in animations)
        if (mentioned.add(animation.track))
          if (animation.track is! MotionDraggableTrack<Object>)
            animation
          else if (_visual(animation) case final visual?)
            visual,
      for (final MapEntry(key: track, value: rest) in feedbackRests.entries)
        if (!mentioned.contains(track))
          track([TrackStep.to(rest, motion: _motionFor(track))]),
      // It turns into what it lands on after an accepted drop, and back
      // into itself otherwise.
      MotionDraggableTrack.morph([
        TrackStep.to(
          phase == MotionDragPhase.accepted && _site != null ? 1.0 : 0.0,
          motion: _motionFor(MotionDraggableTrack.morph),
        ),
      ]),
    ];
    controller.animate(resolved);
  }

  /// [animation] of one of the feedback's visual tracks, with the track's
  /// motion for the steps that have none, or null for a track the draggable
  /// owns, which a transition can't animate.
  TrackAnimation<double>? _visual(TrackAnimation<Object> animation) {
    final track = animation.track;
    if (track is! MotionDraggableTrack<double> ||
        !feedbackRests.containsKey(track)) {
      assert(
        false,
        'MotionDraggable.transitions can only animate the visual tracks '
        '(scale, rotation and opacity) of MotionDraggableTrack: the draggable '
        'owns $track.',
      );
      return null;
    }
    final motion = _motionFor(track);
    return track(
      [
        for (final step in animation.steps)
          switch (step) {
            StepTo(
              :final double value,
              motion: null,
              motionPerDimension: null,
              :final until,
            ) =>
              TrackStep.to(value, motion: motion, until: until),
            StepAt(
              :final at,
              :final double value,
              motion: null,
              motionPerDimension: null,
            ) =>
              TrackStep.at(at, value, motion: motion),
            _ => step as TrackStep<double>,
          },
      ],
      from: animation.from as double?,
      withVelocity: animation.withVelocity as double?,
      delay: animation.delay,
    );
  }

  static List<TrackAnimation<Object>> _defaultTransitions(
    MotionDragDetails drag,
  ) {
    if (drag.phase == MotionDragPhase.dragging || drag.destination != null) {
      return const [];
    }
    return [
      MotionDraggableTrack.scale([const TrackStep.to(0)]),
      MotionDraggableTrack.opacity([const TrackStep.to(0)]),
    ];
  }

  void _checkSettled() {
    final controller = _controller;
    if (_done || controller == null) return;
    if (phase == MotionDragPhase.dragging || !_resolved) return;
    if (controller.status.isAnimating) return;
    if (_site?.holdsLanding ?? false) return;
    _finish(landed: true);
  }

  void _endLanding() {
    if (!_landingMarked) return;
    _landingMarked = false;
    registry.endLanding(id);
  }

  void _finish({required bool landed}) {
    if (_done) return;
    _done = true;
    _active.remove(this);
    _endLanding();
    _endFade();
    _entry
      ..remove()
      ..dispose();
    _notifyFinished();
    if (landed) widget.onLanded?.call();
  }

  void _endFade() {
    if (!_fadingOut) return;
    _fadingOut = false;
    registry.endFade(id);
  }

  void _attach(_FlightViewState view) {
    _view = view;
    view._controller
      ..addStatusListener(_onStatus)
      ..addListener(_tryHandOff);
    if (phase == MotionDragPhase.dragging) {
      _applyTransitions();
    } else {
      // The drag ended before the entry first built.
      _coast();
    }
  }

  void _detach(_FlightViewState view) {
    if (_view != view) return;
    view._controller
      ..removeStatusListener(_onStatus)
      ..removeListener(_tryHandOff);
    _view = null;
    if (_done) return;
    // The overlay went away while the flight was still in it.
    _done = true;
    _active.remove(this);
    _endLanding();
    _endFade();
    _notifyFinished();
  }

  void _onStatus(AnimationStatus status) {
    if (!status.isAnimating) _checkSettled();
  }

  void _grab(PointerDownEvent event) => _site?.grab(event, this);

  void _endGrab(PointerEvent event) => _site?.endGrab(this);
}

class _FlightView extends StatefulWidget {
  const _FlightView({required this.flight});

  final DragFlight flight;

  @override
  State<_FlightView> createState() => _FlightViewState();
}

class _FlightViewState extends State<_FlightView>
    with FixedTickerProviderStateMixin, WidgetTickerRateMixin {
  late final TrackController _controller;

  DragFlight get _flight => widget.flight;

  @override
  TickerRate? get widgetTickerRate => _flight.widget.tickerRate;

  @override
  void initState() {
    super.initState();
    _controller = TrackController(
      vsync: this,
      initialValues: [
        MotionDraggableTrack.offset.value(_flight._pointer - _flight._anchor),
        MotionDraggableTrack.size.value(_flight._initialSize),
      ],
      debugLabel: _flight.widget.debugLabel ?? 'MotionDraggable',
    );
    _flight._attach(this);
  }

  @override
  void dispose() {
    _flight._detach(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _buildFlight(context),
    );
  }

  Widget _buildFlight(BuildContext context) {
    final flight = _flight.._measure();
    final config = flight.widget;
    final value = _controller.value;
    final overlayBox = flight.overlay.context.findRenderObject();
    final global = flight.globalTopLeft;
    final topLeft = overlayBox is RenderBox && overlayBox.hasSize
        ? overlayBox.globalToLocal(global)
        : global;
    final size = value(MotionDraggableTrack.size);
    final details = flight.details;
    final dragging = flight.phase == MotionDragPhase.dragging;
    final grabbable = flight.isRegrabbable;

    final feedback = config.child;
    final site = flight._site;
    final clip = flight._clip();
    final localClip = clip == null
        ? null
        : overlayBox is RenderBox && overlayBox.hasSize
        ? overlayBox.globalToLocal(clip.topLeft) & clip.size
        : clip;
    // The clip and the stack stay in the tree whether or not they clip, so
    // the feedback keeps its state.
    return Positioned.fill(
      child: ClipRect(
        clipper: _RectClipper(localClip),
        clipBehavior: localClip == null ? Clip.none : Clip.hardEdge,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: topLeft.dx,
              top: topLeft.dy,
              width: size.width,
              height: size.height,
              // While landing, the feedback follows where the destination is
              // painted when the frame is composited, after it has moved
              // this frame. Until the destination has painted its leader,
              // and while there is none, it shows where it is positioned.
              // The follower stays in the tree either way, so the feedback
              // keeps its state.
              child: CompositedTransformFollower(
                link: site?.landingLink ?? flight._unlinked,
                // After a hand-off the destination paints the card itself,
                // so the fading copy sits right on top of it.
                offset: site == null || flight._fadingOut
                    ? Offset.zero
                    : value(MotionDraggableTrack.offset),
                child: _buildContent(
                  context,
                  flight: flight,
                  details: details,
                  dragging: dragging,
                  grabbable: grabbable,
                  feedback: feedback,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required DragFlight flight,
    required MotionDragDetails details,
    required bool dragging,
    required bool grabbable,
    required Widget feedback,
  }) {
    final config = flight.widget;
    final value = _controller.value;
    return Listener(
      behavior: grabbable
          ? HitTestBehavior.opaque
          : HitTestBehavior.deferToChild,
      onPointerDown: grabbable ? flight._grab : null,
      onPointerUp: flight._endGrab,
      onPointerCancel: flight._endGrab,
      child: IgnorePointer(
        ignoring: !dragging || config.ignoringFeedbackPointer,
        child: ExcludeSemantics(
          excluding: config.ignoringFeedbackSemantics,
          child: Opacity(
            opacity:
                (value(MotionDraggableTrack.opacity) *
                        value(MotionDraggableTrack.handoffFade))
                    .clamp(0, 1),
            child: Transform.rotate(
              angle: value(MotionDraggableTrack.rotation) * 2 * math.pi,
              child: Transform.scale(
                scale: value(MotionDraggableTrack.scale),
                child: config.feedback?.call(context, details) ?? feedback,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RectClipper extends CustomClipper<Rect> {
  const _RectClipper(this.rect);

  final Rect? rect;

  @override
  Rect getClip(Size size) => rect ?? Offset.zero & size;

  @override
  bool shouldReclip(_RectClipper oldClipper) => oldClipper.rect != rect;
}
