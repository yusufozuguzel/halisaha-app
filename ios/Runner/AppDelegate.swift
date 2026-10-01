import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var mapsChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    var mapsReady = false
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
       !key.contains("$(") {
      mapsReady = GMSServices.provideAPIKey(key)
    }
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "DeparMapsConfiguration") {
      mapsChannel = FlutterMethodChannel(
        name: "depar/maps_configuration", binaryMessenger: registrar.messenger())
      mapsChannel?.setMethodCallHandler { call, result in
        if call.method == "isConfigured" {
          result(mapsReady)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
