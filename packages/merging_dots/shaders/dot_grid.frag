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
// Smooth union radius, in local pixels. 0 disables merging.
uniform float uBlend;
// Width of the anti-aliased edge, in local pixels.
uniform float uAa;

// r: radius (255 / 200 = 1.275 maximum, so springs can overshoot),
// g, b: x and y offset (128 is centered).
uniform sampler2D uData;

out vec4 fragColor;

float smoothUnion(float a, float b, float k) {
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 cell = floor((p - uOrigin) / uSpacing + 0.5);
  float d = 1e4;

  for (int j = -2; j <= 2; j++) {
    for (int i = -2; i <= 2; i++) {
      vec2 c = cell + vec2(float(i), float(j));
      if (c.x < 0.0 || c.y < 0.0 || c.x >= uGrid.x || c.y >= uGrid.y) {
        continue;
      }
      vec2 uv = (c + 0.5) / uGrid;
#ifdef IMPELLER_TARGET_OPENGLES
      uv.y = 1.0 - uv.y;
#endif
      vec4 t = texture(uData, uv);
      float r = t.r * 1.275 * uRadius;
      if (r <= 0.0) {
        continue;
      }
      vec2 offset = (t.gb * 255.0 - 128.0) / 127.0 * uOffset;
      float di = length(p - (uOrigin + c * uSpacing + offset)) - r;
      // Small dots blend less, so a dot fades out continuously.
      float k = min(uBlend, r * 4.0);
      d = k > 0.0 ? smoothUnion(d, di, k) : min(d, di);
    }
  }

  float alpha = clamp(0.5 - d / uAa, 0.0, 1.0);
  fragColor = uColor * alpha;
}
