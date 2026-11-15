#version 460 core

// Renders a grid of dots that melt into each other.
//
// Every cell's radius and offset come from a tiny data texture with one
// texel per cell, so the per-pixel cost is a fixed 5x5 neighborhood,
// independent of how many cells the grid has.

#include <flutter/runtime_effect.glsl>

precision highp float;

// Premultiplied fill color.
uniform vec4 uColor;
// Center of cell (0, 0), in local pixels.
uniform vec2 uOrigin;
// Columns and rows.
uniform vec2 uGrid;
// Distance between two cell centers, in local pixels.
uniform float uSpacing;
// Radius of a dot whose value is 1, in local pixels.
uniform float uRadius;
// Largest offset a dot can be moved by, in local pixels.
uniform float uOffset;
// Smoothing distance of the union, in local pixels. 0 disables merging.
uniform float uBlend;
// Width of the anti-aliased edge, in local pixels.
uniform float uAa;
// 1 when uData was rendered on the GPU instead of uploaded, which flips it
// on OpenGL ES.
uniform float uFlip;

// r: radius (255 / 200 = 1.275 maximum, so springs can overshoot),
// g, b: x and y offset (128 is centered).
uniform sampler2D uData;

out vec4 fragColor;

#include "smooth_union.glsl"

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 cell = floor((p - uOrigin) / uSpacing + 0.5);
  // Every dot within this distance of p is inside the 5x5 window, so
  // contributions fade out before it to keep window changes seamless.
  float window = 1.79 * uSpacing;
  SmoothUnion u = smoothUnionStart();

  for (int j = -2; j <= 2; j++) {
    for (int i = -2; i <= 2; i++) {
      vec2 c = cell + vec2(float(i), float(j));
      if (c.x < 0.0 || c.y < 0.0 || c.x >= uGrid.x || c.y >= uGrid.y) {
        continue;
      }
      vec2 uv = (c + 0.5) / uGrid;
#ifdef IMPELLER_TARGET_OPENGLES
      if (uFlip > 0.5) {
        uv.y = 1.0 - uv.y;
      }
#endif
      vec4 t = texture(uData, uv);
      float r = t.r * 1.275 * uRadius;
      if (r <= 0.0) {
        continue;
      }
      vec2 offset = (t.gb * 255.0 - 128.0) / 127.0 * uOffset;
      vec2 delta = p - (uOrigin + c * uSpacing + offset);
      float distance = length(delta);
      vec2 direction = distance > 0.0 ? delta / distance : vec2(0.0);
      u = smoothUnionAdd(u, distance - r, direction, r, distance, window, uBlend);
    }
  }

  float d = smoothUnionDistance(u, uBlend);
  float alpha = clamp(0.5 - d / uAa, 0.0, 1.0);
  fragColor = uColor * alpha;
}
