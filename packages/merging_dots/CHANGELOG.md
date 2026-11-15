## 0.1.0

- Initial release.
- `DotGridView` renders dot-matrix grids with two shapes: `goo`, an
  order-independent smooth union with configurable `blend`, and `tiles`,
  cells that fuse into rounded glyphs.
- `DotCloudView` renders thousands of freely placed dots, sorted into tiles
  so each pixel only reads its neighbors.
- `DotSequence` keyframe animation powered by motor, with staggers, loop
  modes, presets and JSON serialization.
