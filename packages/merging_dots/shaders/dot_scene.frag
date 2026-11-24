#version 460 core

// Renders up to four layers of freely placed dots, like a character's body
// with eyes cut out of it.
//
// Each layer merges its own dots with its own smoothing. A dot sits between
// two layers while it moves from one to the other and then counts half on
// each. A layer that cuts removes its shape from all layers below it with a
// smooth subtraction; one that inverts flips them, a smooth XOR. Then
// everything is composited bottom to top.

#include <flutter/runtime_effect.glsl>

precision highp float;

// Top left corner of the dot positions, in local pixels.
uniform vec2 uOrigin;
// Positions, radii and layers are stored as fractions of this.
uniform float uSpan;
// How many dots uDots holds.
uniform float uCount;
// Width of uDots, in texels.
uniform float uDotsWidth;
// Width of the anti-aliased edge, in local pixels.
uniform float uAa;
// 1 when the data was rendered on the GPU instead of uploaded, which flips
// it on OpenGL ES.
uniform float uFlip;

// Per layer:
// color: premultiplied color.
// look: opacity, smoothing in pixels, mode (0 over, 1 cut, 2 invert, plus
//       4 when the layer is clipped, painted on the first layer),
//       smoothing of the edges it makes in the layers below, in pixels.
// shape: offset in pixels, height scale, radius scale.
uniform vec4 uColor0;
uniform vec4 uLook0;
uniform vec4 uShape0;
uniform vec4 uColor1;
uniform vec4 uLook1;
uniform vec4 uShape1;
uniform vec4 uColor2;
uniform vec4 uLook2;
uniform vec4 uShape2;
uniform vec4 uColor3;
uniform vec4 uLook3;
uniform vec4 uShape3;

// Four texels per dot, as 16 bit fractions of uSpan, of 4 for the layer
// and of 2 * uSpan around 0.5 for the stretch: (x high, x low, y high),
// (y low, radius high, radius low), (layer high, layer low, stretch x high),
// (stretch x low, stretch y high, stretch y low).
uniform sampler2D uDots;

out vec4 fragColor;

#include "smooth_union.glsl"

const int kMaxDots = 64;

vec2 dataUv(float column) {
  vec2 uv = vec2((column + 0.5) / uDotsWidth, 0.5);
#ifdef IMPELLER_TARGET_OPENGLES
  if (uFlip > 0.5) {
    uv.y = 1.0 - uv.y;
  }
#endif
  return uv;
}

float unpack(float high, float low) {
  return (high * 255.0 * 256.0 + low * 255.0) / 65535.0;
}

// Adds a capsule of radius r from `center` to `center + stretch`, which
// belongs to a layer by `share`, to that layer.
AngularUnion addTo(
    AngularUnion u,
    vec2 p,
    vec2 center,
    vec2 stretch,
    float r,
    float share,
    vec4 look,
    vec4 shape) {
  if (share <= 0.0) {
    return u;
  }
  float radius = r * share * shape.w;
  if (radius <= 0.0) {
    return u;
  }
  vec2 delta = p - center - shape.xy;
  // From the nearest point of the capsule's spine.
  float length2 = dot(stretch, stretch);
  if (length2 > 0.0) {
    delta -= stretch * clamp(dot(delta, stretch) / length2, 0.0, 1.0);
  }
  vec2 radii = vec2(radius, max(radius * shape.z, 0.01));
  // A cheap distance to an ellipse, exact for circles.
  vec2 g = delta / (radii * radii);
  float k0 = length(delta / radii);
  float k1 = length(g);
  float d = k1 > 0.0 ? k0 * (k0 - 1.0) / k1 : -min(radii.x, radii.y);
  vec2 direction = k1 > 0.0 ? g / k1 : vec2(0.0);
  // The blend is sent as the smoothing of the exponential union; the
  // angular union's radius is the blend itself.
  return angularUnionAdd(
      u, d, direction, min(radii.x, radii.y), look.y * 2.7725887);
}

float smin(float a, float b, float k) {
  if (k <= 0.0) {
    return min(a, b);
  }
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

float smax(float a, float b, float k) {
  return -smin(-a, -b, k);
}

// Cuts `shape` out of d, or flips d inside it, as much as its layer does.
float combine(float d, float shape, vec4 look) {
  float amount = clamp(look.x, 0.0, 1.0);
  // A clipped layer lies inside the first one, so inverting it only cuts.
  float mode = look.z > 3.5 ? min(look.z - 4.0, 1.0) : look.z;
  if (mode < 0.5 || amount <= 0.0 || shape > 1e3) {
    return d;
  }
  // A clipped layer lies inside the first one, so it has no corners to round
  // where it meets the outline, and rounding would open the outline.
  float k = look.z > 3.5 ? 0.0 : look.w;
  float result;
  if (mode < 1.5) {
    result = smax(d, -shape, k);
  } else {
    // Inside exactly one of the two.
    result = smax(smin(d, shape, k), -smax(d, shape, k), k);
  }
  return mix(d, result, amount);
}

float coverage(float d, vec4 look) {
  return clamp(0.5 - d / uAa, 0.0, 1.0) * clamp(look.x, 0.0, 1.0);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  AngularUnion u0 = angularUnionStart();
  AngularUnion u1 = angularUnionStart();
  AngularUnion u2 = angularUnionStart();
  AngularUnion u3 = angularUnionStart();

  for (int n = 0; n < kMaxDots; n++) {
    if (float(n) >= uCount) {
      break;
    }
    float column = float(n) * 4.0;
    vec4 a = texture(uDots, dataUv(column));
    vec4 b = texture(uDots, dataUv(column + 1.0));
    vec4 c = texture(uDots, dataUv(column + 2.0));
    vec4 e = texture(uDots, dataUv(column + 3.0));
    vec2 center = uOrigin + vec2(unpack(a.r, a.g), unpack(a.b, b.r)) * uSpan;
    float r = unpack(b.g, b.b) * uSpan;
    vec2 stretch =
        (vec2(unpack(c.b, e.r), unpack(e.g, e.b)) - 0.5) * 2.0 * uSpan;
    // Springs overshoot. Near a layer counts as on it, so a dot that
    // bounces into its new layer doesn't spill into the next one.
    float layer = unpack(c.r, c.g) * 4.0;
    layer = floor(layer) + smoothstep(0.2, 0.8, fract(layer));
    u0 = addTo(u0, p, center, stretch, r, 1.0 - abs(layer), uLook0, uShape0);
    u1 = addTo(u1, p, center, stretch, r, 1.0 - abs(layer - 1.0), uLook1, uShape1);
    u2 = addTo(u2, p, center, stretch, r, 1.0 - abs(layer - 2.0), uLook2, uShape2);
    u3 = addTo(u3, p, center, stretch, r, 1.0 - abs(layer - 3.0), uLook3, uShape3);
  }

  float d0 = angularUnionDistance(u0);
  float d1 = angularUnionDistance(u1);
  float d2 = angularUnionDistance(u2);
  float d3 = angularUnionDistance(u3);

  // Clipped layers are painted on the first layer, and stay a hair inside
  // its edge: an eye turned to the side wraps around the head instead of
  // biting into its outline.
  // The rim is a third of the layer's edge blend, and at least a pixel
  // and a half.
  if (uLook1.z > 3.5) {
    d1 = max(d1, d0 + max(1.5 * uAa, uLook1.w / 3.0));
  }
  if (uLook2.z > 3.5) {
    d2 = max(d2, d0 + max(1.5 * uAa, uLook2.w / 3.0));
  }
  if (uLook3.z > 3.5) {
    d3 = max(d3, d0 + max(1.5 * uAa, uLook3.w / 3.0));
  }

  d0 = combine(d0, d1, uLook1);
  d0 = combine(d0, d2, uLook2);
  d1 = combine(d1, d2, uLook2);
  d0 = combine(d0, d3, uLook3);
  d1 = combine(d1, d3, uLook3);
  d2 = combine(d2, d3, uLook3);

  vec4 color = uColor0 * coverage(d0, uLook0);
  float a1 = coverage(d1, uLook1);
  color = uColor1 * a1 + color * (1.0 - a1 * uColor1.a);
  float a2 = coverage(d2, uLook2);
  color = uColor2 * a2 + color * (1.0 - a2 * uColor2.a);
  float a3 = coverage(d3, uLook3);
  color = uColor3 * a3 + color * (1.0 - a3 * uColor3.a);
  fragColor = color;
}
