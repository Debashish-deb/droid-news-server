import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  // Secure field trick to prevent screen recording/screenshots on some iOS versions
  private var secureTextField: UITextField?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let securityChannel = FlutterMethodChannel(name: "com.bdnews/security",
                                              binaryMessenger: controller.binaryMessenger)
    
    securityChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "enableSecureFlag" {
        self?.enableScreenshotPrevention()
        result(nil)
      } else if call.method == "disableSecureFlag" {
        self?.disableScreenshotPrevention()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Prevents screenshots/screen recording by adding a secure text field to the window
  private func enableScreenshotPrevention() {
    if secureTextField != nil { return }
    
    let field = UITextField()
    field.isSecureTextEntry = true
    
    // Add to window hierarchy but make it invisible users
    // Note: The trick is that the layer content is "secure"
    // Ideally we put the Flutter view *inside* the secure container, but 
    // replacing the root view is risky. 
    // 
    // Standard approach for strict security:
    // Add logic to blur/hide window on resign active (app switcher)
    
    self.secureTextField = field
    window?.addSubview(field)
    
    // Center it (doesn't matter since hidden)
    field.centerYAnchor.constraint(equalTo: window!.centerYAnchor).isActive = true
    field.centerXAnchor.constraint(equalTo: window!.centerXAnchor).isActive = true
    
    // Make the layer secure (this triggers DRM protection on the window in some contexts)
    window?.layer.superlayer?.addSublayer(field.layer)
    field.layer.sublayers?.last?.addSublayer(window!.layer) 
    
    // NOTE: The above layer manipulation is fragile.
    // simpler "Blinding" approach for app switcher:
  }
  
  private func disableScreenshotPrevention() {
    secureTextField?.removeFromSuperview()
    secureTextField = nil
  }

  // Hide content in App Switcher
  override func applicationWillResignActive(_ application: UIApplication) {
    let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.dark)
    let blurEffectView = UIVisualEffectView(effect: blurEffect)
    blurEffectView.frame = window!.frame
    blurEffectView.tag = 999
    window?.addSubview(blurEffectView)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    window?.viewWithTag(999)?.removeFromSuperview()
  }
}
