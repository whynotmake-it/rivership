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
};

SmoothUnion smoothUnionStart() {
  return SmoothUnion(1e4, 0.0);
}

SmoothUnion smoothUnionAdd(
    SmoothUnion u,
    float d,
    float radius,
    float distance,
    float window,
    float k) {
  if (k <= 0.0) {
    u.m = min(u.m, d);
    u.s = 1.0;
    return u;
  }
  float w = clamp(4.0 * radius / k, 0.0, 1.0) *
            (1.0 - smoothstep(0.7 * window, window, distance));
  if (w <= 0.0) {
    return u;
  }
  if (d < u.m) {
    u.s = u.s * exp((d - u.m) / k) + w;
    u.m = d;
  } else {
    u.s += w * exp((u.m - d) / k);
  }
  return u;
}

float smoothUnionDistance(SmoothUnion u, float k) {
  if (u.s <= 0.0) {
    return 1e4;
  }
  if (k <= 0.0) {
    return u.m;
  }
  return u.m - k * log(u.s);
}
