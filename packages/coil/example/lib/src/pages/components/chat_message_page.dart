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

class ChatMessagePage extends StatefulWidget {
  const ChatMessagePage({super.key});

  @override
  State<ChatMessagePage> createState() => _ChatMessagePageState();
}

class _ChatMessagePageState extends State<ChatMessagePage> {
  static const _reply =
      'Three changes: tighter exits, one row height, and sheets for forms '
      'on phones.';

  /// The Copy action's result, shared with InputCopy's behavior: the icon
  /// cross-fades to a check once, and copying again only extends it.
  final _copy = CoilCopyController();

  @override
  void dispose() {
    _copy.dispose();
    super.dispose();
  }

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
                  label: const Text('Copy'),
                  // The icon names the button, as in an IconButton.
                  icon: Semantics(
                    label: 'Copy',
                    child: CoilCopyGlyph.listening(controller: _copy),
                  ),
                  onPressed: () => _copy.copy(_reply, context: context),
                ),
              ],
              child: const Text(_reply),
            ),
          ],
        ),
      ),
    ],
  );
}
