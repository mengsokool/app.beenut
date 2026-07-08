import 'dart:convert';
import 'dart:typed_data';

class Utf8LineFramer {
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  List<String> add(List<int> bytes) {
    if (bytes.isEmpty) return const [];
    _buffer.add(bytes);

    final pending = _buffer.takeBytes();
    final lines = <String>[];
    var lineStart = 0;
    for (var i = 0; i < pending.length; i += 1) {
      if (pending[i] != 0x0a) continue;
      var lineEnd = i;
      if (lineEnd > lineStart && pending[lineEnd - 1] == 0x0d) {
        lineEnd -= 1;
      }
      lines.add(utf8.decode(pending.sublist(lineStart, lineEnd)));
      lineStart = i + 1;
    }

    if (lineStart < pending.length) {
      _buffer.add(pending.sublist(lineStart));
    }
    return lines;
  }
}

String encodeProtocolLine(Map<String, Object?> payload) =>
    '${jsonEncode(payload)}\n';

Map<String, dynamic> decodeProtocolLine(String line) =>
    jsonDecode(line) as Map<String, dynamic>;
