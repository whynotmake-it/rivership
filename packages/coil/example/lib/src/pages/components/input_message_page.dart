import 'package:coil/coil.dart';
import 'package:coil_example/src/registry.dart';
import 'package:coil_example/src/widgets/catalog_page.dart';
import 'package:flutter/widgets.dart';

const inputMessageEntry = CatalogEntry(
  slug: 'input-message',
  title: 'InputMessage',
  group: CatalogGroup.shellAndComposites,
  summary: 'A chat composer: Enter sends; on touch, Return is a new line.',
  page: InputMessagePage.new,
);

class InputMessagePage extends StatefulWidget {
  const InputMessagePage({super.key});

  @override
  State<InputMessagePage> createState() => _InputMessagePageState();
}

class _InputMessagePageState extends State<InputMessagePage> {
  final _sent = <String>[];
  var _streaming = false;
  var _files = ['brief.pdf', 'notes.md'];

  @override
  Widget build(BuildContext context) => CatalogPage(
    title: 'InputMessage',
    summary: 'Sending starts a fake reply; the button stops it.',
    children: [
      DemoSection(
        title: 'Composer',
        child: DemoColumn(
          children: [
            for (final message in _sent) Text(message),
            CoilInputMessage(
              status: _streaming
                  ? CoilMessageStatus.streaming
                  : CoilMessageStatus.idle,
              onStop: () => setState(() => _streaming = false),
              onSend: (text) => setState(() {
                _sent.add(text);
                _streaming = true;
              }),
              attachments: _files.isEmpty
                  ? null
                  : Wrap(
                      spacing: 8,
                      children: [
                        for (final file in _files)
                          CoilFileThumbnail(
                            name: file,
                            size: 48,
                            onRemove: () => setState(
                              () => _files = [..._files]..remove(file),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ],
  );
}
