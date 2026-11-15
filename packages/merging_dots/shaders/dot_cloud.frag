#version 460 core

// Renders freely placed dots that melt into each other.
//
// The cost per pixel grows with the number of dots, so this renderer is
// meant for up to 64 dots - spinners, blobs and small compositions. Use the
// grid renderer for dot-matrix art.

#include <flutter/runtime_effect.glsl>

precision highp float;

// Premultiplied fill color.
uniform vec4 uColor;
// x, y and radius of every dot, in local pixels. w is unused, it keeps the
// array aligned the same on every backend.
uniform vec4 uDots[64];
// How many entries of uDots are used.
uniform float uCount;
// Smooth union radius, in local pixels. 0 disables merging.
uniform float uBlend;
// Width of the anti-aliased edge, in local pixels.
uniform float uAa;

out vec4 fragColor;

float smoothUnion(float a, float b, float k) {
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float d = 1e4;

  for (int i = 0; i < 64; i++) {
    if (float(i) >= uCount) {
      break;
    }
    vec4 entry = uDots[i];
    if (entry.z <= 0.0) {
      continue;
    }
    float di = length(p - entry.xy) - entry.z;
    float k = min(uBlend, entry.z * 4.0);
    d = k > 0.0 ? smoothUnion(d, di, k) : min(d, di);
  }

  float alpha = clamp(0.5 - d / uAa, 0.0, 1.0);
  fragColor = uColor * alpha;
}
