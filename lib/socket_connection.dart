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

  Stream<T> run<T>(Data<T> data) {
    return data.run(this);
  }

  Future<void> close() async {
    return socket.close();
  }
}

abstract class Data<T> {
  Stream<T> run(SocketConnection connection);
}

class SendData implements Data<void> {
  SendData(this.data);

  final List<int> data;

  @override
  Stream<void> run(SocketConnection connection) {
    StreamController controller = StreamController();
    connection.socket.addStream(Stream.value(data)).then(
        (value) => controller.done,
        onError: (error) => controller.addError(error));
    return controller.stream;
  }
}

class ReceiveData<T> implements Data<T> {
  ReceiveData(this.dataValidator, this.mapper);

  final Function dataValidator;
  final Function mapper;

  @override
  Stream<T> run(SocketConnection connection) {
    return connection.subject
        .firstWhere((value) => dataValidator(value))
        .then((value) {
      connection.buffer.clear();
      return mapper(value);
    }).asStream();
  }
}

class HandshakeData<T> implements Data<T> {
  HandshakeData(this.sendData, this.receiveData);

  HandshakeData.data(List<int> data, Function dataValidator, Function mapper)
      : this(SendData(data), ReceiveData(dataValidator, mapper));

  final SendData sendData;
  final ReceiveData<T> receiveData;

  @override
  Stream<T> run(SocketConnection connection) {
    return sendData.run(connection).andThen(receiveData.run(connection));
  }
}

extension _Completable<T> on Stream<T> {
  Stream<V> andThen<V>(Stream<V> stream) {
    var streamController = StreamController<V>();
    StreamSubscription subscription;
    return streamController.stream
    .doOnListen(() {
      subscription = stream.listen((event) {
        streamController.add(event);
      }, onError: (error) {
        streamController.addError(error);
      }, onDone: () {
        streamController.close();
      });
    }).doOnCancel(() {
      subscription.cancel();
    });
  }
}
