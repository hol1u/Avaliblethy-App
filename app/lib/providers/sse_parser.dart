import 'dart:async';
import 'dart:convert';

/// Parses a Server-Sent Events byte stream and emits the `data` payload of
/// each event. Comments and non-`data` fields are ignored.
Stream<String> parseSse(Stream<List<int>> bytes) async* {
  final data = <String>[];

  await for (final line
      in bytes
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        yield data.join('\n');
        data.clear();
      }
      continue;
    }
    if (line.startsWith(':')) continue;

    final colon = line.indexOf(':');
    final field = colon == -1 ? line : line.substring(0, colon);
    if (field != 'data') continue;

    var value = colon == -1 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    data.add(value);
  }

  // Be lenient with servers that close without a trailing blank line.
  if (data.isNotEmpty) yield data.join('\n');
}
