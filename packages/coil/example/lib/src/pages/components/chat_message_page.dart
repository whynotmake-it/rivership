import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const chatMessageEntry = CatalogEntry(
  slug: 'chat-message',
  title: 'ChatMessage',
  group: CatalogGroup.layoutAndDisplay,
  summary: 'User bubbles and assistant replies, with actions.',
  page: ChatMessagePage.new,
);

class ChatMessagePage extends StatelessWidget {
  const ChatMessagePage({super.key});

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'ChatMessage',
    summary: 'Actions show on hover, or with a long press on touch.',
    children: [
      DemoSection(
        title: 'Conversation',
        child: DemoColumn(
          children: [
            const CoilChatMessage(
              sender: CoilChatSender.user,
              child: Text('Can you summarize the design review?'),
            ),
            CoilChatMessage(
              sender: CoilChatSender.assistant,
              actions: [
                CoilChatMessageAction(
                  label: 'Copy',
                  icon: const CoilDrawnGlyph(CoilGlyph.check),
                  onPressed: () {},
                ),
              ],
              child: const Text(
                'Three changes: tighter exits, one row height, and sheets '
                'for forms on phones.',
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
