
import 'dart:async';

import 'package:flutter/services.dart';

class TcpsocketPlugin {
  static const MethodChannel _channel =
      const MethodChannel('tcpsocket_plugin');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
