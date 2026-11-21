import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:motor_example/widgets/icons.dart';

/// Whether the motor devtools overlay is shown. It starts off, and only the
/// gallery's DevTools switch turns it on. The tools keep tracking while
/// hidden, so nothing is lost.
final devtoolsVisible = ValueNotifier(false);

/// The sidebar footer's row that shows or hides the motor devtools: an
/// icon and a label lined up with the sidebar's rows, and a switch at the
/// end. A tap anywhere on the row flips it.
class DevToolsSwitch extends StatelessWidget {
  const DevToolsSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context);
    final colors = CoilTheme.of(context).colors;
    return ValueListenableBuilder(
      valueListenable: devtoolsVisible,
      builder: (context, visible, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => devtoolsVisible.value = !visible,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: metrics.controlHeight),
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: metrics.itemPaddingX,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: IconTheme.merge(
                    data: IconThemeData(
                      size: metrics.iconSize,
                      color: colors.mutedForeground,
                    ),
                    child: const GlyphIcon(Glyph.activity),
                  ),
                ),
                SizedBox(width: metrics.gap),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      'DevTools',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CoilTheme.textOf(context).muted.body,
                    ),
                  ),
                ),
                CoilSwitch(
                  value: visible,
                  semanticLabel: 'DevTools',
                  onChanged: (value) => devtoolsVisible.value = value,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
