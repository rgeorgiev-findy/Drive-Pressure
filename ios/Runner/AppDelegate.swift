import UIKit
import Flutter
import UserNotifications

let flutterEngine = FlutterEngine(name: "SharedEngine", project: nil, allowHeadlessExecution: true)

// Accessible from CarPlaySceneDelegate to notify Flutter when CarPlay connects
var appCarPlayChannel: FlutterMethodChannel?

// Used by FindyBLEManager to push background BLE packets into Flutter's BleService
var nativeBleChannel: FlutterMethodChannel?

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Start native BLE manager immediately — BEFORE super.application() returns.
    // iOS requires the CBCentralManager with the restore identifier to be allocated
    // inside didFinishLaunchingWithOptions when the app is relaunched for BLE restoration.
    FindyBLEManager.shared.start()

    // Only run the Flutter engine when NOT launched purely for BLE state restoration.
    // When launched for restoration, the engine starts but stays headless; Flutter
    // BleService will re-start scanning after the app comes to the foreground.
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)

    appCarPlayChannel = FlutterMethodChannel(
      name: "eu.findy.drivePressure/carplay",
      binaryMessenger: flutterEngine.binaryMessenger
    )
    appCarPlayChannel?.setMethodCallHandler { call, result in
      if call.method == "update",
         let data = call.arguments as? [String: Any] {
        carPlaySceneDelegate?.receiveVehicles(data)
      } else if call.method == "alert",
                let data = call.arguments as? [String: Any] {
        let title = data["title"] as? String ?? "TPMS Alert"
        let body  = data["body"]  as? String ?? ""
        DispatchQueue.main.async {
          carPlaySceneDelegate?.showAlert(title: title, body: body)
        }
      }
      result(nil)
    }

    nativeBleChannel = FlutterMethodChannel(
      name: "eu.findy.drivePressure/native_ble",
      binaryMessenger: flutterEngine.binaryMessenger
    )

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Ensure this AppDelegate is the UNUserNotificationCenter delegate so that
    // willPresent is called (and banners shown) while the app is in the foreground.
    UNUserNotificationCenter.current().delegate = self
    return result
  }

  // Show notification banners even when the app is in the foreground.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .badge, .sound])
  }
}
