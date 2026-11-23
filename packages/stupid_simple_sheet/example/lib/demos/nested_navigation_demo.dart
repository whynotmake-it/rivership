import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet_example/shell/coil_sheets.dart';
import 'package:stupid_simple_sheet_example/shell/demo_scaffold.dart';
import 'package:stupid_simple_sheet_example/shell/rows.dart';

/// An issue tracker whose filters live in one sheet. Each filter opens its
/// own page inside the sheet, and the sheet still drags down to dismiss from
/// any of them.
class NestedNavigationDemo extends StatefulWidget {
  /// Creates the demo.
  const NestedNavigationDemo({super.key});

  @override
  State<NestedNavigationDemo> createState() => _NestedNavigationDemoState();
}

class _NestedNavigationDemoState extends State<NestedNavigationDemo> {
  _Filters _filters = const _Filters();

  Future<void> _openFilters() async {
    // Dismissing the sheet, by drag or scrim, returns null and leaves the
    // filters as they were.
    final applied = await Navigator.of(context).push<_Filters>(
      DemoSheetRoute<_Filters>(
        context: context,
        child: _FilterSheet(initial: _filters),
      ),
    );
    if (applied != null && mounted) setState(() => _filters = applied);
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final issues = [
      for (final issue in _issues)
        if (_filters.matches(issue)) issue,
    ];
    final active = _filters.activeCount;
    return DemoScaffold(
      title: const Text('Issues'),
      trailing: CoilButton(
        variant: CoilButtonVariant.secondary,
        size: CoilSize.compact,
        onPressed: _openFilters,
        child: Text(active > 0 ? 'Filter · $active' : 'Filter'),
      ),
      body: issues.isEmpty
          ? Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 12,
                  children: [
                    Text(
                      'No issues match these filters',
                      style: text.muted.body,
                      textAlign: TextAlign.center,
                    ),
                    CoilButton(
                      variant: CoilButtonVariant.secondary,
                      onPressed: () =>
                          setState(() => _filters = const _Filters()),
                      child: const Text('Clear filters'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.only(
                top: 8,
                bottom: MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                DemoContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final issue in issues)
                        DemoRow(
                          label: Text(issue.title),
                          description: Text(
                            '${issue.key} · ${issue.assignee}'
                            ' · ${issue.labels.join(', ')}',
                          ),
                          trailing: CoilBadge(
                            color: issue.status.color,
                            child: Text(issue.status.label),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// The sheet: a header, a nested navigator for the filter pages and the
/// action bar. It holds the draft the pages edit, so nothing reaches the
/// issue list until "Show" pops it.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final _Filters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  static const _root = 'Filters';

  final _navigator = GlobalKey<NavigatorState>();
  late final _draft = ValueNotifier(widget.initial);

  /// The title follows the visible page.
  final _title = ValueNotifier(_root);

  /// Holds focus above the pages, so Escape reaches the sheet before the
  /// first Tab and after a page that had focus has left.
  final _focus = FocusNode(skipTraversal: true);

  @override
  void dispose() {
    _draft.dispose();
    _title.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Takes focus back to the sheet's scope as a page comes or goes: the
  /// row that had focus is leaving the tree.
  void _refocus() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _focus.requestFocus();
  });

  Route<void> _route(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      'status' => _StatusPage(draft: _draft),
      'assignee' => _AssigneePage(draft: _draft),
      'labels' => _LabelsPage(draft: _draft),
      _ => _RootPage(draft: _draft, open: _open),
    };
    return _slideRoute(
      settings: settings,
      duration: CoilTheme.motionOf(context).standard.duration,
      child: page,
    );
  }

  void _open(String name) => _navigator.currentState?.pushNamed(name);

  @override
  Widget build(BuildContext context) {
    final height = math.min(264.0, MediaQuery.sizeOf(context).height * 0.4);
    return CoilSheetPanel(
      title: ValueListenableBuilder(
        valueListenable: _title,
        builder: (context, title, _) => Text(title),
      ),
      footer: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ValueListenableBuilder(
          valueListenable: _draft,
          builder: (context, draft, _) {
            final count = _issues.where(draft.matches).length;
            return CoilActionBar(
              actions: [
                CoilButton(
                  variant: CoilButtonVariant.secondary,
                  onPressed: draft.activeCount == 0
                      ? null
                      : () => _draft.value = const _Filters(),
                  child: const Text('Clear'),
                ),
                CoilButton(
                  onPressed: count == 0
                      ? null
                      : () => Navigator.of(context).pop(draft),
                  child: Text('Show $count ${count == 1 ? 'issue' : 'issues'}'),
                ),
              ],
            );
          },
        ),
      ),
      // Escape goes back a page before it closes the sheet. The sheet's own
      // route can't hold a back handler: a route that refuses to pop also
      // refuses the dismissing drag.
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): _BackIntent(),
        },
        child: Actions(
          actions: {_BackIntent: _BackAction(_navigator)},
          // Takes focus on open so Escape works before the first Tab, and
          // keeps it when a page leaves.
          child: Focus(
            focusNode: _focus,
            autofocus: true,
            child: SizedBox(
              height: height,
              child: Navigator(
                key: _navigator,
                observers: [_TitleObserver(_title, _refocus)],
                onGenerateRoute: _route,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackIntent extends Intent {
  const _BackIntent();
}

/// Pops the nested navigator for Escape while it has a page to pop, and
/// otherwise leaves Escape to the sheet.
class _BackAction extends Action<_BackIntent> {
  _BackAction(this.navigator);

  final GlobalKey<NavigatorState> navigator;

  @override
  bool isEnabled(_BackIntent intent) =>
      navigator.currentState?.canPop() ?? false;

  @override
  Object? invoke(_BackIntent intent) {
    navigator.currentState?.pop();
    return null;
  }
}

/// Keeps [title] on the name of the visible page.
class _TitleObserver extends NavigatorObserver {
  _TitleObserver(this.title, this.onChanged);

  final ValueNotifier<String> title;

  /// Called after a page came or went.
  final VoidCallback onChanged;

  static String _nameOf(Route<dynamic>? route) =>
      switch (route?.settings.name) {
        'status' => 'Status',
        'assignee' => 'Assignee',
        'labels' => 'Labels',
        _ => 'Filters',
      };

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    title.value = _nameOf(route);
    onChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    title.value = _nameOf(previousRoute);
    onChanged();
  }
}

/// A page that slides in from the end edge while the page under it shifts a
/// little and fades, on the duration of coil's `standard` motion.
Route<void> _slideRoute({
  required RouteSettings settings,
  required Duration? duration,
  required Widget child,
}) {
  final time = duration ?? const Duration(milliseconds: 180);
  return PageRouteBuilder<void>(
    settings: settings,
    transitionDuration: time,
    reverseTransitionDuration: time,
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final sign = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
      return AnimatedBuilder(
        animation: Listenable.merge([animation, secondaryAnimation]),
        child: child,
        builder: (context, child) {
          final entering = Curves.easeOutCubic.transform(animation.value);
          final leaving = Curves.easeOutCubic.transform(
            secondaryAnimation.value,
          );
          return Opacity(
            opacity: (1 - leaving) * entering,
            child: FractionalTranslation(
              translation: Offset(sign * ((1 - entering) - 0.25 * leaving), 0),
              child: child,
            ),
          );
        },
      );
    },
  );
}

class _RootPage extends StatelessWidget {
  const _RootPage({required this.draft, required this.open});

  final ValueNotifier<_Filters> draft;
  final ValueChanged<String> open;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: draft,
    builder: (context, filters, _) => ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        DemoRow(
          label: const Text('Status'),
          trailing: Text(filters.status.label),
          chevron: true,
          onPressed: () => open('status'),
        ),
        DemoRow(
          label: const Text('Assignee'),
          trailing: Text(filters.assignee ?? 'Anyone'),
          chevron: true,
          onPressed: () => open('assignee'),
        ),
        DemoRow(
          label: const Text('Labels'),
          trailing: Text(switch (filters.labels.length) {
            0 => 'None',
            1 => filters.labels.single,
            final count => '$count selected',
          }),
          chevron: true,
          onPressed: () => open('labels'),
        ),
      ],
    ),
  );
}

/// The frame of a pushed page: a pinned back row to the parent, then a
/// scrolling [child].
class _FilterPage extends StatelessWidget {
  const _FilterPage({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DemoRow(
        label: const Text('Filters'),
        leading: const CoilIcon(CoilIconRole.chevronStart),
        semanticLabel: 'Back to filters',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      Expanded(
        // The groups sit in a popup's inset, like the rows above them, so
        // their controls start 16 in, where the sheet's title starts.
        child: ListView(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          children: children,
        ),
      ),
    ],
  );
}

class _StatusPage extends StatelessWidget {
  const _StatusPage({required this.draft});

  final ValueNotifier<_Filters> draft;

  @override
  Widget build(BuildContext context) => _FilterPage(
    children: [
      ValueListenableBuilder(
        valueListenable: draft,
        builder: (context, filters, _) => CoilRadioGroup<_Status>(
          semanticLabel: 'Status',
          value: filters.status,
          onChanged: (status) => draft.value = filters.copyWith(status: status),
          options: [
            for (final status in _Status.values)
              CoilOption(value: status, label: Text(status.label)),
          ],
        ),
      ),
    ],
  );
}

class _AssigneePage extends StatelessWidget {
  const _AssigneePage({required this.draft});

  final ValueNotifier<_Filters> draft;

  @override
  Widget build(BuildContext context) => _FilterPage(
    children: [
      ValueListenableBuilder(
        valueListenable: draft,
        builder: (context, filters, _) => CoilRadioGroup<String>(
          semanticLabel: 'Assignee',
          value: filters.assignee ?? _anyone,
          onChanged: (name) => draft.value = filters.copyWith(
            assignee: name == _anyone ? null : name,
          ),
          options: [
            for (final name in [_anyone, ..._people])
              CoilOption(value: name, label: Text(name)),
          ],
        ),
      ),
    ],
  );
}

class _LabelsPage extends StatelessWidget {
  const _LabelsPage({required this.draft});

  final ValueNotifier<_Filters> draft;

  @override
  Widget build(BuildContext context) => _FilterPage(
    children: [
      ValueListenableBuilder(
        valueListenable: draft,
        builder: (context, filters, _) => CoilCheckboxGroup<String>(
          semanticLabel: 'Labels',
          values: filters.labels,
          onChanged: (labels) => draft.value = filters.copyWith(labels: labels),
          options: [
            for (final label in _labels)
              CoilOption(value: label, label: Text(label)),
          ],
        ),
      ),
    ],
  );
}

enum _Status {
  any('Any', CoilBadgeColor.gray),
  open('Open', CoilBadgeColor.gray),
  inProgress('In progress', CoilBadgeColor.amber),
  done('Done', CoilBadgeColor.green);

  const _Status(this.label, this.color);

  final String label;
  final CoilBadgeColor color;
}

const _anyone = 'Anyone';

@immutable
class _Filters {
  const _Filters({
    this.status = _Status.any,
    this.assignee,
    this.labels = const {},
  });

  final _Status status;

  /// The assignee's name; null for anyone.
  final String? assignee;

  /// Issues need at least one of these labels; empty means no restriction.
  final Set<String> labels;

  /// How many of the three filters narrow the list.
  int get activeCount =>
      (status == _Status.any ? 0 : 1) +
      (assignee == null ? 0 : 1) +
      (labels.isEmpty ? 0 : 1);

  bool matches(_Issue issue) =>
      (status == _Status.any || issue.status == status) &&
      (assignee == null || issue.assignee == assignee) &&
      (labels.isEmpty || issue.labels.any(labels.contains));

  _Filters copyWith({
    _Status? status,
    Object? assignee = _keep,
    Set<String>? labels,
  }) => _Filters(
    status: status ?? this.status,
    assignee: identical(assignee, _keep) ? this.assignee : assignee as String?,
    labels: labels ?? this.labels,
  );
}

const _keep = Object();

class _Issue {
  const _Issue(this.key, this.title, this.assignee, this.status, this.labels);

  final String key;
  final String title;
  final String assignee;
  final _Status status;
  final List<String> labels;
}

const _people = ['Priya', 'Marcus', 'Elena', 'Jonas', 'Aiko', 'Sam'];

const _labels = [
  'Bug',
  'Design',
  'Performance',
  'Accessibility',
  'iOS',
  'Android',
  'Web',
];

const _issues = [
  _Issue('APP-128', 'Crash on offline settings', 'Priya', _Status.open, [
    'Bug',
    'iOS',
  ]),
  _Issue(
    'APP-131',
    'Dark mode flashes on launch',
    'Marcus',
    _Status.inProgress,
    ['Bug', 'Design'],
  ),
  _Issue('APP-135', 'VoiceOver labels on tab bar', 'Elena', _Status.open, [
    'Accessibility',
    'iOS',
  ]),
  _Issue('APP-136', 'Slow cold start', 'Jonas', _Status.inProgress, [
    'Performance',
    'Android',
  ]),
  _Issue('APP-139', 'Photo upload fails over 5 MB', 'Aiko', _Status.open, [
    'Bug',
  ]),
  _Issue('APP-142', 'Empty state for saved items', 'Sam', _Status.inProgress, [
    'Design',
  ]),
  _Issue('APP-144', 'Back gesture exits checkout', 'Priya', _Status.done, [
    'Bug',
    'Android',
  ]),
  _Issue('APP-147', 'Dynamic Type in order summary', 'Elena', _Status.done, [
    'Accessibility',
    'iOS',
  ]),
  _Issue('APP-150', 'Image cache never shrinks', 'Jonas', _Status.open, [
    'Performance',
  ]),
  _Issue('APP-153', 'Keyboard hides promo field', 'Marcus', _Status.done, [
    'Bug',
    'Android',
  ]),
  _Issue('APP-155', 'Saved addresses at checkout', 'Aiko', _Status.open, [
    'Web',
  ]),
  _Issue('APP-158', 'Secondary button contrast', 'Sam', _Status.open, [
    'Design',
    'Accessibility',
  ]),
  _Issue('APP-160', 'Feed jank on older Pixels', 'Priya', _Status.inProgress, [
    'Performance',
    'Android',
  ]),
  _Issue('APP-166', 'Order history on small windows', 'Aiko', _Status.open, [
    'Bug',
    'Web',
  ]),
];
