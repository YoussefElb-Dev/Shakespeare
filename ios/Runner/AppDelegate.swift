import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "ShakespeareGlass") {
      registrar.register(GlassFactory(), withId: "app.shakespeare/glass-surface")
      let channel = FlutterMethodChannel(name: "app.shakespeare/glass", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "isAvailable" else { result(FlutterMethodNotImplemented); return }
        if #available(iOS 26.0, *) { result(true) } else { result(false) }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// Kept in this compilation unit so no Xcode project file discovery is required.
private final class GlassFactory: NSObject, FlutterPlatformViewFactory {
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    GlassPlatformView(frame: frame)
  }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
}

private final class GlassPlatformView: NSObject, FlutterPlatformView {
  private let surface: UIView
  init(frame: CGRect) {
    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect(style: .regular)
      effect.isInteractive = true
      let glass = UIVisualEffectView(effect: effect)
      glass.overrideUserInterfaceStyle = .dark
      surface = glass
    } else {
      surface = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    }
    surface.frame = frame
    surface.layer.cornerRadius = 28
    surface.clipsToBounds = true
    surface.isAccessibilityElement = false
    super.init()
  }
  func view() -> UIView { surface }
}
