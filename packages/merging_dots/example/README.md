# Merging Dots Editor

An editor for [merging_dots](../), built with [coil](../../coil): draw dots
on a grid or place them freely, animate them over frames, save projects on
your device, and export them as Dart code or JSON for your app.

Run it on the web (needs Flutter 3.47 or newer):

```sh
flutter create --platforms web .   # once; don't commit the generated folder
flutter run -d chrome
```

- **Grid**: Flip (F) switches cells, Draw (D) only adds ink, Erase (E) only
  removes it. Symmetry (X) mirrors strokes. `[` and `]` change the grid size.
- **Freeform**: Add (A) puts a dot into every frame, Select (V) drags one
  in this frame; scroll to resize it.
- **Frames**: duplicate the current frame, change it, and press Space to
  play. The onion skin shows the previous frame.
- **Style**: tiles or goo for grids, corner radii, blend and color.
- **Motion**: spring or curve, and a cascade that sweeps, ripples or
  scatters the change across the dots.
- **Library** (G): templates, and your saved projects. **Export** copies Dart
  code or JSON; **Import** opens JSON again.

Ctrl/Cmd + Z undoes, add Shift to redo.
