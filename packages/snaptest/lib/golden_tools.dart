/// Lower-level snaptest utilities for custom screenshot workflows.
///
/// Import this alongside `snaptest.dart` when you need direct access to
/// image capture, text blocking, or font loading helpers.
library;

export 'src/blocked_text_painting_context.dart'
    show BlockedTextCanvasAdapter, BlockedTextPaintingContext;
export 'src/font_loading.dart' show loadFont, loadFonts;
export 'src/snap.dart'
    show CaptureFinder, CaptureImage, precacheImages, setTestViewForDevice;
