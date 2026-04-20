import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    DebugCrashChannel.register(with: engineBridge.pluginRegistry)
  }
}

/// Handles MethodChannel calls from the Flutter debug tab that trigger real
/// native crashes. Exists solely to exercise Faro's PLCrashReporter-based
/// native crash pipeline (capture-on-crash, read-on-next-launch).
///
/// Crashes are deferred a short beat via DispatchQueue so the method-channel
/// result is delivered back to Dart cleanly before the process dies.
enum DebugCrashChannel {
  static let name = "com.grafana.quickpizza/debug/crash"

  static func register(with registry: FlutterPluginRegistry) {
    let messenger = registry.registrar(forPlugin: "DebugCrashChannel")!.messenger()
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "crashWithMessage":
        let args = call.arguments as? [String: Any]
        let message = args?["message"] as? String ?? "Deliberate crash"
        result(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          fatalError(message)
        }
      case "crashWithNullPointer":
        result(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          let value: String? = nil
          _ = value!.count
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
