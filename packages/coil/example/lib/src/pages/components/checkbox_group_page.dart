import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const checkboxGroupEntry = CatalogEntry(
  slug: 'checkbox-group',
  title: 'CheckboxGroup',
  group: CatalogGroup.groupedControls,
  summary: 'Checked rows merge into one block; it splits when you uncheck.',
  page: CheckboxGroupPage.new,
);

class CheckboxGroupPage extends StatefulWidget {
  const CheckboxGroupPage({super.key});

  @override
  State<CheckboxGroupPage> createState() => _CheckboxGroupPageState();
}

class _CheckboxGroupPageState extends State<CheckboxGroupPage> {
  var _toppings = {'basil', 'mozzarella'};
  var _days = {'mon', 'tue', 'thu'};
  var _compact = {'errors'};

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'CheckboxGroup',
    summary:
        'Check the row between two runs to watch them merge; uncheck the '
        'middle of a run to watch it split. Each row is a tab stop; Up and '
        'Down move with a keyboard.',
    children: [
      DemoSection(
        title: 'Toppings',
        child: CoilFieldSet(
          legend: const Text('Toppings'),
          description: const Text('Pick as many as you like.'),
          children: [
            CoilCheckboxGroup<String>(
              values: _toppings,
              onChanged: (values) => setState(() => _toppings = values),
              options: const [
                CoilOption(
                  value: 'basil',
                  label: Text('Basil'),
                ),
                CoilOption(
                  value: 'mozzarella',
                  label: Text('Mozzarella'),
                ),
                CoilOption(
                  value: 'olives',
                  label: Text('Olives'),
                ),
                CoilOption(
                  value: 'mushrooms',
                  label: Text('Mushrooms'),
                ),
                CoilOption(
                  value: 'anchovies',
                  label: Text('Anchovies (sold out)'),
                  enabled: false,
                ),
              ],
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'Long labels wrap',
        child: CoilCheckboxGroup<String>(
          values: _days,
          onChanged: (values) => setState(() => _days = values),
          options: const [
            CoilOption(
              value: 'mon',
              label: Text('Monday: standup and planning'),
            ),
            CoilOption(
              value: 'tue',
              label: Text(
                'Tuesday: design review with the whole product team, '
                'including the people joining remotely',
              ),
              searchText:
                  'Tuesday: design review with the whole product team, '
                  'including the people joining remotely',
            ),
            CoilOption(
              value: 'wed',
              label: Text('Wednesday: focus day'),
            ),
            CoilOption(
              value: 'thu',
              label: Text('Thursday: demos'),
            ),
          ],
        ),
      ),
      DemoSection(
        title: 'Compact',
        child: CoilCheckboxGroup<String>(
          size: CoilSize.compact,
          values: _compact,
          onChanged: (values) => setState(() => _compact = values),
          options: const [
            CoilOption(
              value: 'errors',
              label: Text('Errors'),
            ),
            CoilOption(
              value: 'warnings',
              label: Text('Warnings'),
            ),
            CoilOption(value: 'info', label: Text('Info')),
          ],
        ),
      ),
    ],
  );
}
