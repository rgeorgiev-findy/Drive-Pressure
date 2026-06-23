import UIKit
import Flutter

let flutterEngine = FlutterEngine(name: "SharedEngine", project: nil, allowHeadlessExecution: true)

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var carPlayChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)

    // Receive live tire data from Flutter and forward to the CarPlay scene
    carPlayChannel = FlutterMethodChannel(
      name: "eu.findy.drivePressure/carplay",
      binaryMessenger: flutterEngine.binaryMessenger
    )
    carPlayChannel?.setMethodCallHandler { call, result in
      if call.method == "update",
         let data = call.arguments as? [String: Any] {
        carPlaySceneDelegate?.receiveVehicles(data)
      }
      result(nil)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
