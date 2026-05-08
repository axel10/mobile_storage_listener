package com.example.mobile_storage_listener

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.plugin.common.EventChannel
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** MobileStorageListenerPlugin */
class MobileStorageListenerPlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var applicationContext: Context? = null
    private var eventSink: EventChannel.EventSink? = null
    private var storageReceiver: BroadcastReceiver? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "mobile_storage_listener")
        eventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "mobile_storage_listener/events"
        )
        channel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else {
            result.notImplemented()
        }
    }

    override fun onListen(
        arguments: Any?,
        events: EventChannel.EventSink?
    ) {
        eventSink = events
        startListening()
    }

    override fun onCancel(arguments: Any?) {
        stopListening()
        eventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopListening()
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        applicationContext = null
        eventSink = null
    }

    private fun startListening() {
        if (storageReceiver != null) {
            return
        }

        val context = applicationContext ?: return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                val path = intent.data?.path
                val type = when (action) {
                    Intent.ACTION_MEDIA_MOUNTED -> "mounted"
                    Intent.ACTION_MEDIA_UNMOUNTED -> "unmounted"
                    Intent.ACTION_MEDIA_REMOVED -> "removed"
                    Intent.ACTION_MEDIA_EJECT -> "eject"
                    Intent.ACTION_MEDIA_BAD_REMOVAL -> "bad_removal"
                    else -> "unknown"
                }

                eventSink?.success(
                    mapOf(
                        "type" to type,
                        "path" to path
                    )
                )
            }
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_MEDIA_MOUNTED)
            addAction(Intent.ACTION_MEDIA_UNMOUNTED)
            addAction(Intent.ACTION_MEDIA_REMOVED)
            addAction(Intent.ACTION_MEDIA_EJECT)
            addAction(Intent.ACTION_MEDIA_BAD_REMOVAL)
            addDataScheme("file")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }
        storageReceiver = receiver
    }

    private fun stopListening() {
        val receiver = storageReceiver ?: return
        val context = applicationContext

        if (context != null) {
            try {
                context.unregisterReceiver(receiver)
            } catch (_: IllegalArgumentException) {
                // Receiver already unregistered.
            }
        }

        storageReceiver = null
    }
}
