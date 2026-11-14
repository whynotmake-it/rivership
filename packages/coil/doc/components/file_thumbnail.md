# FileThumbnail

<!-- Generated from DESIGN.md by `dart run tool/generate_docs.dart`. Edit DESIGN.md instead. -->

```dart
import 'package:coil/file_thumbnail.dart';
```

Exports `CoilFileThumbnail`.

To change its look or composition, eject a copy into your app with `dart run coil:eject file_thumbnail` (see [SKILL.md](../../SKILL.md)). The full spec, including the tokens and rules these sections cite, is in [DESIGN.md](../../DESIGN.md).

## FileThumbnail

- **Anatomy:** a square preview (`size` required), radius item (or nested), `muted` background.
- **States:**
  - pending: spinner 24, muted;
  - image: cover-fit;
  - PDF: page 1 via a pluggable renderer;
  - failed or unsupported: a document glyph at 35 % of the size (min 16), muted.
- **Motion:** none of its own; the image fades in on `fade`.
- **Semantics:** an image labeled with the file name; the spinner announces "Loading preview".
