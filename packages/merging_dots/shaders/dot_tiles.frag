#version 460 core

// Renders a grid of cells that fuse into rounded letterforms.
//
// Unlike the gooey grid, filled cells fill their whole square. Neighbors
// join with straight edges, a corner is rounded only where nothing else
// meets it, and an empty cell wedged between two filled neighbors carves
// a concave fillet. Every pixel only needs its own cell and the three cells
// around its nearest cell corner.

#include <flutter/runtime_effect.glsl>

precision highp float;

// Premultiplied fill color.
uniform vec4 uColor;
// Top left corner of cell (0, 0), in local pixels.
uniform vec2 uOrigin;
// Columns and rows.
uniform vec2 uGrid;
// Size of a cell, in local pixels.
uniform float uCell;
// Radius of free outer corners, in cells (0 = square, 0.5 = quarter circle).
uniform float uCornerRadius;
// Radius of inner corners, in cells.
uniform float uInnerRadius;
// Shrinks every shape by this, in cells. Negative values fatten.
uniform float uPadding;
// Width of the anti-aliased edge, in local pixels.
uniform float uAa;
// 1 when uData was rendered on the GPU instead of uploaded, which flips it
// on OpenGL ES.
uniform float uFlip;

// r: the cell's value (255 / 200 = 1.275 maximum).
uniform sampler2D uData;

out vec4 fragColor;

float valueAt(vec2 cell) {
  if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= uGrid.x || cell.y >= uGrid.y) {
    return 0.0;
  }
  vec2 uv = (cell + 0.5) / uGrid;
#ifdef IMPELLER_TARGET_OPENGLES
  if (uFlip > 0.5) {
    uv.y = 1.0 - uv.y;
  }
#endif
  return texture(uData, uv).r * 1.275;
}

// A rounded box of half size `extent` centered at `center`, its corners
// rounded by `radius`. Positive outside.
float roundedBox(vec2 p, vec2 center, vec2 extent, float radius) {
  vec2 q = abs(p - center) - (extent - radius);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// The union of two distances with a circular fillet of radius `r` in every
// concave corner between them.
float filletUnion(float a, float b, float r) {
  if (r <= 0.0) {
    return min(a, b);
  }
  vec2 u = max(vec2(r - a, r - b), 0.0);
  return max(r, min(a, b)) - length(u);
}

// The polynomial smooth union of two distances, bulging by up to k / 4
// where they meet.
float gooUnion(float a, float b, float k) {
  if (k <= 0.0) {
    return min(a, b);
  }
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

// How much a neighbor of value `v` squares off the corner it shares with a
// cell: not at all until it is half filled, completely once it is full.
float squaring(float v) {
  return smoothstep(0.5, 1.0, v);
}

// A cell at `center` with value `v`, its horizontal neighbor toward the
// shared corner `beside`, its vertical one `above`, and the diagonal one
// `diagonal`: a dot that grows into its rounded
// square. Its corner toward the shared corner at (0.5, 0.5) squares off
// while any of the other three cells around that corner fill, so filled
// neighbors meet flush and diagonal ones in a neck. The corner only ever
// shows in this cell's quarter toward the shared corner, where it is
// computed, so neighboring pixels agree.
float cellBody(
    vec2 p,
    vec2 center,
    float v,
    float beside,
    float above,
    float diagonal) {
  if (v <= 0.002) {
    return 1e4;
  }
  float extent = 0.5 * v;
  float filled = squaring(min(v, 1.0));
  float joined =
      max(squaring(beside), max(squaring(above), squaring(diagonal)));
  float radius = min(uCornerRadius * v, extent) * (1.0 - filled * joined);
  // Toward a neighbor that is there, a filling cell stretches to their
  // shared edge, so it reads as flowing out of that neighbor. It reaches a
  // hair past the edge, so two full cells overlap instead of leaving a
  // seam where they touch. Each axis only depends on the neighbor on that
  // side, which every pixel sharing that side agrees on.
  float stretch = smoothstep(0.2, 0.8, min(v, 1.0));
  vec2 toward = vec2(smoothstep(0.3, 0.8, beside), smoothstep(0.3, 0.8, above));
  vec2 extents = vec2(extent) + (vec2(0.52) - extent) * toward * stretch;
  return roundedBox(p, center, max(extents, vec2(extent)), radius);
}

// Orthogonal neighbors melt together like goo while the smaller of the two
// fills. The blend peaks halfway and vanishes at both ends, so the cells
// are separate when one is empty and flush when both are full.
float gooPair(float bodyA, float bodyB, float va, float vb) {
  float m = min(min(va, 1.0), min(vb, 1.0));
  if (m <= 0.002) {
    return 1e4;
  }
  // The goo also fades out as the facing corners square off, so it never
  // bulges the straight edge of a join that is about to settle.
  return gooUnion(
    bodyA,
    bodyB,
    2.4 * m * (1.0 - m) * (1.0 - smoothstep(0.75, 1.0, m)));
}

void main() {
  vec2 p = (FlutterFragCoord().xy - uOrigin) / uCell - 0.5;
  vec2 cell = floor(p + 0.5);
  vec2 local = p - cell;
  // Mirror into the quadrant toward the nearest cell corner. The shape there
  // only depends on the four cells around that corner: this one at the
  // origin, its side neighbor h, the one above or below v, the diagonal dg.
  vec2 s = vec2(local.x < 0.0 ? -1.0 : 1.0, local.y < 0.0 ? -1.0 : 1.0);
  vec2 q = local * s;

  float a = max(valueAt(cell), 0.0);
  float h = max(valueAt(cell + vec2(s.x, 0.0)), 0.0);
  float v = max(valueAt(cell + vec2(0.0, s.y)), 0.0);
  float dg = max(valueAt(cell + s), 0.0);

  const vec2 pa = vec2(0.0, 0.0);
  const vec2 ph = vec2(1.0, 0.0);
  const vec2 pv = vec2(0.0, 1.0);
  const vec2 pd = vec2(1.0, 1.0);

  // Every piece grows continuously with the values, so cells, joins,
  // corners and fillets all morph instead of switching at a threshold. At
  // rest, with values of 0 and 1, the result is exactly the tile shape:
  // full cells, straight joins, round free corners, and fillets of the
  // inner radius in concave corners, holes and diagonal necks.
  //
  // Each cell's body knows the other three cells around the shared corner.
  float bodyA = cellBody(q, pa, a, h, v, dg);
  float bodyH = cellBody(q, ph, h, a, dg, v);
  float bodyV = cellBody(q, pv, v, dg, a, h);
  float bodyD = cellBody(q, pd, dg, v, h, a);
  float joinH = gooPair(bodyA, bodyH, a, h);
  float joinV = gooPair(bodyA, bodyV, a, v);
  float joinHD = gooPair(bodyH, bodyD, h, dg);
  float joinVD = gooPair(bodyV, bodyD, v, dg);
  float r = uInnerRadius;
  float d = min(min(bodyA, bodyH), min(bodyV, bodyD));
  d = min(d, min(min(joinH, joinV), min(joinHD, joinVD)));
  // Concave corners at rest, holes and diagonal necks all form between
  // diagonally opposite cells meeting at the shared corner, so only those
  // get a fillet of the inner radius. They are filleted body to body: a
  // join with a cell they share would put that cell on both sides and
  // bulge the fillet around it.
  d = min(d, filletUnion(bodyH, bodyV, r));
  d = min(d, filletUnion(bodyA, bodyD, r));

  d = (d + uPadding) * uCell;
  float alpha = clamp(0.5 - d / uAa, 0.0, 1.0);
  fragColor = uColor * alpha;
}
