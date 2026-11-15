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

// Distance to a box of half size 0.5 centered at `center`, with the corner
// that faces the origin's quadrant rounded by `radius`. Positive outside.
float cornerBox(vec2 p, vec2 center, float radius) {
  vec2 q = abs(p - center) - vec2(0.5 - radius);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// Distance to the free corner of the cell at the origin: square up to the
// corner, rounded by `radius`. `p` is in the quadrant toward +x, +y.
float freeCorner(vec2 p, float radius) {
  vec2 q = p - vec2(0.5 - radius);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// Distance to the ink of a filled cell centered at `center`, near the
// corner at (0.5, 0.5). Its corner is square when `joined`, else rounded.
float neighborInk(vec2 p, vec2 center, bool joined) {
  vec2 q = abs(p - center) - vec2(0.5);
  float box = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
  if (joined) {
    return box;
  }
  // Only the corner toward (0.5, 0.5) is free.
  vec2 toCorner = vec2(0.5) - center;
  vec2 local = (p - center) * sign(toCorner);
  return freeCorner(local, uCornerRadius);
}

void main() {
  vec2 p = (FlutterFragCoord().xy - uOrigin) / uCell - 0.5;
  vec2 cell = floor(p + 0.5);
  vec2 local = p - cell;
  // Mirror into the quadrant toward the nearest cell corner.
  vec2 s = vec2(local.x < 0.0 ? -1.0 : 1.0, local.y < 0.0 ? -1.0 : 1.0);
  vec2 aq = local * s;

  float self = valueAt(cell);
  float h = valueAt(cell + vec2(s.x, 0.0));
  float v = valueAt(cell + vec2(0.0, s.y));
  float dg = valueAt(cell + s);
  bool C = self >= 0.5;
  bool H = h >= 0.5;
  bool V = v >= 0.5;
  bool D = dg >= 0.5;

  float d;
  if (C) {
    // The paper of an empty side or diagonal cell, its corner toward ours
    // rounded by the inner radius.
    float hPaper = -cornerBox(aq, vec2(1.0, 0.0), uInnerRadius);
    float vPaper = -cornerBox(aq, vec2(0.0, 1.0), uInnerRadius);
    float dPaper = -cornerBox(aq, vec2(1.0, 1.0), uInnerRadius);
    if (H && V) {
      d = D ? -1.0 : dPaper;
    } else if (H) {
      d = D ? vPaper : aq.y - 0.5;
    } else if (V) {
      d = D ? hPaper : aq.x - 0.5;
    } else if (D) {
      // Only diagonal: a neck, square at the shared corner.
      d = max(hPaper, vPaper);
    } else {
      d = freeCorner(aq, uCornerRadius);
      // A cell filling in grows from its inscribed disc to its full shape.
      float grow = clamp((self - 0.5) * 2.0, 0.0, 1.0);
      d = max(d, length(aq) - mix(0.5, 0.75, grow));
    }
  } else {
    // An empty cell: the nearest ink of its neighbors, plus the fillet
    // when two orthogonal neighbors are filled, plus its own growing dot.
    d = self > 0.0 ? length(aq) - self : 1.0;
    if (H) {
      d = min(d, neighborInk(aq, vec2(1.0, 0.0), V || D));
    }
    if (V) {
      d = min(d, neighborInk(aq, vec2(0.0, 1.0), H || D));
    }
    if (D) {
      d = min(d, neighborInk(aq, vec2(1.0, 1.0), H || V));
    }
    if (H && V) {
      d = min(d, -cornerBox(aq, vec2(0.0), uInnerRadius));
    }
  }

  d = (d + uPadding) * uCell;
  float alpha = clamp(0.5 - d / uAa, 0.0, 1.0);
  fragColor = uColor * alpha;
}
