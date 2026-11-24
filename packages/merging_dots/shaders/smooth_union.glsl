// An order-independent smooth union of signed distances.
//
// The union of distances d_i with smoothing k is the exponential smooth
// minimum -k * log(sum(w_i * exp(-d_i / k))). A sum doesn't depend on the
// order of its terms, so neither does the shape. It is accumulated as a
// running log-sum-exp (minimum m and scaled sum s), which never overflows.
//
// Each term is weighted:
// - by size, so a dot shrinking to nothing fades out instead of leaving a
//   bump on its neighbors and then popping away, and
// - by distance, fading to zero at `window`, beyond which the caller may
//   not see dots at all. That keeps the edge of the lookup seamless.

struct SmoothUnion {
  float m;
  float s;
  // The gradient, scaled like s: the weighted sum of each term's unit
  // direction. Near merges the union's slope drops below 1, and dividing
  // by it keeps the anti-aliased edge one pixel wide.
  vec2 g;
};

SmoothUnion smoothUnionStart() {
  return SmoothUnion(1e4, 0.0, vec2(0.0));
}

SmoothUnion smoothUnionAdd(
    SmoothUnion u,
    float d,
    vec2 direction,
    float radius,
    float distance,
    float window,
    float k) {
  if (k <= 0.0) {
    if (d < u.m) {
      u.m = d;
      u.g = direction;
    }
    u.s = 1.0;
    return u;
  }
  float w = clamp(4.0 * radius / k, 0.0, 1.0) *
            (1.0 - smoothstep(0.7 * window, window, distance));
  if (w <= 0.0) {
    return u;
  }
  if (d < u.m) {
    float scale = exp((d - u.m) / k);
    u.s = u.s * scale + w;
    u.g = u.g * scale + w * direction;
    u.m = d;
  } else {
    float term = w * exp((u.m - d) / k);
    u.s += term;
    u.g += term * direction;
  }
  return u;
}

float smoothUnionDistance(SmoothUnion u, float k) {
  if (u.s <= 0.0) {
    return 1e4;
  }
  float d = k <= 0.0 ? u.m : u.m - k * log(u.s);
  // Turn the field into a distance estimate by its slope.
  float slope = length(u.g) / u.s;
  return d / max(slope, 0.5);
}

// A smooth union whose blend radius follows the angle between the surfaces
// it joins, as in liquid_glass_renderer: zero where they run alongside
// each other, like the collinear sides of dots in a row, and the full
// radius where they face each other across a gap. A plain smooth minimum
// lifts aligned edges near a join, which makes rows of dots wavy; this
// keeps them straight while bridges and concave joins still round.
//
// It is a running polynomial smooth minimum, so unlike SmoothUnion it
// depends a little on the order shapes are added in. Keep that order
// stable from frame to frame.
//
// Shapes can have a depth. The blend fades as their depths grow apart,
// gone at twice the radius, so shapes that only overlap on screen, one far
// behind the other, overlap instead of melting together.

struct AngularUnion {
  float d;
  // The gradient of d, split between the joined shapes like the distance.
  // It shortens at a bridge's saddle, which the anti-aliasing divides by.
  vec2 g;
  // The depth of the surface, split like the gradient.
  float z;
};

AngularUnion angularUnionStart() {
  return AngularUnion(1e4, vec2(0.0), 0.0);
}

// Adds a shape at distance d with outward `direction`. A shape smaller
// than a quarter of k blends with less, so a dot shrinking to nothing
// fades out of its joins instead of popping.
AngularUnion angularUnionAdd(
    AngularUnion u,
    float d,
    vec2 direction,
    float radius,
    float depth,
    float k) {
  if (u.d >= 1e4) {
    return AngularUnion(d, direction, depth);
  }
  float blend = k * min(0.5 * length(u.g - direction), 1.0) *
                clamp(4.0 * radius / max(k, 1e-4), 0.0, 1.0) *
                clamp(1.0 - abs(u.z - depth) / max(2.0 * k, 1e-4), 0.0, 1.0);
  float e = max(blend - abs(u.d - d), 0.0);
  float joined = min(u.d, d) - e * e * 0.25 / max(blend, 1e-4);
  float weight = clamp(0.5 + (d - u.d) / (2.0 * max(blend, 1e-4)), 0.0, 1.0);
  return AngularUnion(
      joined, mix(direction, u.g, weight), mix(depth, u.z, weight));
}

float angularUnionDistance(AngularUnion u) {
  if (u.d >= 1e4) {
    return 1e4;
  }
  return u.d / max(length(u.g), 0.5);
}
