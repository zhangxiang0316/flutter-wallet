import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var screenSecurityController: ScreenSecurityController?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let securityController = ScreenSecurityController(windowProvider: { [weak self] in
      if let appDelegateWindow = self?.window {
        return appDelegateWindow
      }
      return UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)
    })
    if let registrar = self.registrar(forPlugin: "ScreenSecurityPlugin") {
      let channel = FlutterMethodChannel(
        name: "screen_security",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak securityController] call, result in
        switch call.method {
        case "enable":
          securityController?.setEnabled(true)
          result(nil)
        case "disable":
          securityController?.setEnabled(false)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    screenSecurityController = securityController
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// iOS 隐私遮罩控制器。
///
/// iOS 不提供等价于 Android `FLAG_SECURE` 的公开 API，因此在应用切换、录屏和
/// AirPlay 镜像期间使用不透明遮罩保护 Flutter 内容。系统截图通知发生在截图完成后，
/// 收到通知时会立即覆盖界面，避免敏感内容继续暴露。
final class ScreenSecurityController {
  private let windowProvider: () -> UIWindow?
  private let overlayView: UIView
  private(set) var isEnabled = false
  private var isApplicationActive = true
  private var isScreenCaptured = false

  init(windowProvider: @escaping () -> UIWindow?) {
    self.windowProvider = windowProvider
    overlayView = UIView(frame: .zero)
    overlayView.backgroundColor = UIColor.systemBackground
    overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlayView.accessibilityIdentifier = "walletPrivacyOverlay"

    let icon = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
    icon.tintColor = UIColor.secondaryLabel
    icon.contentMode = .scaleAspectFit
    icon.translatesAutoresizingMaskIntoConstraints = false
    overlayView.addSubview(icon)
    NSLayoutConstraint.activate([
      icon.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),
      icon.widthAnchor.constraint(equalToConstant: 48),
      icon.heightAnchor.constraint(equalToConstant: 48),
    ])

    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(
      self,
      selector: #selector(applicationWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    notificationCenter.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    notificationCenter.addObserver(
      self,
      selector: #selector(screenCaptureDidChange),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    notificationCenter.addObserver(
      self,
      selector: #selector(userDidTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
  }

  convenience init(window: UIWindow?) {
    self.init(windowProvider: { [weak window] in window })
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  func setEnabled(_ enabled: Bool) {
    isEnabled = enabled
    isScreenCaptured = UIScreen.main.isCaptured
    updateOverlayVisibility()
  }

  @objc func applicationWillResignActive() {
    isApplicationActive = false
    updateOverlayVisibility()
  }

  @objc func applicationDidBecomeActive() {
    isApplicationActive = true
    isScreenCaptured = UIScreen.main.isCaptured
    updateOverlayVisibility()
  }

  @objc func screenCaptureDidChange() {
    isScreenCaptured = UIScreen.main.isCaptured
    updateOverlayVisibility()
  }

  @objc func userDidTakeScreenshot() {
    guard isEnabled else { return }
    showOverlay()
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      self?.updateOverlayVisibility()
    }
  }

  private func updateOverlayVisibility() {
    guard isEnabled, !isApplicationActive || isScreenCaptured else {
      hideOverlay()
      return
    }
    showOverlay()
  }

  private func showOverlay() {
    guard let window = windowProvider() else { return }
    overlayView.frame = window.bounds
    if overlayView.superview !== window {
      window.addSubview(overlayView)
    }
    window.bringSubviewToFront(overlayView)
  }

  private func hideOverlay() {
    overlayView.removeFromSuperview()
  }
}
