import Flutter
import UIKit
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Bildirim butonlarının arka plan isolate'inde çalışması için gerekli.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
      // Arka plandaki senkron da ilaç alarmlarını yeniden kurabilsin.
      if let registrar = registry.registrar(forPlugin: "CallAlarms") {
        CallAlarms.register(messenger: registrar.messenger(), main: false)
      }
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CallAlarms") {
      CallAlarms.register(messenger: registrar.messenger(), main: true)
    }
  }
}
