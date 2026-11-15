# SettingsDialog

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/settings_dialog.dart';
```

Exports `CoilSettingRow`, `CoilSettingsDialog`, `CoilSettingsList`, `CoilSettingsSection`, `showCoilSettingsDialog`.

To change its look or composition, eject a copy into your app with `dart run coil_cli:eject settings_dialog` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## SettingsDialog

- **Anatomy:** an `xl` dialog frame, `min(640, window − 64)` tall: a static sidebar of sections (208 wide, a 3 % `overlay` tint, no hairline) beside a panel with the section's heading, description and a scrolling body of setting rows.
- **Setting row:** label (body) and an optional description (caption, muted) at the start, the control at the end, 16 vertical padding, hairlines between rows. A toggle row is one tap target, and one semantics node named by the label and description (§ Field).
- **Compact (< 600):** the sidebar hides and a select at the top of the panel picks the section, under the dialog's title.
- **Touch, phone:** it opens as a sheet, like a form dialog.
- **Keyboard and semantics:** as the dialog and the sidebar; the title names the route; the close button sits in the corner.
