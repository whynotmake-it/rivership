import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet_example/shell/coil_sheets.dart';
import 'package:stupid_simple_sheet_example/shell/demo_scaffold.dart';

/// A task list whose quick-add sheet rides on the keyboard, grows with its
/// notes and asks before it throws a draft away.
class KeyboardDemo extends StatefulWidget {
  /// Creates the demo.
  const KeyboardDemo({super.key});

  @override
  State<KeyboardDemo> createState() => _KeyboardDemoState();
}

class _KeyboardDemoState extends State<KeyboardDemo> {
  var _tasks = _seedTasks;

  Future<void> _addTask() async {
    final task = await Navigator.of(
      context,
    ).push(DemoSheetRoute<_Task>(context: context, child: const _NewTask()));
    if (task != null && mounted) {
      setState(() => _tasks = [task, ..._tasks]);
    }
  }

  void _toggle(int index, bool done) => setState(() {
    _tasks = [
      for (final (i, task) in _tasks.indexed)
        if (i == index) task.copyWith(done: done) else task,
    ];
  });

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return DemoScaffold(
      title: const Text('Today'),
      trailing: CoilButton(
        variant: CoilButtonVariant.secondary,
        size: CoilSize.compact,
        onPressed: _addTask,
        child: const Text('New task'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: 8,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        child: DemoContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_tasks.where((task) => !task.done).length} left to do',
                style: text.muted.body,
              ),
              const SizedBox(height: 8),
              for (final (index, task) in _tasks.indexed)
                _TaskRow(task: task, onChanged: (done) => _toggle(index, done)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.onChanged});

  final _Task task;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final metrics = CoilTheme.metricsOf(context);
    final title = task.done ? text.muted.body : text.body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!task.done),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: metrics.controlHeight + 16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            spacing: 12,
            children: [
              // The box is as wide as the checkbox draws, so it sits on the
              // gutter; its hit area reaches past it.
              SizedBox(
                width: metrics.checkboxSize,
                height: math.max(metrics.minHitTarget, metrics.checkboxSize),
                child: OverflowBox(
                  maxWidth: metrics.minHitTarget + metrics.checkboxSize,
                  child: CoilCheckbox(
                    value: task.done,
                    onChanged: (value) => onChanged(value ?? false),
                    semanticLabel: task.title,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: task.done
                          ? title.copyWith(
                              decoration: TextDecoration.lineThrough,
                            )
                          : title,
                    ),
                    if (task.due != null)
                      Text(task.due!.caption, style: text.muted.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The quick-add sheet. A draft in it is never dropped silently: a dismissal
/// bounces back and asks first.
class _NewTask extends StatefulWidget {
  const _NewTask();

  @override
  State<_NewTask> createState() => _NewTaskState();
}

class _NewTaskState extends State<_NewTask> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  var _due = _Due.today;

  late final _draft = Listenable.merge([_title, _notes]);

  bool get _hasDraft =>
      _title.text.trim().isNotEmpty || _notes.text.trim().isNotEmpty;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(_Task(title: title, due: _due));
  }

  /// Runs when a dismissal was stopped by [PopScope]: the sheet has already
  /// rubber-banded back, so ask what to do with the draft.
  Future<void> _confirmDiscard() async {
    final discard = await showCoilDialog<bool>(
      context: context,
      builder: (context) => CoilDialog(
        title: const Text('Discard this task?'),
        description: const Text('Your title and notes will be lost.'),
        actions: [
          CoilButton(
            variant: CoilButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          CoilButton(
            variant: CoilButtonVariant.destructive,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard task'),
          ),
        ],
      ),
    );
    // `pop` skips PopScope, which only guards `maybePop` and the drag.
    if ((discard ?? false) && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) => PopScope(
        canPop: !_hasDraft,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmDiscard();
        },
        child: CoilSheetPanel(
          title: const Text('New task'),
          // Named, because the default button hides itself while a PopScope
          // refuses the pop, which is when a draft needs the way out most.
          close: CoilSheetCloseButton(
            onPressed: Navigator.of(context).maybePop,
          ),
          footer: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CoilActionBar(
              actions: [
                CoilButton(
                  onPressed: _title.text.trim().isEmpty ? null : _submit,
                  child: const Text('Add task'),
                ),
              ],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                CoilField(
                  label: const Text('Title'),
                  child: CoilInput(
                    controller: _title,
                    autofocus: true,
                    placeholder: const Text('Call the plumber'),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                CoilField(
                  label: const Text('Notes'),
                  child: CoilInput.multiline(
                    controller: _notes,
                    minLines: 2,
                    maxLines: 8,
                    placeholder: const Text('Add details'),
                  ),
                ),
                CoilField(
                  label: const Text('Due'),
                  child: CoilTabs<_Due>(
                    value: _due,
                    onChanged: (due) => setState(() => _due = due),
                    tabs: [
                      for (final due in _Due.values)
                        CoilTab(value: due, label: Text(due.label)),
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
}

enum _Due {
  today('Today', 'Due today'),
  tomorrow('Tomorrow', 'Due tomorrow'),
  nextWeek('Next week', 'Due next week');

  const _Due(this.label, this.caption);

  final String label;
  final String caption;
}

class _Task {
  const _Task({required this.title, this.due, this.done = false});

  final String title;
  final _Due? due;
  final bool done;

  _Task copyWith({bool? done}) =>
      _Task(title: title, due: due, done: done ?? this.done);
}

const _seedTasks = [
  _Task(title: 'Reply to Dana about the venue', due: _Due.today),
  _Task(title: 'Book dentist appointment', due: _Due.tomorrow),
  _Task(title: 'Pick up the dry cleaning', done: true),
  _Task(title: 'Send the invoice to Northwind', due: _Due.today),
  _Task(title: 'Water the plants', done: true),
  _Task(title: 'Plan next week’s meals', due: _Due.nextWeek),
];
