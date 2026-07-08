import 'package:beenut/core/service_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses unix service endpoints', () {
    final plain = ServiceEndpoint.parse('/tmp/beenutd.sock');
    final explicit = ServiceEndpoint.parse('unix:/tmp/beenutd.sock');

    expect(plain, isA<UnixServiceEndpoint>());
    expect((plain as UnixServiceEndpoint).path, '/tmp/beenutd.sock');
    expect((explicit as UnixServiceEndpoint).path, '/tmp/beenutd.sock');
  });

  test('parses tcp service endpoints for future platform bridges', () {
    final compact = ServiceEndpoint.parse('tcp:127.0.0.1:49100');
    final uri = ServiceEndpoint.parse('tcp://localhost:49101');

    expect(compact, isA<TcpServiceEndpoint>());
    expect((compact as TcpServiceEndpoint).host, '127.0.0.1');
    expect(compact.port, 49100);
    expect((uri as TcpServiceEndpoint).host, 'localhost');
    expect(uri.port, 49101);
  });

  test('rejects malformed tcp endpoints', () {
    expect(
      () => ServiceEndpoint.parse('tcp:127.0.0.1'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ServiceEndpoint.parse('tcp://localhost'),
      throwsA(isA<FormatException>()),
    );
  });

  test('creates tcp transport from endpoint', () {
    final transport = createServiceTransport('tcp:127.0.0.1:49100');
    expect(transport, isA<TcpServiceTransport>());
  });
}
