import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';
import 'package:stupid_simple_sheet_example/widgets/sheet_previews.dart';

/// Preview for the home page card — interactive playground mockup.
class PlaygroundPreview extends StatelessWidget {
  const PlaygroundPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: MiniModal(
        width: 120,
        height: 80,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 6,
            children: [
              for (var i = 0; i < 3; i++)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: t.previewLine,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 18,
                      height: 10,
                      decoration: BoxDecoration(
                        color: i == 0 ? t.accentOrange : t.previewLine,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An interactive playground where developers can toggle every
/// [StupidSimpleSheetRoute] setting and immediately see the effect.
class PlaygroundPage extends StatefulWidget {
  const PlaygroundPage({super.key});

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage> {
  DismissalMode _dismissalMode = DismissalMode.slide;
  bool _draggable = true;
  bool _originateAboveBottomViewInset = false;
  bool _barrierDismissible = true;
  double _initialSnap = 1.0;
  bool _useMultipleSnaps = false;
  _MotionPreset _motionPreset = _MotionPreset.smooth;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CupertinoPageScaffold(
      backgroundColor: t.canvas,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('Playground'),
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),

                  // -- Dismissal Mode --
                  _SectionLabel('Dismissal Mode'),
                  const SizedBox(height: 8),
                  _OptionRow<DismissalMode>(
                    options: const {
                      DismissalMode.slide: 'Slide',
                      DismissalMode.shrink: 'Shrink',
                    },
                    selected: _dismissalMode,
                    onChanged: (v) => setState(() => _dismissalMode = v),
                    accentColor: t.accentBlue,
                    theme: t,
                  ),

                  const SizedBox(height: 24),

                  // -- Motion --
                  _SectionLabel('Motion'),
                  const SizedBox(height: 8),
                  _OptionRow<_MotionPreset>(
                    options: const {
                      _MotionPreset.smooth: 'Smooth',
                      _MotionPreset.snappy: 'Snappy',
                      _MotionPreset.bouncy: 'Bouncy',
                      _MotionPreset.interactive: 'Interactive',
                    },
                    selected: _motionPreset,
                    onChanged: (v) => setState(() => _motionPreset = v),
                    accentColor: t.accentGold,
                    theme: t,
                  ),

                  const SizedBox(height: 24),

                  // -- Toggles --
                  _SectionLabel('Options'),
                  const SizedBox(height: 8),
                  _ToggleTile(
                    label: 'Draggable',
                    value: _draggable,
                    onChanged: (v) => setState(() => _draggable = v),
                    theme: t,
                  ),
                  _ToggleTile(
                    label: 'Barrier Dismissible',
                    value: _barrierDismissible,
                    onChanged: (v) => setState(() => _barrierDismissible = v),
                    theme: t,
                  ),
                  _ToggleTile(
                    label: 'Originate Above Keyboard',
                    value: _originateAboveBottomViewInset,
                    onChanged: (v) =>
                        setState(() => _originateAboveBottomViewInset = v),
                    theme: t,
                  ),
                  _ToggleTile(
                    label: 'Multiple Snap Points',
                    value: _useMultipleSnaps,
                    onChanged: (v) => setState(() => _useMultipleSnaps = v),
                    theme: t,
                  ),

                  // -- Initial Snap slider --
                  if (_useMultipleSnaps) ...[
                    const SizedBox(height: 16),
                    _SectionLabel('Initial Snap'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: t.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '0%',
                            style: TextStyle(
                              fontSize: 13,
                              color: t.textTertiary,
                            ),
                          ),
                          Expanded(
                            child: CupertinoSlider(
                              value: _initialSnap,
                              min: 0.1,
                              max: 1.0,
                              divisions: 9,
                              onChanged: (v) =>
                                  setState(() => _initialSnap = v),
                            ),
                          ),
                          Text(
                            '${(_initialSnap * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // -- Open button --
                  _OpenButton(onPressed: _openSheet, theme: t),

                  const SizedBox(height: 48),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSheet() {
    final snappingConfig = _useMultipleSnaps
        ? SheetSnappingConfig(
            [0.3, 0.6, 1.0],
            initialSnap: _initialSnap.clamp(0.3, 1.0),
          )
        : SheetSnappingConfig.full;

    Navigator.of(context).push(
      StupidSimpleSheetRoute(
        dismissalMode: _dismissalMode,
        draggable: _draggable,
        barrierDismissible: _barrierDismissible,
        originateAboveBottomViewInset: _originateAboveBottomViewInset,
        snappingConfig: snappingConfig,
        motion: _motionPreset.motion,
        child: SheetBackground(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(child: Placeholder()),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CupertinoButton.filled(
                    child: const Text('Close'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: t.textTertiary,
      ),
    );
  }
}

/// A row of tappable option chips.
class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.accentColor,
    required this.theme,
  });

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final Color accentColor;
  final ExampleTheme theme;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in options.entries)
          GestureDetector(
            onTap: () => onChanged(entry.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: entry.key == selected
                    ? accentColor.withValues(alpha: .12)
                    : theme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: entry.key == selected
                      ? accentColor.withValues(alpha: .4)
                      : theme.borderSubtle,
                ),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      entry.key == selected ? FontWeight.w600 : FontWeight.w400,
                  color:
                      entry.key == selected ? accentColor : theme.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A toggle row matching the card surface style.
class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ExampleTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border(
            bottom: BorderSide(color: theme.borderSubtle, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.textPrimary,
                ),
              ),
            ),
            CupertinoSwitch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Open Sheet" button.
class _OpenButton extends StatelessWidget {
  const _OpenButton({required this.onPressed, required this.theme});

  final VoidCallback onPressed;
  final ExampleTheme theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: theme.textPrimary,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          'Open Sheet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.surface,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Motion presets
// ---------------------------------------------------------------------------

enum _MotionPreset {
  smooth,
  snappy,
  bouncy,
  interactive;

  Motion get motion => switch (this) {
        smooth => CupertinoMotion.smooth(snapToEnd: true),
        snappy => CupertinoMotion.snappy(snapToEnd: true),
        bouncy => CupertinoMotion.bouncy(snapToEnd: true),
        interactive => CupertinoMotion.interactive(snapToEnd: true),
      };
}
