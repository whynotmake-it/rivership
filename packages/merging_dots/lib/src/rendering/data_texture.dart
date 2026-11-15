import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// A small RGBA texture of raw data that a dot shader reads, refreshed
/// every frame the dots change.
///
/// Where the engine supports it (Impeller), the bytes are uploaded directly
/// with `decodeImageFromPixelsSync`. Elsewhere (Skia, the web) they are
/// drawn as one batch of single-pixel quads and rasterized with
/// `toImageSync`, which costs an extra render pass but works everywhere.
///
/// Every pixel must be opaque, so premultiplication can't change the data.
class DotDataTexture {
  static bool? _directUploadSupported;

  ui.Image? _image;
  bool _rendered = false;

  // Quad geometry for the fallback, cached per size.
  int _meshWidth = 0;
  int _meshHeight = 0;
  Float32List _positions = Float32List(0);
  Int32List _colors = Int32List(0);
  Uint16List? _indices16;
  Uint32List? _indices32;

  /// The current texture, or null before the first [upload].
  ui.Image? get image => _image;

  /// Whether [image] was rendered on the GPU rather than uploaded. Shaders
  /// need to flip such textures vertically on OpenGL ES.
  bool get isRendered => _rendered;

  /// Replaces the texture with [rgba], `width * height * 4` bytes.
  void upload(Uint8List rgba, int width, int height) {
    assert(rgba.length == width * height * 4, 'Wrong number of bytes.');
    final previous = _image;
    _image =
        _uploadDirectly(rgba, width, height) ?? _render(rgba, width, height);
    previous?.dispose();
  }

  ui.Image? _uploadDirectly(Uint8List rgba, int width, int height) {
    if (_directUploadSupported == false) return null;
    try {
      final image = ui.decodeImageFromPixelsSync(
        rgba,
        width,
        height,
        ui.PixelFormat.rgba8888,
      );
      _directUploadSupported = true;
      _rendered = false;
      return image;
    } on Object {
      // Skia and the web don't implement it. Remember, so the failure is
      // only paid once.
      _directUploadSupported = false;
      return null;
    }
  }

  ui.Image _render(Uint8List rgba, int width, int height) {
    _ensureMesh(width, height);
    final colors = _colors;
    final pixels = width * height;
    for (var i = 0; i < pixels; i++) {
      final o = i * 4;
      final argb =
          0xFF000000 | (rgba[o] << 16) | (rgba[o + 1] << 8) | rgba[o + 2];
      final c = i * 4;
      colors[c] = argb;
      colors[c + 1] = argb;
      colors[c + 2] = argb;
      colors[c + 3] = argb;
    }
    final vertices = _indices16 != null
        ? ui.Vertices.raw(
            VertexMode.triangles,
            _positions,
            colors: colors,
            indices: _indices16,
          )
        : ui.Vertices.raw(
            VertexMode.triangles,
            _expand(_positions, _indices32!),
            colors: _expandColors(colors, _indices32!),
          );
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawVertices(vertices, BlendMode.dst, Paint());
    vertices.dispose();
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    _rendered = true;
    return image;
  }

  void _ensureMesh(int width, int height) {
    if (width == _meshWidth && height == _meshHeight) return;
    _meshWidth = width;
    _meshHeight = height;
    final pixels = width * height;
    _positions = Float32List(pixels * 8);
    _colors = Int32List(pixels * 4);
    final indices = pixels * 4 <= 65536
        ? (_indices16 = Uint16List(pixels * 6))
        : (_indices32 = Uint32List(pixels * 6));
    if (indices is Uint16List) _indices32 = null;
    if (indices is Uint32List) _indices16 = null;
    for (var i = 0; i < pixels; i++) {
      final x = (i % width).toDouble();
      final y = (i ~/ width).toDouble();
      _positions.setAll(i * 8, [x, y, x + 1, y, x + 1, y + 1, x, y + 1]);
      final v = i * 4;
      indices.setAll(i * 6, [v, v + 1, v + 2, v, v + 2, v + 3]);
    }
  }

  // Vertices.raw only takes 16 bit indices, so large meshes are expanded.
  static Float32List _expand(Float32List positions, Uint32List indices) {
    final out = Float32List(indices.length * 2);
    for (var i = 0; i < indices.length; i++) {
      out[i * 2] = positions[indices[i] * 2];
      out[i * 2 + 1] = positions[indices[i] * 2 + 1];
    }
    return out;
  }

  static Int32List _expandColors(Int32List colors, Uint32List indices) {
    final out = Int32List(indices.length);
    for (var i = 0; i < indices.length; i++) {
      out[i] = colors[indices[i]];
    }
    return out;
  }

  /// Releases the texture.
  void dispose() {
    _image?.dispose();
    _image = null;
  }
}
