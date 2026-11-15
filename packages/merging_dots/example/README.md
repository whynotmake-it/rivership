# Merging Dots Editor

An editor for [merging_dots](../): draw dots on a grid or place them freely,
animate them over frames, save projects on your device, and export them as
Dart code or JSON for your app.

Run it on the web:

```sh
flutter create --platforms web .   # once; don't commit the generated folder
flutter run -d chrome
```

- **Grid**: click or drag to paint with the selected brush size. Starting a
  stroke on a cell that already has that size erases.
- **Freeform**: click to add a dot to every frame, drag to move it in this
  frame, scroll to resize it.
- **Frames**: duplicate the current frame, change it, and press play. The
  onion skin shows the previous frame.
- **Library**: templates to start from, and your saved projects.
- **Export**: copy Dart code or JSON. `Import` opens JSON again.

Shortcuts: <kbd>Space</kbd> plays, <kbd>Ctrl/Cmd</kbd> + <kbd>Z</kbd> undoes,
add <kbd>Shift</kbd> to redo.
