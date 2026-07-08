import 'dart:convert';

import 'package:beenut/core/service_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('frames UTF-8 protocol lines across chunks', () {
    final framer = Utf8LineFramer();
    final payload = utf8.encode(
      encodeProtocolLine({
        'type': 'diagnosticEvent',
        'message': 'กล้องพร้อมใช้งาน',
      }),
    );
    final split = payload.indexWhere((byte) => byte > 0x7f) + 1;

    expect(framer.add(payload.sublist(0, split)), isEmpty);
    expect(framer.add(payload.sublist(split)), hasLength(1));
  });

  test('encodes and decodes json line payloads', () {
    final line = encodeProtocolLine({'type': 'status', 'count': 3});

    expect(line.endsWith('\n'), isTrue);
    expect(decodeProtocolLine(line)['type'], 'status');
    expect(decodeProtocolLine(line)['count'], 3);
  });
}
