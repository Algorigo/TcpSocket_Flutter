
import 'dart:async';

import 'package:flutter/services.dart';

import 'package:rxdart/rxdart.dart';

import 'socket.dart';

part 'socket_connection.dart';

class TcpsocketPlugin {
  static const MethodChannel channel =
      const MethodChannel('tcpsocket_plugin');

  static Future<String> get platformVersion async {
    final String version = await channel.invokeMethod('getPlatformVersion');
    return version;
  }
}

class SocketClient {
  SocketClient(this.server, this.port);

  final String server;
  final int port;

  Stream<SocketConnection> connect({Duration? duration}) {
    SocketConnection connection = SocketConnection(server, port);
    StreamController<SocketConnection>? controller;
    controller = new StreamController<SocketConnection>(onListen: () async {
      try {
        await connection._initialize(duration ?? Duration(seconds: 5));
        controller?.add(connection);
      } catch (e) {
        print("initialized error:$e");
        controller?.addError(e);
      }
    }, onCancel: () async {
      print("SocketClient onCancel");
      await connection._close();
    });
    return controller.stream.doOnCancel(() {
      controller?.close();
    });
  }
}
