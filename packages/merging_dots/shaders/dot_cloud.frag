#version 460 core

// Renders freely placed dots that melt into each other.
//
// Dots are sorted into square tiles at least as large as a dot's reach, so
// every pixel only reads the dots of its own tile and the 8 around it. Two
// data textures hold the tiles and the dots, see `RenderDotCloud`.

#include <flutter/runtime_effect.glsl>

precision highp float;

// Premultiplied fill color.
uniform vec4 uColor;
// Top left corner of tile (0, 0), in local pixels.
uniform vec2 uOrigin;
// Columns and rows of tiles.
uniform vec2 uTiles;
// Width and height of uDots, in texels.
uniform vec2 uDotsSize;
// Size of a tile, in local pixels.
uniform float uTile;
// Positions and radii are stored as fractions of this, in local pixels.
uniform float uSpan;
// Smoothing distance of the union, in local pixels. 0 disables merging.
uniform float uBlend;
// Width of the anti-aliased edge, in local pixels.
uniform float uAa;
// 1 when the data was rendered on the GPU instead of uploaded, which flips
// it on OpenGL ES.
uniform float uFlip;

// One texel per tile: r, g: index of its first dot (high, low byte),
// b: how many dots it has.
uniform sampler2D uTileData;
// Two texels per dot, x, y and radius as 16 bit fractions of uSpan:
// (x high, x low, y high), (y low, radius high, radius low).
uniform sampler2D uDots;

out vec4 fragColor;

#include "smooth_union.glsl"

// The most dots one tile can hold.
const int kMaxDotsPerTile = 64;

vec2 dataUv(vec2 coord, vec2 size) {
  vec2 uv = (coord + 0.5) / size;
#ifdef IMPELLER_TARGET_OPENGLES
  if (uFlip > 0.5) {
    uv.y = 1.0 - uv.y;
  }
#endif
  return uv;
}

float unpack(float high, float low) {
  return (high * 255.0 * 256.0 + low * 255.0) / 65535.0 * uSpan;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 tile = floor((p - uOrigin) / uTile);
  SmoothUnion u = smoothUnionStart();

  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 t = tile + vec2(float(i), float(j));
      if (t.x < 0.0 || t.y < 0.0 || t.x >= uTiles.x || t.y >= uTiles.y) {
        continue;
      }
      vec4 entry = texture(uTileData, dataUv(t, uTiles));
      float start = floor(entry.r * 255.0 + 0.5) * 256.0 +
                    floor(entry.g * 255.0 + 0.5);
      float count = floor(entry.b * 255.0 + 0.5);
      for (int n = 0; n < kMaxDotsPerTile; n++) {
        if (float(n) >= count) {
          break;
        }
        float index = (start + float(n)) * 2.0;
        float row = floor(index / uDotsSize.x);
        float column = index - row * uDotsSize.x;
        vec4 a = texture(uDots, dataUv(vec2(column, row), uDotsSize));
        vec4 b = texture(uDots, dataUv(vec2(column + 1.0, row), uDotsSize));
        vec2 center = uOrigin + vec2(unpack(a.r, a.g), unpack(a.b, b.r));
        float r = unpack(b.g, b.b);
        float distance = length(p - center);
        u = smoothUnionAdd(u, distance - r, r, distance, uTile, uBlend);
      }
    }
  }

  float d = smoothUnionDistance(u, uBlend);
  float alpha = clamp(0.5 - d / uAa, 0.0, 1.0);
  fragColor = uColor * alpha;
}
