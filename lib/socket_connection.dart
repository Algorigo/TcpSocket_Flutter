import 'dart:async';
import 'dart:io';

import 'package:rxdart/rxdart.dart';

class SocketClient {
  SocketClient(this.server, this.port);

  final String server;
  final int port;

  Stream<SocketConnection> connect() {
    SocketConnection connection = SocketConnection(server, port);
    StreamController<SocketConnection> controller;
    controller = new StreamController<SocketConnection>(onListen: () async {
      await connection.initialize();
      controller.add(connection);
    }, onCancel: () async {
      await connection.close();
    });
    return controller.stream;
  }
}

class SocketConnection {
  SocketConnection(this.server, this.port) {}

  final String server;
  final int port;
  Socket socket;
  List<int> buffer = [];
  var subject = BehaviorSubject<List<int>>();

  Future<void> initialize() async {
    socket = await Socket.connect(server, port);

    var completer = Completer<void>();
    // listen to the received data event stream
    socket.doOnListen(() {
      completer.complete();
    }).listen((List<int> event) {
      buffer.addAll(event);
      subject.add(List.from(buffer));
    }, onError: (error) {
      completer.completeError(error);
    }, cancelOnError: true);

    // wait 5 seconds
    return await completer.future;
  }

  Future<T> run<T>(Data<T> data) async {
    return data.run(this);
  }

  Future<void> close() async {
    return socket.close();
  }
}

abstract class Data<T> {
  Future<T> run(SocketConnection connection);
}

class SendData implements Data<void> {
  SendData(this.data);

  final List<int> data;

  @override
  Future<void> run(SocketConnection connection) async {
    return connection.socket.addStream(Stream.value(data));
  }
}

class ReceiveData<T> implements Data<T> {
  ReceiveData(this.dataValidator, this.mapper);

  final Function dataValidator;
  final Function mapper;

  @override
  Future<T> run(SocketConnection connection) async {
    return connection.subject
        .firstWhere((value) => dataValidator(value))
        .then((value) {
      connection.buffer.clear();
      return mapper(value);
    });
  }
}

class HandshakeData<T> implements Data<T> {
  HandshakeData(this.sendData, this.receiveData);

  HandshakeData.data(List<int> data, Function dataValidator, Function mapper)
      : this(SendData(data), ReceiveData(dataValidator, mapper));

  final SendData sendData;
  final ReceiveData<T> receiveData;

  @override
  Future<T> run(SocketConnection connection) async {
    await sendData.run(connection);
    return receiveData.run(connection);
  }
}
