package com.example.flutter_mobile_o11y_demo

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DebugCrashChannel.register(flutterEngine)
    }
}

/// Handles MethodChannel calls from the Flutter debug tab that trigger real
/// native crashes. Exists solely to exercise Faro's native crash pipeline
/// (Thread.UncaughtExceptionHandler + ApplicationExitInfo; capture-on-crash,
/// read-on-next-launch).
///
/// Crashes are posted to the main Looper AFTER sending `result` back so the
/// method-channel call completes cleanly; throwing synchronously inside the
/// handler would otherwise be caught by Flutter's plugin machinery and
/// converted into a Dart-side PlatformException instead of killing the process.
private object DebugCrashChannel {
    private const val CHANNEL_NAME = "com.grafana.quickpizza/debug/crash"

    fun register(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        )
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "crashWithMessage" -> {
                    val message = call.argument<String>("message") ?: "Deliberate crash"
                    result.success(null)
                    Handler(Looper.getMainLooper()).postDelayed({
                        throw RuntimeException(message)
                    }, 100)
                }
                "crashWithNullPointer" -> {
                    result.success(null)
                    Handler(Looper.getMainLooper()).postDelayed({
                        val value: String? = null
                        value!!.length
                    }, 100)
                }
                else -> result.notImplemented()
            }
        }
    }
}
