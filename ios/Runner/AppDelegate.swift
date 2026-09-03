import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Provide the Google Maps key before any map is created. The key is
    // injected from ios/Flutter/maps-key.xcconfig via Info.plist's MapsApiKey
    // ($(MAPS_API_KEY)) and is never committed to version control.
    if let mapsKey = Bundle.main.object(forInfoDictionaryKey: "MapsApiKey") as? String,
       !mapsKey.isEmpty, mapsKey != "YOUR_IOS_API_KEY" {
      GMSServices.provideAPIKey(mapsKey)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
