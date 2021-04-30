import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tcpsocket_plugin/socket_connection.dart';
import 'package:tcpsocket_plugin/tcpsocket_plugin.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static final String KEY_SERVER = "KEY_SERVER";
  static final String KEY_PORT = "KEY_PORT";

  final scaffoldKey = GlobalKey<ScaffoldState>();

  String _platformVersion = 'Unknown';
  final _serverController = TextEditingController();
  final _portController = TextEditingController();

  int get _port {
    return int.parse(_portController.text) ?? -1;
  }

  bool get _connected {
    return _subscription != null;
  }

  String get _connectTitle {
    return _connected ? "Disconnect" : "Connect";
  }

  String _send = "";
  String _receive = "";
  StreamSubscription _subscription;
  SocketConnection _socketConnection;
  String _result = "";

  @override
  void initState() {
    super.initState();
    initPlatformState();
    SharedPreferences.getInstance().then((sp) {
      setState(() {
        _serverController.text = sp.getString(KEY_SERVER);
        _portController.text = sp.getInt(KEY_PORT)?.toString() ?? -1;
      });
    });
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await TcpsocketPlugin.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> connect() async {
    if (_connected) {
      print("disconnect");
      _subscription.cancel();
      setState(() {
        _subscription = null;
      });
    } else {
      var server = _serverController.text;
      if (server.isNotEmpty) {
        SocketClient socketClient = SocketClient(server, _port);
        _subscription = socketClient.connect().doOnCancel(() {
          _subscription = null;
          _socketConnection = null;
        }).listen((connection) async {
          print("listen:$connection");
          _socketConnection = connection;
          var sp = await SharedPreferences.getInstance();
          sp.setString(KEY_SERVER, server);
          sp.setInt(KEY_PORT, _port);
        }, onError: (error) {
          _subscription = null;
          _socketConnection = null;
        }, cancelOnError: true);
        setState(() {});
      }
    }
  }

  Future<void> send() async {
    _socketConnection?.run(HandshakeData.data(
        utf8.encode(_send), (list) => list.length > 0, (received) {
      print("received:$received");
      return utf8.decode(received);
    })).doOnListen(() {
      setState(() {
        _receive += "\n";
      });
    }).listen((result) {
      print("result:$result");
      setState(() {
        _receive += (result ?? "null");
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
              Text('Running on: $_platformVersion\n'),
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
              ElevatedButton(onPressed: connect, child: Text(_connectTitle)),
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
