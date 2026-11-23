import 'dart:async';
import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';
import 'package:stupid_simple_sheet_example/shell/coil_sheets.dart';
import 'package:stupid_simple_sheet_example/shell/demo_scaffold.dart';
import 'package:stupid_simple_sheet_example/shell/rows.dart';

/// A settings screen whose time zone picker is a long list in a sheet that
/// hands its drag over once the list is at its top, or from anywhere in it.
class ScrollHandoffDemo extends StatefulWidget {
  /// Creates the demo.
  const ScrollHandoffDemo({super.key});

  @override
  State<ScrollHandoffDemo> createState() => _ScrollHandoffDemoState();
}

class _ScrollHandoffDemoState extends State<ScrollHandoffDemo> {
  late final Timer _clock;
  _Zone _zone = _zones.firstWhere((zone) => zone.city == 'Berlin');
  bool _use24Hour = true;
  bool _handOffMidScroll = false;

  @override
  void initState() {
    super.initState();
    // Re-reads the time every few seconds so the minute turns on its own.
    _clock = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  Future<void> _pickZone() async {
    final picked = await Navigator.of(context).push<_Zone>(
      DemoSheetRoute<_Zone>(
        context: context,
        dragHandoff: _handOffMidScroll
            ? SheetDragHandoff.continuous
            : SheetDragHandoff.gestureStart,
        child: _ZonePicker(selected: _zone),
      ),
    );
    if (picked != null && mounted) setState(() => _zone = picked);
  }

  /// The time in [_zone] at its standard offset, which ignores daylight
  /// saving.
  String get _time {
    final now = DateTime.now().toUtc().add(_zone.offset);
    final minute = now.minute.toString().padLeft(2, '0');
    if (_use24Hour) return '${now.hour.toString().padLeft(2, '0')}:$minute';
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    return '$hour:$minute ${now.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return DemoScaffold(
      title: const Text('Date & time'),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: 8,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        child: DemoContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DemoRow(
                label: const Text('Time zone'),
                trailing: Text(_zone.city),
                chevron: true,
                onPressed: _pickZone,
              ),
              DemoRow(
                label: const Text('Current time'),
                description: Text('Standard time in ${_zone.city}'),
                trailing: Text(
                  _time,
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              _SwitchRow(
                label: '24-hour time',
                value: _use24Hour,
                onChanged: (value) => setState(() => _use24Hour = value),
              ),
              SizedBox(height: DemoScaffold.sectionGapOf(context)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Semantics(
                  header: true,
                  child: Text(
                    'Time zone picker',
                    style: text.muted.caption.copyWith(
                      fontWeight: text.emphasis,
                    ),
                  ),
                ),
              ),
              _SwitchRow(
                label: 'Hand off mid-scroll',
                description:
                    'Drag down from anywhere in the list, not only from its '
                    'top.',
                value: _handOffMidScroll,
                onChanged: (value) => setState(() => _handOffMidScroll = value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A settings row ending in a switch, laid out like a [DemoRow] but with a
/// description that wraps instead of ending in an ellipsis. A tap anywhere
/// on the row toggles the switch.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => CoilAdaptiveScope(
    tier: CoilTier.touch,
    size: CoilSize.regular,
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final metrics = CoilTheme.metricsOf(context);
    final radii = CoilTheme.radiiOf(context);
    final text = CoilTheme.textOf(context);
    final minHeight = description == null
        ? metrics.controlHeight
        : metrics.controlHeight + 16;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.popupInset),
      child: Semantics(
        container: true,
        excludeSemantics: true,
        toggled: value,
        label: description == null ? label : '$label. $description',
        onTap: () => onChanged(!value),
        child: CoilInteraction(
          onPressed: () => onChanged(!value),
          minHitTarget: math.min(metrics.minHitTarget, minHeight),
          builder: (context, states, _) => DecoratedBox(
            decoration: ShapeDecoration(
              color: states.contains(WidgetState.pressed)
                  ? colors.active
                  : states.contains(WidgetState.hovered)
                  ? colors.hover
                  : const Color(0x00000000),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(radii.item),
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.itemPaddingX,
                  vertical: 8,
                ),
                child: Row(
                  spacing: metrics.gap,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: text.body),
                          if (description != null)
                            Text(description!, style: text.muted.caption),
                        ],
                      ),
                    ),
                    CoilSwitch(value: value, onChanged: onChanged),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZonePicker extends StatefulWidget {
  const _ZonePicker({required this.selected});

  final _Zone selected;

  @override
  State<_ZonePicker> createState() => _ZonePickerState();
}

class _ZonePickerState extends State<_ZonePicker> {
  final _search = TextEditingController();
  late _Zone _selected = widget.selected;
  bool _picked = false;

  /// Opens on the selected zone, two rows from the top, so the list starts
  /// mid-scroll.
  late final _scroll = ScrollController(
    initialScrollOffset: math.max(
      0,
      (_zones.indexOf(widget.selected) - 2) * _rowHeight,
    ),
  );

  /// A two-line row's height: the touch control height plus 16.
  static const _rowHeight = 60.0;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Checks [zone], then closes once the check has landed.
  void _pick(_Zone zone) {
    if (_picked) return;
    _picked = true;
    setState(() => _selected = zone);
    Timer(CoilTheme.motionOf(context).acknowledgeDuration, () {
      if (mounted) Navigator.of(context).pop(zone);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return CoilSheetPanel(
      title: const Text('Time zone'),
      child: ListenableBuilder(
        listenable: _search,
        builder: (context, _) {
          final query = _search.text.trim().toLowerCase();
          final zones = [
            for (final zone in _zones)
              if (zone.matches(query)) zone,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: CoilInput(
                  controller: _search,
                  placeholder: const Text('Search'),
                  semanticLabel: 'Search time zones',
                ),
              ),
              Expanded(
                child: zones.isEmpty
                    ? Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 12,
                            children: [
                              Text(
                                'No results for “${_search.text.trim()}”',
                                style: text.muted.body,
                                textAlign: TextAlign.center,
                              ),
                              CoilButton(
                                variant: CoilButtonVariant.tertiary,
                                onPressed: _search.clear,
                                child: const Text('Clear search'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        controller: _scroll,
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.paddingOf(context).bottom + 8,
                        ),
                        children: [
                          for (final zone in zones)
                            DemoRow(
                              label: Text(zone.city),
                              description: Text(zone.region),
                              trailing: Text(zone.offsetLabel),
                              checked: zone == _selected,
                              onPressed: () => _pick(zone),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Zone {
  const _Zone(this.city, this.region, this.minutes);

  final String city;
  final String region;

  /// The standard offset from UTC in minutes.
  final int minutes;

  Duration get offset => Duration(minutes: minutes);

  /// The offset as people write it: "UTC+1", "UTC−3:30", with a true minus.
  String get offsetLabel {
    if (minutes == 0) return 'UTC';
    final sign = minutes < 0 ? '−' : '+';
    final hours = minutes.abs() ~/ 60;
    final rest = minutes.abs() % 60;
    final fraction = rest == 0 ? '' : ':${rest.toString().padLeft(2, '0')}';
    return 'UTC$sign$hours$fraction';
  }

  bool matches(String query) =>
      query.isEmpty ||
      city.toLowerCase().contains(query) ||
      region.toLowerCase().contains(query);
}

const _zones = [
  _Zone('Honolulu', 'Pacific', -600),
  _Zone('Anchorage', 'America', -540),
  _Zone('Los Angeles', 'America', -480),
  _Zone('Denver', 'America', -420),
  _Zone('Chicago', 'America', -360),
  _Zone('Mexico City', 'America', -360),
  _Zone('Bogotá', 'America', -300),
  _Zone('New York', 'America', -300),
  _Zone('Toronto', 'America', -300),
  _Zone('Halifax', 'America', -240),
  _Zone('Santiago', 'America', -240),
  _Zone('St. John’s', 'America', -210),
  _Zone('Buenos Aires', 'America', -180),
  _Zone('São Paulo', 'America', -180),
  _Zone('Reykjavik', 'Atlantic', 0),
  _Zone('Lisbon', 'Europe', 0),
  _Zone('London', 'Europe', 0),
  _Zone('Amsterdam', 'Europe', 60),
  _Zone('Berlin', 'Europe', 60),
  _Zone('Lagos', 'Africa', 60),
  _Zone('Madrid', 'Europe', 60),
  _Zone('Paris', 'Europe', 60),
  _Zone('Rome', 'Europe', 60),
  _Zone('Stockholm', 'Europe', 60),
  _Zone('Athens', 'Europe', 120),
  _Zone('Cairo', 'Africa', 120),
  _Zone('Helsinki', 'Europe', 120),
  _Zone('Johannesburg', 'Africa', 120),
  _Zone('Istanbul', 'Europe', 180),
  _Zone('Nairobi', 'Africa', 180),
  _Zone('Tehran', 'Asia', 210),
  _Zone('Dubai', 'Asia', 240),
  _Zone('Karachi', 'Asia', 300),
  _Zone('Kolkata', 'Asia', 330),
  _Zone('Kathmandu', 'Asia', 345),
  _Zone('Dhaka', 'Asia', 360),
  _Zone('Bangkok', 'Asia', 420),
  _Zone('Jakarta', 'Asia', 420),
  _Zone('Hong Kong', 'Asia', 480),
  _Zone('Perth', 'Australia', 480),
  _Zone('Shanghai', 'Asia', 480),
  _Zone('Singapore', 'Asia', 480),
  _Zone('Seoul', 'Asia', 540),
  _Zone('Tokyo', 'Asia', 540),
  _Zone('Adelaide', 'Australia', 570),
  _Zone('Sydney', 'Australia', 600),
  _Zone('Auckland', 'Pacific', 720),
];
