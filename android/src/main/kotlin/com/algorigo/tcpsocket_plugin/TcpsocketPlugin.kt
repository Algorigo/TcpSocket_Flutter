package com.algorigo.tcpsocket_plugin

import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers
import io.reactivex.rxjava3.core.Completable
import io.reactivex.rxjava3.core.Single
import io.reactivex.rxjava3.schedulers.Schedulers
import java.net.NetworkInterface
import java.net.Socket
import java.nio.ByteBuffer

/** TcpsocketPlugin */
class TcpsocketPlugin: FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var eventChannel: EventChannel

  private val socketMap = mutableMapOf<Int, Socket>()
  private val eventChannelSink = mutableMapOf<Int, EventChannel.EventSink>()
  private val socketClose = mutableListOf<Int>()

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "tcpsocket_plugin")
    channel.setMethodCallHandler(this)

    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "tcpsocket_plugin_connect")
    eventChannel.setStreamHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
      "connect" -> {
        val address = call.argument<String>("address")
        val port = call.argument<Int>("port")
        val timeout = call.argument<Int>("timeout")
        Log.e("!!!", "connect:$address, $port, $timeout")
        if (address != null && port != null) {
          Single.create<Int> {
            val socket = Socket(address, port).apply {
              if (timeout != null) {
                soTimeout = timeout
              }
            }
            val identityHashCode = System.identityHashCode(socket)
            socketMap[identityHashCode] = socket
            it.onSuccess(identityHashCode)
          }
            .subscribeOn(Schedulers.io())
            .observeOn(AndroidSchedulers.mainThread())
            .subscribe({
              result.success(it)
            }, {
              result.error(it.javaClass.simpleName, it.localizedMessage, null)
            })
        } else {
          result.error(IllegalArgumentException::class.java.simpleName, "address:$address, port:$port", null)
        }
      }
      "sendData" -> {
        val identityHashCode = call.argument<Int>("id")
        val data = call.argument<List<Int>>("data")?.map { it.toByte() }
        Log.e("!!!", "sendData:$identityHashCode, $data")
        if (identityHashCode != null && data != null && socketMap[identityHashCode] != null) {
          socketMap[identityHashCode]?.getOutputStream()?.write(ByteArray(data.size) { data[it] })
          result.success(null)
        } else {
          result.error(IllegalArgumentException::class.java.simpleName, "id:$identityHashCode, data:$data, socket:${socketMap[identityHashCode]}", null)
        }
      }
      "close" -> {
        val identityHashCode = call.argument<Int>("id")
        Log.e("!!!", "close:$identityHashCode")
        if (identityHashCode != null) {
          socketClose.add(identityHashCode)
        }
      }
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    val identityHashCode = arguments as? Int
    Log.e("!!!", "onListen:$identityHashCode")
    if (identityHashCode != null && events != null) {
      eventChannelSink[identityHashCode] = events
    }
  }

  override fun onCancel(arguments: Any?) {
    val identityHashCode = arguments as? Int
    Log.e("!!!", "onCancel:$identityHashCode")
    if (identityHashCode != null) {
      eventChannelSink.remove(identityHashCode)
    }
  }

  private fun messageHandle(identityHashCode: Int) {
    val byteBuffer = ByteBuffer.allocate(100000)
    var bufferSize = 0

    val socket = socketMap[identityHashCode] ?: return
    val inputStream = socket.getInputStream()

    while (!socketClose.contains(identityHashCode)) {
      try {
        val length = inputStream.available()
        if (length > 0) {
          val bytes = ByteArray(length)
          inputStream.read(bytes)
          byteBuffer.put(bytes)
          bufferSize += length
        }
      } catch (e: Exception) {
        Log.e(LOG_TAG, "", e)
        eventChannelSink[identityHashCode]?.error(e.javaClass.simpleName, e.localizedMessage, null)
        break
      }

      val intList = byteBuffer.array().copyOf(bufferSize).map { it.toInt() }
      Log.e(LOG_TAG, "receiving byteArray:${intList.toTypedArray().contentToString()}")

      eventChannelSink[identityHashCode]?.success(intList)

      try {
        Thread.sleep(500)
      } catch (e: InterruptedException) {
        Log.e(LOG_TAG, "interruptedException")
      }
    }

  socketMap.remove(identityHashCode)
    try {
      socket.close()
    } catch (e: Exception) {
      Log.e(LOG_TAG, "", e)
    } finally {
      Log.e("!!!", "111")
      socket.getInputStream()?.close()
      Log.e("!!!", "222")
      socket.getOutputStream()?.close()
      Log.e("!!!", "333")
    }
  }

  companion object {
    private val LOG_TAG = "!!!"//TcpsocketPlugin::class.java.simpleName
  }
}
