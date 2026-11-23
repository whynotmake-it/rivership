import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/playground/sheet_config.dart';
import 'package:stupid_simple_sheet_example/shell/code_block.dart';
import 'package:stupid_simple_sheet_example/shell/demo_scaffold.dart';

/// Every setting of a `stupid_simple_sheet` route in one page: configure the
/// sheet, read the code that opens it, then open it.
class PlaygroundPage extends StatefulWidget {
  /// Creates the playground.
  const PlaygroundPage({super.key});

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage> {
  var _config = const SheetConfig();

  /// The width from which the settings and the code sit side by side.
  static const _twoColumnWidth = 900.0;

  /// How wide the settings column gets beside the code.
  static const _settingsWidth = 380.0;

  /// The widest the two columns get together.
  static const _wideContentWidth = 880.0;

  void _update(SheetConfig config) => setState(() => _config = config);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _twoColumnWidth;
        return DemoScaffold(
          title: const Text('Playground'),
          // Beside the code the bar spans both columns, its chevron on the
          // settings' text edge and Reset on the code's trailing edge.
          contentWidth: wide ? _wideContentWidth : DemoScaffold.maxContentWidth,
          alignBackGlyph: wide,
          trailing: CoilButton(
            variant: CoilButtonVariant.tertiary,
            size: CoilSize.compact,
            onPressed: _config == const SheetConfig()
                ? null
                : () => _update(const SheetConfig()),
            child: const Text('Reset'),
          ),
          body: wide ? _wide(context) : _narrow(context),
        );
      },
    );
  }

  /// Settings beside the code, both scrolling with the page.
  Widget _wide(BuildContext context) {
    final gutter = DemoScaffold.gutterOf(context);
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: _wideContentWidth + 2 * 24,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 24,
              children: [
                SizedBox(width: _settingsWidth, child: _settings(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: CoilButton(
                          onPressed: _open,
                          child: const Text('Open sheet'),
                        ),
                      ),
                      SizedBox(height: DemoScaffold.sectionGapOf(context)),
                      _code(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Settings, then the code, with the button pinned at the bottom.
  Widget _narrow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: DemoContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _settings(context),
                  SizedBox(height: DemoScaffold.sectionGapOf(context)),
                  _code(context),
                ],
              ),
            ),
          ),
        ),
        _openBar(context),
      ],
    );
  }

  /// The generated snippet under its label.
  Widget _code(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'The code for this sheet',
            style: text.muted.caption.copyWith(fontWeight: text.emphasis),
          ),
        ),
        const SizedBox(height: 4),
        CodeBlock(code: _config.toCode()),
      ],
    );
  }

  /// The pinned bar on phone widths: one full-width thumb target that
  /// clears the home indicator.
  Widget _openBar(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: 12,
          bottom: MediaQuery.paddingOf(context).bottom + 12,
        ),
        child: DemoContent(
          child: CoilAdaptiveScope(
            tier: CoilTier.touch,
            size: CoilSize.regular,
            child: SizedBox(
              width: double.infinity,
              child: CoilButton(
                onPressed: _open,
                child: const Text('Open sheet'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open() => _config.open(context);

  Widget _settings(BuildContext context) {
    final gap = DemoScaffold.sectionGapOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        CoilFieldSet(
          legend: const Text('Route'),
          children: [
            CoilField(
              label: const Text('Style'),
              child: CoilTabs<SheetRouteKind>(
                value: _config.route,
                onChanged: (route) => _update(_config.copyWith(route: route)),
                tabs: [
                  for (final route in SheetRouteKind.values)
                    CoilTab(value: route, label: Text(route.label)),
                ],
              ),
            ),
            CoilField(
              label: const Text('Motion'),
              description: Text(
                _config.disabledReason(SheetSetting.motion) ??
                    'The spring the sheet opens and closes on.',
              ),
              child: _dimmedUnless(
                _config.takes(SheetSetting.motion),
                CoilTabs<SheetMotionPreset>(
                  value: _config.motion,
                  onChanged: _config.takes(SheetSetting.motion)
                      ? (motion) => _update(_config.copyWith(motion: motion))
                      : null,
                  tabs: [
                    for (final motion in SheetMotionPreset.values)
                      CoilTab(value: motion, label: Text(motion.label)),
                  ],
                ),
              ),
            ),
          ],
        ),
        CoilFieldSet(
          legend: const Text('Snapping'),
          children: [
            CoilField(
              label: const Text('Stops'),
              description: const Text('The heights the sheet snaps to.'),
              // The group stretches to its field; it hugs its segments.
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: CoilToggleGroup<SheetStop>(
                  values: _config.stops,
                  onChanged: (stops) {
                    if (stops.isEmpty) return;
                    _update(_config.copyWith(stops: stops));
                  },
                  options: [
                    for (final stop in SheetStop.values)
                      CoilOption(value: stop, label: Text(stop.label)),
                  ],
                ),
              ),
            ),
            CoilField(
              label: const Text('Opens at'),
              child: CoilSelect<SheetStop>(
                value: _config.effectiveOpenAt,
                onChanged: (stop) => _update(_config.copyWith(openAt: stop)),
                options: [
                  for (final stop in _config.sortedStops)
                    CoilOption(
                      value: stop,
                      label: Text(stop.label),
                      searchText: stop.label,
                    ),
                ],
              ),
            ),
            CoilField(
              label: const Text('Snap physics'),
              description: const Text(
                'Friction carries a fling to where it would come to rest, '
                'past any stop in between.',
              ),
              child: CoilTabs<SnapPhysicsKind>(
                value: _config.physics,
                onChanged: (physics) =>
                    _update(_config.copyWith(physics: physics)),
                tabs: [
                  for (final physics in SnapPhysicsKind.values)
                    CoilTab(value: physics, label: Text(physics.label)),
                ],
              ),
            ),
            CoilField(
              label: const Text('Drag handoff'),
              description: const Text(
                'Continuous lets a scrolling list hand the drag over as soon '
                'as it reaches its top.',
              ),
              child: CoilTabs<SheetDragHandoff>(
                value: _config.handoff,
                onChanged: (handoff) =>
                    _update(_config.copyWith(handoff: handoff)),
                tabs: const [
                  CoilTab(
                    value: SheetDragHandoff.gestureStart,
                    label: Text('At gesture start'),
                  ),
                  CoilTab(
                    value: SheetDragHandoff.continuous,
                    label: Text('Continuous'),
                  ),
                ],
              ),
            ),
            CoilField(
              label: const Text('Dismissal'),
              description: const Text(
                'Shrink squeezes the sheet down instead of sliding it off '
                'the screen.',
              ),
              child: CoilTabs<DismissalMode>(
                value: _config.dismissal,
                onChanged: (dismissal) =>
                    _update(_config.copyWith(dismissal: dismissal)),
                tabs: const [
                  CoilTab(value: DismissalMode.slide, label: Text('Slide')),
                  CoilTab(value: DismissalMode.shrink, label: Text('Shrink')),
                ],
              ),
            ),
          ],
        ),
        CoilFieldSet(
          legend: const Text('Behavior'),
          children: [
            _switchField(
              label: 'Draggable',
              description: _config.disabledReason(SheetSetting.draggable),
              value: _config.effectiveDraggable,
              onChanged: _config.takes(SheetSetting.draggable)
                  ? (value) => _update(_config.copyWith(draggable: value))
                  : null,
            ),
            _switchField(
              label: 'Tap outside to close',
              description: _config.disabledReason(
                SheetSetting.barrierDismissible,
              ),
              value: _config.effectiveBarrierDismissible,
              onChanged: _config.takes(SheetSetting.barrierDismissible)
                  ? (value) =>
                        _update(_config.copyWith(barrierDismissible: value))
                  : null,
            ),
            _switchField(
              label: 'Confirm before closing',
              description: 'A dismissal springs back and asks first.',
              value: _config.confirmBeforeClosing,
              onChanged: (value) =>
                  _update(_config.copyWith(confirmBeforeClosing: value)),
            ),
            _switchField(
              label: 'Above the keyboard',
              description:
                  _config.disabledReason(SheetSetting.aboveKeyboard) ??
                  'The sheet rides on the keyboard instead of behind it.',
              value: _config.effectiveAboveKeyboard,
              onChanged: _config.takes(SheetSetting.aboveKeyboard)
                  ? (value) => _update(_config.copyWith(aboveKeyboard: value))
                  : null,
            ),
          ],
        ),
        CoilFieldSet(
          legend: const Text('Content'),
          children: [
            CoilField(
              label: const Text('In the sheet'),
              child: CoilSelect<SheetContentKind>(
                value: _config.content,
                onChanged: (content) =>
                    _update(_config.copyWith(content: content)),
                options: [
                  for (final content in SheetContentKind.values)
                    CoilOption(
                      value: content,
                      label: Text(content.label),
                      searchText: content.label,
                    ),
                ],
              ),
            ),
            CoilField(
              label: const Text('Background snapshot'),
              description: Text(
                _config.disabledReason(SheetSetting.snapshot) ??
                    'When the page behind is frozen to a texture, which '
                    'keeps a heavy page cheap.',
              ),
              child: CoilSelect<RouteSnapshotMode>(
                value: _config.effectiveSnapshot,
                onChanged: _config.takes(SheetSetting.snapshot)
                    ? (mode) => _update(_config.copyWith(snapshot: mode))
                    : null,
                options: const [
                  CoilOption(
                    value: RouteSnapshotMode.never,
                    label: Text('Never'),
                    searchText: 'Never',
                  ),
                  CoilOption(
                    value: RouteSnapshotMode.always,
                    label: Text('Always'),
                    searchText: 'Always',
                  ),
                  CoilOption(
                    value: RouteSnapshotMode.animating,
                    label: Text('Animating'),
                    searchText: 'Animating',
                  ),
                  CoilOption(
                    value: RouteSnapshotMode.settled,
                    label: Text('Settled'),
                    searchText: 'Settled',
                  ),
                  CoilOption(
                    value: RouteSnapshotMode.openAndForward,
                    label: Text('Open and forward'),
                    searchText: 'Open and forward',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// [child] at coil's disabled opacity unless [enabled]. Tabs and toggle
  /// groups have no disabled look of their own; switches and selects do.
  Widget _dimmedUnless(bool enabled, Widget child) {
    if (enabled) return child;
    return Opacity(
      opacity: CoilTheme.metricsOf(context).disabledOpacity,
      child: child,
    );
  }

  Widget _switchField({
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
    String? description,
  }) => CoilField(
    orientation: CoilFieldOrientation.horizontal,
    label: Text(label),
    description: description == null ? null : Text(description),
    child: CoilSwitch(value: value, onChanged: onChanged),
  );
}
