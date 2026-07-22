import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tcpsocket_plugin/socket_connection.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static final String keyServer = "KEY_SERVER";
  static final String keyPort = "KEY_PORT";

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final _serverController = TextEditingController();
  final _portController = TextEditingController();

  int get _port {
    return int.parse(_portController.text);
  }

  bool get _connected {
    return _socketConnection != null;
  }

  bool get _connecting {
    return _subscription != null && _socketConnection == null;
  }

  String get _connectTitle {
    return _connected ? "Disconnect" : "Connect";
  }

  String _send = "";
  String _receive = "";
  StreamSubscription? _subscription;
  SocketConnection? _socketConnection;
  String _result = "";

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((sp) {
      setState(() {
        _serverController.text = sp.getString(keyServer) ?? "";
        _portController.text = sp.getInt(keyPort)?.toString() ?? "-1";
      });
    });
  }

  Future<void> connect() async {
    if (_connected) {
      print("disconnect");
      _subscription?.cancel();
      setState(() {
        _subscription = null;
      });
    } else {
      var server = _serverController.text;
      if (server.isNotEmpty) {
        SocketClient socketClient = SocketClient(server, _port);
        _subscription = socketClient.connect().doOnCancel(() {
          setState(() {
            _subscription = null;
            _socketConnection = null;
          });
        }).listen((connection) async {
          print("listen:$connection");
          setState(() {
            _socketConnection = connection;
          });
          var sp = await SharedPreferences.getInstance();
          sp.setString(keyServer, server);
          sp.setInt(keyPort, _port);
        }, onError: (error) {
          _result = "Connect Error:$error";
          setState(() {
            _subscription = null;
            _socketConnection = null;
          });
        }, cancelOnError: true);
      }
      setState(() {});
    }
  }

  Future<void> send() async {
    _socketConnection
        ?.run(HandshakeData.data(utf8.encode(_send), (list) => list.length > 0,
            (received) {
      print("received:$received");
      return utf8.decode(received);
    }))
        .doOnListen(() {
      setState(() {
        _receive += "\n";
      });
    }).listen((result) {
      print("result:$result");
      setState(() {
        _receive += result;
      });
    }, onError: (error) {
      print("error:$error");
      setState(() {
        _receive = "onError:$error";
      });
    }, onDone: () {
      print("onDone");
      _receive += ":onDone";
    }, cancelOnError: true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            children: [
              TextField(
                controller: _serverController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(hintText: '서버'),
                enabled: !_connected,
              ),
              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: 'Port'),
                enabled: !_connected,
              ),
              ElevatedButton(
                onPressed: _connecting ? null : connect,
                child: Text(_connectTitle),
              ),
              TextField(
                keyboardType: TextInputType.text,
                decoration: InputDecoration(hintText: 'Send Data'),
                onChanged: (value) {
                  _send = value;
                },
                enabled: _connected,
              ),
              ElevatedButton(
                onPressed: _connected ? send : null,
                child: Text("Send"),
              ),
              Text(_result),
              Expanded(
                child: Text(_receive),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
