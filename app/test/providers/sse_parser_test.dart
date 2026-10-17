import 'dart:convert';

import 'package:avaliblethy_app/providers/sse_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<List<int>> bytes(List<String> parts) =>
    Stream.fromIterable(parts.map(utf8.encode));

void main() {
  test('parses events separated by blank lines', () async {
    final out = await parseSse(bytes(['data: one\n\ndata: two\n\n'])).toList();
    expect(out, ['one', 'two']);
  });

  test('handles CRLF and data split across chunks', () async {
    final out = await parseSse(
      bytes(['data: hel', 'lo\r\n\r\nda', 'ta: [DONE]\r\n\r\n']),
    ).toList();
    expect(out, ['hello', '[DONE]']);
  });

  test('joins multi-line data, ignores comments and other fields', () async {
    final out = await parseSse(
      bytes([': keep-alive\nevent: x\nid: 1\ndata: a\ndata: b\n\n']),
    ).toList();
    expect(out, ['a\nb']);
  });

  test('handles multibyte characters split across chunks', () async {
    final encoded = utf8.encode('data: héllo\n\n');
    final out = await parseSse(
      Stream.fromIterable([encoded.sublist(0, 8), encoded.sublist(8)]),
    ).toList();
    expect(out, ['héllo']);
  });

  test('flushes a trailing event without blank line', () async {
    final out = await parseSse(bytes(['data: tail'])).toList();
    expect(out, ['tail']);
  });

  test('data without space after colon', () async {
    final out = await parseSse(bytes(['data:x\n\n'])).toList();
    expect(out, ['x']);
  });
}
