import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// What a lit shape is, which decides where its light falls.
///
/// The light always comes from above. A [raised] or [filled] shape catches
/// it on its top edge and casts a shadow below; a [recessed] one is a well,
/// shaded along its top and lit along its bottom; a [floating] one is a
/// container (card, popover) that only gets a quiet edge.
enum CoilReliefRole {
  /// A neutral control standing off the surface: secondary and
  /// destructive buttons, the switch thumb, the slider knob, the select
  /// trigger. Selection indicators (a tab's pill, a toggle group's
  /// segment) mark the current item rather than something to press, and
  /// are never lit.
  raised,

  /// A control with a strong fill: the primary button, an on switch, a
  /// selected radio dot. Its sheen and edges are tuned for dark and
  /// saturated fills.
  filled,

  /// A control that only shows a surface on hover or press, or is drawn
  /// with a hairline: tertiary and ghost buttons. Lit like [raised].
  quiet,

  /// A well a mark sits in: the switch's off track, the checkbox and
  /// radio boxes.
  recessed,

  /// A text field. Lit like [recessed].
  field,

  /// A slider's track, under its thumb. Lit like [recessed].
  track,

  /// A container above the page: cards, popovers, menus, dialogs.
  floating,
}

/// How plastic coil looks: from flat, the default, through softly lit, to
/// tactile. A token group on `CoilThemeData.plasticity`.
///
/// Each field is an intensity, 0 for none and 1 for the reference recipe
/// (opencode's desktop elevation tokens, see [subtle]). Values above 1
/// strengthen it. coil turns them into concrete colors and shadows per
/// [CoilReliefRole] and brightness with [resolve], so one setting reads
/// right on a white button, a black one, a blue switch and in dark mode.
///
/// The light comes from above. Hover brightens it, a press flattens it and
/// turns the top edge into a shadow (the control sinks in), and a disabled
/// control is flat.
///
/// ```dart
/// CoilThemeData(plasticity: CoilPlasticity.subtle)
/// // A quieter version for one subtree:
/// CoilTheme.override(
///   transform: (t) => t.copyWith(plasticity: t.plasticity.scale(0.5)),
///   child: Sidebar(),
/// )
/// ```
///
/// The ladder runs [flat] < [subtle] < [soft] < [tactile]. A future
/// glass material is meant to sit above [tactile]: it would be a preset
/// that also refracts what lies beneath, which painting alone can't do.
@immutable
class CoilPlasticity with Diagnosticable {
  /// Creates a plasticity. Every intensity defaults to 0 (none).
  const CoilPlasticity({
    this.edge = 0,
    this.edgeWidth = 1,
    this.highlight = 0,
    this.shade = 0,
    this.sheen = 0,
    this.lift = 0,
    this.recess = 0,
    this.containers = 0,
    this.response = 1,
    this.roles = const {},
  }) : assert(edgeWidth > 0, 'edgeWidth must be positive');

  /// No lighting: coil's flat look. The default.
  static const flat = CoilPlasticity();

  /// opencode's recipe, kept to what you press: a hairline edge lit at the
  /// top and darker at the bottom, a faint top highlight, a 1 px drop
  /// shadow and a light sheen on buttons, thumbs and the select trigger,
  /// with raised controls at 0.78 and filled ones at 0.8 of opencode's
  /// strength (`roles`). Wells
  /// (checkbox, radio, the off switch) get a hairline of shade, fields
  /// barely any; slider tracks, quiet buttons and containers stay flat.
  /// Hover and press move the light half as far as [soft] and [tactile].
  static const subtle = CoilPlasticity(
    edge: 1,
    edgeWidth: 0.5,
    highlight: 1,
    shade: 0.5,
    sheen: 1,
    lift: 1,
    recess: 0.6,
    containers: 1,
    response: 0.5,
    roles: {
      CoilReliefRole.raised: 0.78,
      CoilReliefRole.filled: 0.8,
      CoilReliefRole.quiet: 0,
      CoilReliefRole.recessed: 0.35,
      CoilReliefRole.field: 0.2,
      CoilReliefRole.track: 0,
      CoilReliefRole.floating: 0,
    },
  );

  /// Softly lit: a quieter edge, a visible top-to-bottom sheen on every
  /// control and a softer, larger shadow.
  static const soft = CoilPlasticity(
    edge: 0.6,
    highlight: 0.8,
    shade: 0.6,
    sheen: 2.2,
    lift: 2,
    recess: 0.5,
    containers: 1.4,
  );

  /// Tactile: a pronounced bevel (bright top rim, dark bottom rim), and
  /// inputs and tracks clearly pressed into the surface.
  static const tactile = CoilPlasticity(
    edge: 1.5,
    highlight: 1.8,
    shade: 1.6,
    sheen: 1.4,
    lift: 1.5,
    recess: 1.6,
    containers: 1.2,
  );

  /// The edge: a gradient outline, lighter at the top and darker at the
  /// bottom on raised shapes, the other way round on recessed ones.
  final double edge;

  /// The edge's stroke width in logical pixels, drawn inside the shape.
  final double edgeWidth;

  /// The inner rim of light along the top edge.
  final double highlight;

  /// The inner rim of shade along the bottom edge.
  final double shade;

  /// The fill's vertical gradient: lighter at the top.
  final double sheen;

  /// The drop shadow under raised and filled shapes.
  final double lift;

  /// How deep recessed shapes (inputs, tracks, boxes) look.
  final double recess;

  /// How lit floating containers (cards, popovers) are.
  final double containers;

  /// How far hover and press move the light, 0 (not at all) to 1 (fully
  /// brightened, fully sunk).
  final double response;

  /// A multiplier per role, for lighting some kinds of shape less than
  /// others: `{CoilReliefRole.track: 0}` keeps slider tracks flat. A
  /// missing role is 1; 0 turns that role off.
  final Map<CoilReliefRole, double> roles;

  /// Whether this paints nothing, so components keep their flat look
  /// untouched.
  bool get isFlat =>
      edge <= 0 &&
      highlight <= 0 &&
      shade <= 0 &&
      sheen <= 0 &&
      lift <= 0 &&
      recess <= 0 &&
      containers <= 0;

  /// Every intensity times [t]: `CoilPlasticity.subtle.scale(0.5)` is half
  /// as strong. The edge width stays.
  CoilPlasticity scale(double t) => CoilPlasticity(
    edge: edge * t,
    edgeWidth: edgeWidth,
    highlight: highlight * t,
    shade: shade * t,
    sheen: sheen * t,
    lift: lift * t,
    recess: recess * t,
    containers: containers * t,
    response: response,
    roles: roles,
  );

  /// Returns a copy with the given intensities replaced.
  CoilPlasticity copyWith({
    double? edge,
    double? edgeWidth,
    double? highlight,
    double? shade,
    double? sheen,
    double? lift,
    double? recess,
    double? containers,
    double? response,
    Map<CoilReliefRole, double>? roles,
  }) => CoilPlasticity(
    edge: edge ?? this.edge,
    edgeWidth: edgeWidth ?? this.edgeWidth,
    highlight: highlight ?? this.highlight,
    shade: shade ?? this.shade,
    sheen: sheen ?? this.sheen,
    lift: lift ?? this.lift,
    recess: recess ?? this.recess,
    containers: containers ?? this.containers,
    response: response ?? this.response,
    roles: roles ?? this.roles,
  );

  /// Interpolates two plasticities, for animated theme changes.
  // A static lerp, like Color.lerp and TextStyle.lerp.
  // ignore: prefer_constructors_over_static_methods
  static CoilPlasticity lerp(CoilPlasticity a, CoilPlasticity b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return CoilPlasticity(
      edge: l(a.edge, b.edge),
      edgeWidth: math.max(0.01, l(a.edgeWidth, b.edgeWidth)),
      highlight: l(a.highlight, b.highlight),
      shade: l(a.shade, b.shade),
      sheen: l(a.sheen, b.sheen),
      lift: l(a.lift, b.lift),
      recess: l(a.recess, b.recess),
      containers: l(a.containers, b.containers),
      response: l(a.response, b.response),
      roles: {
        for (final role in {...a.roles.keys, ...b.roles.keys})
          role: l(a.roles[role] ?? 1, b.roles[role] ?? 1),
      },
    );
  }

  /// The concrete lighting of a [role] shape in [brightness], or null when
  /// it gets none (this is [flat], or the control is disabled).
  ///
  /// [hover] (0 to 1) brightens the light: pass an animated value so it
  /// fades. [press] (0 to 1) flattens it and moves the shade to the top
  /// edge, as if the control sank in.
  CoilRelief? resolve(
    CoilReliefRole role,
    Brightness brightness, {
    double hover = 0,
    double press = 0,
    bool enabled = true,
  }) {
    if (!enabled || isFlat) return null;
    final k = roles[role] ?? 1;
    if (k <= 0) return null;
    final base = switch (role) {
      CoilReliefRole.quiet => CoilReliefRole.raised,
      CoilReliefRole.field || CoilReliefRole.track => CoilReliefRole.recessed,
      _ => role,
    };
    return (k == 1 ? this : scale(k))._resolve(
      base,
      brightness,
      hover * response,
      press * response,
    );
  }

  CoilRelief _resolve(
    CoilReliefRole role,
    Brightness brightness,
    double hover,
    double press,
  ) {
    final dark = brightness == Brightness.dark;
    Color w(double a) => Color.fromRGBO(255, 255, 255, a.clamp(0.0, 1.0));
    Color b(double a) => Color.fromRGBO(0, 0, 0, a.clamp(0.0, 1.0));

    // The reference recipe at intensity 1, per role and brightness. Alphas
    // follow opencode's v2 elevation tokens (packages/ui/src/theme/v2/
    // mapping.ts): `--v2-elevation-button-neutral`, `-button-contrast`,
    // `-input`, `-switch-off`/`-on`, `-raised`, and the
    // `linear-gradient(180deg, alpha-light-20, alpha-light-0)` sheen of
    // contrast buttons.
    final CoilRelief rest;
    switch (role) {
      case CoilReliefRole.raised || CoilReliefRole.quiet:
        rest = CoilRelief(
          edgeWidth: edgeWidth,
          edgeTop: dark ? w(0.22 * edge) : b(0.06 * edge),
          edgeBottom: dark ? w(0.05 * edge) : b(0.18 * edge),
          rimTop: dark ? w(0.10 * highlight) : w(0.85 * highlight),
          rimBottom: dark ? b(0.22 * shade) : b(0.05 * shade),
          sheenTop: dark ? w(0.025 * sheen) : w(0.22 * sheen),
          sheenBottom: dark ? b(0.06 * sheen) : b(0.02 * sheen),
          shadows: _drop(dark ? 0.40 : 0.10, dark ? 0.20 : 0.05),
        );
      case CoilReliefRole.filled:
        rest = CoilRelief(
          edgeWidth: edgeWidth,
          edgeTop: dark ? w(0.45 * edge) : w(0.20 * edge),
          edgeBottom: dark ? b(0.30 * edge) : b(0.35 * edge),
          rimTop: dark ? w(0.45 * highlight) : w(0.16 * highlight),
          rimBottom: b(0.10 * shade),
          sheenTop: w(0.10 * sheen),
          sheenBottom: b(0.06 * sheen),
          shadows: _drop(dark ? 0.40 : 0.18, dark ? 0.20 : 0.06),
        );
      case CoilReliefRole.recessed ||
          CoilReliefRole.field ||
          CoilReliefRole.track:
        final r = recess;
        rest = CoilRelief(
          edgeWidth: edgeWidth,
          edgeTop: dark ? b(0.45 * r) : b(0.13 * r),
          edgeBottom: dark ? w(0.10 * r) : b(0.03 * r),
          rimTop: dark ? b(0.30 * r) : b(0.06 * r),
          rimBottom: dark ? w(0.05 * r) : w(0.5 * r),
          sheenTop: dark ? b(0.14 * r) : b(0.035 * r),
          sheenBottom: dark ? w(0.015 * r) : w(0.2 * r),
          shadows: const [],
        );
      case CoilReliefRole.floating:
        final s = containers;
        rest = CoilRelief(
          edgeWidth: edgeWidth,
          edgeTop: dark ? w(0.14 * s) : b(0),
          edgeBottom: dark ? w(0.02 * s) : b(0.07 * s),
          rimTop: dark ? w(0.05 * s) : w(0.9 * s),
          rimBottom: b(0),
          sheenTop: dark ? w(0.02 * s) : w(0),
          sheenBottom: w(0),
          shadows: [
            if (s > 0)
              BoxShadow(
                color: b((dark ? 0.30 : 0.04) * s),
                offset: Offset(0, 2 * s),
                blurRadius: _cssBlur(4 * s),
              ),
          ],
        );
    }
    var relief = rest;
    if (hover > 0) relief = relief._brighten(hover);
    if (press > 0) relief = CoilRelief.lerp(relief, relief._sunk(), press)!;
    return relief;
  }

  /// The drop shadows at [lift]: opencode's `0 1px 1.5px` at intensity 1,
  /// plus a wider soft one that grows past it.
  List<BoxShadow> _drop(double near, double far) {
    if (lift <= 0) return const [];
    return [
      BoxShadow(
        color: Color.fromRGBO(
          0,
          0,
          0,
          (near * math.min(lift, 1.5)).clamp(0, 1),
        ),
        offset: const Offset(0, 1),
        blurRadius: _cssBlur(1.5),
      ),
      if (lift > 0.5)
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, (far * (lift - 0.5)).clamp(0, 1)),
          offset: Offset(0, 1 + lift),
          blurRadius: _cssBlur(2 + 3 * lift),
          spreadRadius: -lift / 2,
        ),
    ];
  }

  /// The [BoxShadow.blurRadius] whose sigma matches a CSS blur of
  /// [cssBlur] (CSS sigma is `B / 2`).
  static double _cssBlur(double cssBlur) =>
      math.max(0, (cssBlur / 2 - 0.5) / 0.57735);

  @override
  bool operator ==(Object other) =>
      other is CoilPlasticity &&
      other.edge == edge &&
      other.edgeWidth == edgeWidth &&
      other.highlight == highlight &&
      other.shade == shade &&
      other.sheen == sheen &&
      other.lift == lift &&
      other.recess == recess &&
      other.containers == containers &&
      other.response == response &&
      mapEquals(other.roles, roles);

  @override
  int get hashCode => Object.hash(
    edge,
    edgeWidth,
    highlight,
    shade,
    sheen,
    lift,
    recess,
    containers,
    response,
    Object.hashAllUnordered(
      roles.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('edge', edge, defaultValue: 0))
      ..add(DoubleProperty('edgeWidth', edgeWidth, defaultValue: 1))
      ..add(DoubleProperty('highlight', highlight, defaultValue: 0))
      ..add(DoubleProperty('shade', shade, defaultValue: 0))
      ..add(DoubleProperty('sheen', sheen, defaultValue: 0))
      ..add(DoubleProperty('lift', lift, defaultValue: 0))
      ..add(DoubleProperty('recess', recess, defaultValue: 0))
      ..add(DoubleProperty('containers', containers, defaultValue: 0))
      ..add(DoubleProperty('response', response, defaultValue: 1))
      ..add(DiagnosticsProperty('roles', roles, defaultValue: const {}));
  }
}

/// The lighting of one shape, resolved from a [CoilPlasticity] for its
/// role, brightness and state: what to paint over the fill and the shadows
/// to cast under it.
///
/// Paint it with [paint] after the fill, or let a [ShapeDecoration] do it
/// with [decorate]. All of it is plain fills and strokes with gradient
/// shaders: no layers, no clips.
@immutable
class CoilRelief {
  /// Creates a relief.
  const CoilRelief({
    required this.edgeWidth,
    required this.edgeTop,
    required this.edgeBottom,
    required this.rimTop,
    required this.rimBottom,
    required this.sheenTop,
    required this.sheenBottom,
    required this.shadows,
  });

  /// The edge stroke's width, inside the shape.
  final double edgeWidth;

  /// The edge's color at the top.
  final Color edgeTop;

  /// The edge's color at the bottom.
  final Color edgeBottom;

  /// The 1 px rim just inside the edge along the top.
  final Color rimTop;

  /// The 1 px rim just inside the edge along the bottom.
  final Color rimBottom;

  /// The sheen over the fill, at the top.
  final Color sheenTop;

  /// The sheen over the fill, at the bottom.
  final Color sheenBottom;

  /// Shadows cast under the shape.
  final List<BoxShadow> shadows;

  /// How far the rims reach in from the top and bottom before fading out.
  static const _rimReach = 3.0;

  /// [base] with this relief: its shape wrapped in a [CoilReliefBorder]
  /// that paints the lighting over the fill and the shadows around it.
  ///
  /// [base]'s shape must be a [RoundedSuperellipseBorder], or a
  /// [CoilReliefBorder], whose relief this one replaces: applying twice
  /// lights the shape once. Any other shape is a mistake (coil's shapes
  /// are superellipses); in release builds it is returned unlit.
  ShapeDecoration apply(ShapeDecoration base) {
    final shape = switch (base.shape) {
      final CoilReliefBorder lit => lit.shape,
      final RoundedSuperellipseBorder plain => plain,
      _ => null,
    };
    assert(
      shape != null,
      'CoilRelief.apply needs a RoundedSuperellipseBorder (or a '
      'CoilReliefBorder), not a ${base.shape.runtimeType}. coil lights '
      'superellipses only.',
    );
    if (shape == null) return base;
    return ShapeDecoration(
      color: base.color,
      gradient: base.gradient,
      image: base.image,
      shadows: base.shadows,
      shape: CoilReliefBorder(relief: this, shape: shape),
    );
  }

  /// [base] lit by [relief], or [base] itself, untouched, when [relief] is
  /// null.
  static ShapeDecoration decorate(ShapeDecoration base, CoilRelief? relief) =>
      relief == null ? base : relief.apply(base);

  /// Paints [shadows] around [shape], outside it only, like CSS
  /// `box-shadow`: a see-through fill (a tint, a ghost button) never shows
  /// its own shadow through it. So it can be painted before or after the
  /// fill. A [ShapeDecoration] from [apply] does it itself.
  void paintShadows(Canvas canvas, RSuperellipse shape) {
    if (shadows.isEmpty) return;
    var reach = 0.0;
    for (final s in shadows) {
      reach = math.max(
        reach,
        s.offset.distance + s.spreadRadius + s.blurSigma * 3,
      );
    }
    canvas
      ..save()
      ..clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(shape.outerRect.inflate(reach + 1))
          ..addRSuperellipse(shape),
      );
    for (final shadow in shadows) {
      if (shadow.color.a <= 0) continue;
      canvas.drawRSuperellipse(
        shape.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  /// Paints the sheen, rims and edge inside [shape], over its fill.
  void paint(Canvas canvas, RSuperellipse shape) {
    final rect = shape.outerRect;
    if (rect.isEmpty) return;
    Shader vertical(List<Color> colors, [List<double>? stops]) =>
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: stops,
        ).createShader(rect);

    if (sheenTop.a > 0 || sheenBottom.a > 0) {
      canvas.drawRSuperellipse(
        shape,
        Paint()..shader = vertical([sheenTop, sheenBottom]),
      );
    }
    if (rimTop.a > 0 || rimBottom.a > 0) {
      // One stroke just inside the edge, opaque only near the top and the
      // bottom: the rims follow the corners and fade down the sides.
      final reach = (_rimReach / rect.height).clamp(0.0, 0.5);
      canvas.drawRSuperellipse(
        shape.deflate(edgeWidth + 0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = vertical(
            [
              rimTop,
              rimTop.withValues(alpha: 0),
              rimBottom.withValues(alpha: 0),
              rimBottom,
            ],
            [0, reach, 1 - reach, 1],
          ),
      );
    }
    if (edgeTop.a > 0 || edgeBottom.a > 0) {
      canvas.drawRSuperellipse(
        shape.deflate(edgeWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = edgeWidth
          ..shader = vertical([edgeTop, edgeBottom]),
      );
    }
  }

  /// Returns a copy with the given fields replaced: `copyWith(shadows:
  /// const [])` for a shape that shouldn't cast one.
  CoilRelief copyWith({
    double? edgeWidth,
    Color? edgeTop,
    Color? edgeBottom,
    Color? rimTop,
    Color? rimBottom,
    Color? sheenTop,
    Color? sheenBottom,
    List<BoxShadow>? shadows,
  }) => CoilRelief(
    edgeWidth: edgeWidth ?? this.edgeWidth,
    edgeTop: edgeTop ?? this.edgeTop,
    edgeBottom: edgeBottom ?? this.edgeBottom,
    rimTop: rimTop ?? this.rimTop,
    rimBottom: rimBottom ?? this.rimBottom,
    sheenTop: sheenTop ?? this.sheenTop,
    sheenBottom: sheenBottom ?? this.sheenBottom,
    shadows: shadows ?? this.shadows,
  );

  /// This relief brighter by [t] (0 to 1): the hover response.
  CoilRelief _brighten(double t) {
    Color up(Color c, double by) =>
        c.withValues(alpha: (c.a * (1 + by * t)).clamp(0, 1));
    return CoilRelief(
      edgeWidth: edgeWidth,
      edgeTop: up(edgeTop, 0.4),
      edgeBottom: edgeBottom,
      rimTop: up(rimTop, 0.5),
      rimBottom: rimBottom,
      sheenTop: up(sheenTop, 0.5),
      sheenBottom: sheenBottom,
      shadows: [
        for (final s in shadows) s.copyWith(color: up(s.color, 0.25)),
      ],
    );
  }

  /// This relief pressed in: an even edge, the shade moved to the top, the
  /// sheen flipped and halved, the shadow nearly gone.
  CoilRelief _sunk() {
    final edge = Color.lerp(edgeTop, edgeBottom, 0.5)!;
    final depth = math.max(rimBottom.a, 0.04);
    return CoilRelief(
      edgeWidth: edgeWidth,
      edgeTop: edge,
      edgeBottom: edge,
      rimTop: Color.fromRGBO(0, 0, 0, depth),
      rimBottom: rimBottom.withValues(alpha: 0),
      sheenTop: sheenBottom.withValues(alpha: sheenBottom.a * 0.5),
      sheenBottom: sheenTop.withValues(alpha: sheenTop.a * 0.5),
      shadows: [
        for (final s in shadows)
          s.copyWith(color: s.color.withValues(alpha: s.color.a * 0.3)),
      ],
    );
  }

  /// Interpolates two reliefs. A null side is no lighting.
  static CoilRelief? lerp(CoilRelief? a, CoilRelief? b, double t) {
    if (a == null && b == null) return null;
    if (t <= 0 && a != null) return a;
    if (t >= 1 && b != null) return b;
    final from = a ?? b!._none();
    final to = b ?? a!._none();
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return CoilRelief(
      edgeWidth: from.edgeWidth + (to.edgeWidth - from.edgeWidth) * t,
      edgeTop: c(from.edgeTop, to.edgeTop),
      edgeBottom: c(from.edgeBottom, to.edgeBottom),
      rimTop: c(from.rimTop, to.rimTop),
      rimBottom: c(from.rimBottom, to.rimBottom),
      sheenTop: c(from.sheenTop, to.sheenTop),
      sheenBottom: c(from.sheenBottom, to.sheenBottom),
      shadows: BoxShadow.lerpList(from.shadows, to.shadows, t)!,
    );
  }

  /// This relief with every color clear, to fade from or to.
  CoilRelief _none() {
    Color clear(Color c) => c.withValues(alpha: 0);
    return CoilRelief(
      edgeWidth: edgeWidth,
      edgeTop: clear(edgeTop),
      edgeBottom: clear(edgeBottom),
      rimTop: clear(rimTop),
      rimBottom: clear(rimBottom),
      sheenTop: clear(sheenTop),
      sheenBottom: clear(sheenBottom),
      shadows: [for (final s in shadows) s.copyWith(color: clear(s.color))],
    );
  }

  /// This relief at [t] of its strength (0 none, 1 full).
  CoilRelief fade(double t) => t >= 1 ? this : lerp(_none(), this, t)!;

  @override
  bool operator ==(Object other) =>
      other is CoilRelief &&
      other.edgeWidth == edgeWidth &&
      other.edgeTop == edgeTop &&
      other.edgeBottom == edgeBottom &&
      other.rimTop == rimTop &&
      other.rimBottom == rimBottom &&
      other.sheenTop == sheenTop &&
      other.sheenBottom == sheenBottom &&
      listEquals(other.shadows, shadows);

  @override
  int get hashCode => Object.hash(
    edgeWidth,
    edgeTop,
    edgeBottom,
    rimTop,
    rimBottom,
    sheenTop,
    sheenBottom,
    Object.hashAll(shadows),
  );
}

/// A [RoundedSuperellipseBorder] that also paints a [CoilRelief] over the
/// fill: the sheen, the rims and the gradient edge, after [shape]'s own
/// side. Made by [CoilRelief.apply].
class CoilReliefBorder extends OutlinedBorder {
  /// Wraps [shape] with [relief].
  CoilReliefBorder({required this.relief, required this.shape})
    : super(side: shape.side);

  CoilReliefBorder._lerp(
    (CoilRelief?, RoundedSuperellipseBorder) a,
    (CoilRelief?, RoundedSuperellipseBorder) b,
    double t,
  ) : this(
        // At least one side is lit, so the lerp isn't null.
        relief: CoilRelief.lerp(a.$1, b.$1, t)!,
        shape: RoundedSuperellipseBorder(
          side: BorderSide.lerp(a.$2.side, b.$2.side, t),
          borderRadius: BorderRadiusGeometry.lerp(
            a.$2.borderRadius,
            b.$2.borderRadius,
            t,
          ),
        ),
      );

  /// The lighting.
  final CoilRelief relief;

  /// The shape and its own side.
  final RoundedSuperellipseBorder shape;

  @override
  EdgeInsetsGeometry get dimensions => shape.dimensions;

  @override
  ShapeBorder scale(double t) => CoilReliefBorder(
    relief: relief,
    shape: shape.scale(t) as RoundedSuperellipseBorder,
  );

  /// [border]'s relief and superellipse, or null when it is neither a
  /// [CoilReliefBorder] nor a [RoundedSuperellipseBorder].
  static (CoilRelief?, RoundedSuperellipseBorder)? _partsOf(
    ShapeBorder? border,
  ) => switch (border) {
    CoilReliefBorder(:final relief, :final shape) => (relief, shape),
    final RoundedSuperellipseBorder shape => (null, shape),
    _ => null,
  };

  /// Lerps from another lit or plain superellipse: the corners and side
  /// morph and the lighting fades, instead of [ShapeBorder.lerp]'s
  /// fallback, which shrinks one shape away and grows the other.
  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    final from = _partsOf(a);
    if (from == null) return super.lerpFrom(a, t);
    return CoilReliefBorder._lerp(from, (relief, shape), t);
  }

  /// See [lerpFrom].
  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    final to = _partsOf(b);
    if (to == null) return super.lerpTo(b, t);
    return CoilReliefBorder._lerp((relief, shape), to, t);
  }

  @override
  CoilReliefBorder copyWith({BorderSide? side}) => CoilReliefBorder(
    relief: relief,
    shape: shape.copyWith(side: side),
  );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      shape.getInnerPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      shape.getOuterPath(rect, textDirection: textDirection);

  @override
  bool get preferPaintInterior => true;

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) => shape.paintInterior(canvas, rect, paint, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    shape.paint(canvas, rect, textDirection: textDirection);
    final outline = shape.borderRadius
        .resolve(textDirection)
        .toRSuperellipse(rect);
    relief
      ..paintShadows(canvas, outline)
      ..paint(canvas, outline);
  }

  @override
  bool operator ==(Object other) =>
      other is CoilReliefBorder &&
      other.relief == relief &&
      other.shape == shape;

  @override
  int get hashCode => Object.hash(relief, shape);
}

/// Marks a subtree that sits on a surface above the page: a card, a
/// popover, a menu, a dialog, a sheet. `CoilSurface` places one for its
/// content, `elevated` when its level is above 1 (the page).
///
/// Lighting belongs on controls that sit on the page. On a surface that is
/// itself raised, lit controls compete with it, so `CoilTheme.of` reads a
/// [CoilPlasticity.flat] plasticity inside an elevated scope. A
/// component's style still wins: `CoilButtonStyle(plasticity: …)`, per
/// instance or through `CoilThemeData.withComponentStyle`, lights it
/// anyway. Wrap a subtree in `CoilPlasticityScope(elevated: false)` to
/// light it again.
class CoilPlasticityScope extends InheritedTheme {
  /// Marks [child] as [elevated] or not.
  const CoilPlasticityScope({
    required this.elevated,
    required super.child,
    super.key,
  });

  /// Whether [child] sits on a surface above the page.
  final bool elevated;

  /// Whether [context] sits on a surface above the page.
  static bool elevatedOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<CoilPlasticityScope>()
          ?.elevated ??
      false;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      CoilPlasticityScope(elevated: elevated, child: child);

  @override
  bool updateShouldNotify(CoilPlasticityScope oldWidget) =>
      oldWidget.elevated != elevated;
}
