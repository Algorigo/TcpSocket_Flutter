
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'package:rxdart/rxdart.dart';

import 'tcpsocket_plugin.dart';

abstract class SocketWrapper {
  static SocketWrapper init() {
    if (Platform.isAndroid) {
      return SocketAndroid();
    } else {
      return SocketDart();
    }
  }

  Future<Stream<Uint8List>> connect(String host, int port, {String sourceAddress, Duration? timeout});

  Future<void> addStream(Stream<List<int>> stream);

  Future<void> close();
}

class SocketDart extends SocketWrapper {

  Socket? socket;

  @override
  Future<Stream<Uint8List>> connect(String host, int port,
      {String? sourceAddress, Duration? timeout}) async {
    socket = await Socket.connect(host, port, sourceAddress: sourceAddress, timeout: timeout);
    return socket!;
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await socket?.addStream(stream);
  }

  @override
  Future<void> close() async {
    await socket?.close();
  }
}

class SocketAndroid extends SocketWrapper {

  late int _socketIdentity;

  @override
  Future<Stream<Uint8List>> connect(String host, int port,
      {String? sourceAddress, Duration? timeout}) async {

    _socketIdentity = await TcpsocketPlugin.channel.invokeMethod('connect', {'address': host, 'port': port, 'timeout': timeout?.inMilliseconds});
    return _Observable<Uint8List>(_socketIdentity);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.doOnData((event) async {
      print("!!! doOnData:$event");
      await TcpsocketPlugin.channel.invokeMethod('sendData', {'id': _socketIdentity, 'data': event});
    }).last;
  }

  @override
  Future<void> close() async {
    await TcpsocketPlugin.channel.invokeMethod('close');
  }
}

class _Observable<T> extends Stream<T> {
  static const EventChannel _eventChannel =
      const EventChannel('tcpsocket_plugin_connect');

  _Observable(this._id);

  int _id;

  @override
  StreamSubscription<T> listen(void onData(T event)?,
      {Function? onError, void onDone()?, bool? cancelOnError}) {
    return _eventChannel
        .receiveBroadcastStream(_id)
        .map((event) => event as T)
        .listen((event) => onData?.call(event),
        onError: (error) => onError?.call(error),
        onDone: () => onDone?.call(),
        cancelOnError: true);
  }
}
