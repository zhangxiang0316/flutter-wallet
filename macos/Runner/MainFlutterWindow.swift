import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // 设置窗口默认大小为 iPhone 尺寸（375x812）
    let phoneWidth: CGFloat = 375
    let phoneHeight: CGFloat = 812

    // 获取屏幕中心位置
    if let screen = NSScreen.main {
      let screenRect = screen.visibleFrame
      let newX = screenRect.origin.x + (screenRect.width - phoneWidth) / 2
      let newY = screenRect.origin.y + (screenRect.height - phoneHeight) / 2

      let newFrame = NSRect(x: newX, y: newY, width: phoneWidth, height: phoneHeight)
      self.setFrame(newFrame, display: true)
    }

    // 设置窗口最小尺寸
    self.minSize = NSSize(width: 375, height: 600)

    // 设置窗口标题
    self.title = "flutter Wallet"
  }
}
