package com.example.smart_cabinet

import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "smart_cabinet/ble_background"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val intent = Intent(this, BleForegroundService::class.java).apply {
                            action = BleForegroundService.ACTION_START
                            putExtra(BleForegroundService.EXTRA_MESSAGE,
                                call.argument<String>("message"))
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "update" -> {
                        startService(Intent(this, BleForegroundService::class.java).apply {
                            action = BleForegroundService.ACTION_UPDATE
                            putExtra(BleForegroundService.EXTRA_MESSAGE,
                                call.argument<String>("message"))
                        })
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, BleForegroundService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
