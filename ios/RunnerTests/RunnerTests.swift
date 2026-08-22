import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testPrivacyOverlayFollowsLifecycleWhenProtectionIsEnabled() {
    let window = UIWindow(frame: UIScreen.main.bounds)
    let controller = ScreenSecurityController(window: window)

    controller.setEnabled(true)
    controller.applicationWillResignActive()
    XCTAssertTrue(window.subviews.contains { $0.accessibilityIdentifier == "walletPrivacyOverlay" })

    controller.applicationDidBecomeActive()
    if !UIScreen.main.isCaptured {
      XCTAssertFalse(window.subviews.contains { $0.accessibilityIdentifier == "walletPrivacyOverlay" })
    }
  }

  func testDisablingProtectionRemovesPrivacyOverlay() {
    let window = UIWindow(frame: UIScreen.main.bounds)
    let controller = ScreenSecurityController(window: window)

    controller.setEnabled(true)
    controller.applicationWillResignActive()
    controller.setEnabled(false)

    XCTAssertFalse(window.subviews.contains { $0.accessibilityIdentifier == "walletPrivacyOverlay" })
  }
}
