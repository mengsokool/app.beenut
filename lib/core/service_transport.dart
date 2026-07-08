import 'dart:async';
import 'dart:io';

sealed class ServiceEndpoint {
  const ServiceEndpoint();

  factory ServiceEndpoint.parse(String value) {
    if (value.startsWith('tcp://')) {
      final uri = Uri.parse(value);
      if (uri.host.isEmpty || !uri.hasPort) {
        throw FormatException('TCP endpoint must include host and port', value);
      }
      return TcpServiceEndpoint(uri.host, uri.port);
    }
    if (value.startsWith('tcp:')) {
      final raw = value.substring('tcp:'.length);
      final parts = raw.split(':');
      if (parts.length != 2) {
        throw FormatException('TCP endpoint must be tcp:host:port', value);
      }
      final port = int.tryParse(parts[1]);
      if (parts[0].isEmpty || port == null) {
        throw FormatException(
          'TCP endpoint must include host and numeric port',
          value,
        );
      }
      return TcpServiceEndpoint(parts[0], port);
    }
    if (value.startsWith('unix:')) {
      return UnixServiceEndpoint(value.substring('unix:'.length));
    }
    return UnixServiceEndpoint(value);
  }
}

class UnixServiceEndpoint extends ServiceEndpoint {
  const UnixServiceEndpoint(this.path);

  final String path;
}

class TcpServiceEndpoint extends ServiceEndpoint {
  const TcpServiceEndpoint(this.host, this.port);

  final String host;
  final int port;
}

abstract interface class ServiceTransport {
  Stream<List<int>> get bytes;

  Future<void> connect();
  void send(String line);
  Future<void> close();
}

ServiceTransport createServiceTransport(String endpoint) {
  final parsed = ServiceEndpoint.parse(endpoint);
  return switch (parsed) {
    UnixServiceEndpoint(:final path) =>
      Platform.isWindows
          ? TcpServiceTransport('127.0.0.1', 8080)
          : UnixSocketServiceTransport(path),
    TcpServiceEndpoint(:final host, :final port) => TcpServiceTransport(
      host,
      port,
    ),
  };
}


class UnixSocketServiceTransport implements ServiceTransport {
  UnixSocketServiceTransport(this.socketPath);

  final String socketPath;
  final _controller = StreamController<List<int>>.broadcast();
  Socket? _socket;
  StreamSubscription<List<int>>? _subscription;

  @override
  Stream<List<int>> get bytes => _controller.stream;

  @override
  Future<void> connect() async {
    await close();
    final socket = await Socket.connect(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    _socket = socket;
    _subscription = socket.listen(
      _controller.add,
      onError: _controller.addError,
      onDone: () => _controller.addError(const SocketException('closed')),
      cancelOnError: true,
    );
  }

  @override
  void send(String line) {
    _socket?.write(line);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    _socket?.destroy();
    _socket = null;
  }
}

class TcpServiceTransport implements ServiceTransport {
  TcpServiceTransport(this.host, this.port);

  final String host;
  final int port;
  final _controller = StreamController<List<int>>.broadcast();
  Socket? _socket;
  StreamSubscription<List<int>>? _subscription;

  @override
  Stream<List<int>> get bytes => _controller.stream;

  @override
  Future<void> connect() async {
    await close();
    final socket = await Socket.connect(host, port);
    _socket = socket;
    _subscription = socket.listen(
      _controller.add,
      onError: _controller.addError,
      onDone: () => _controller.addError(const SocketException('closed')),
      cancelOnError: true,
    );
  }

  @override
  void send(String line) {
    _socket?.write(line);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    _socket?.destroy();
    _socket = null;
  }
}

class UnsupportedServiceTransport implements ServiceTransport {
  UnsupportedServiceTransport(this.message);

  final String message;
  final _controller = StreamController<List<int>>.broadcast();

  @override
  Stream<List<int>> get bytes => _controller.stream;

  @override
  Future<void> connect() => Future<void>.error(UnsupportedError(message));

  @override
  void send(String line) {}

  @override
  Future<void> close() async {}
}
