import UIKit
import Flutter

let flutterEngine = FlutterEngine(name: "SharedEngine", project: nil, allowHeadlessExecution: true)

// Accessible from CarPlaySceneDelegate to notify Flutter when CarPlay connects
var appCarPlayChannel: FlutterMethodChannel?

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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
      }
      result(nil)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
