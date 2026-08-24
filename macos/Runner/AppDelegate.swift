import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // The app lives in the menu bar by default (no Dock icon). The Dart side
    // switches this to .regular while the full app window is open.
    NSApp.setActivationPolicy(.accessory)
    registerDesktopShellChannel()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // The menu bar tray icon keeps the app alive after the window is closed;
    // quitting only happens via the tray menu's Quit item.
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Lets the Dart-side DesktopShellService toggle the Dock icon and quit the
  /// app cleanly, neither of which window_manager/tray_manager expose.
  private func registerDesktopShellChannel() {
    guard let controller = NSApp.windows.first?.contentViewController as? FlutterViewController
    else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "desktop_shell",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setActivationPolicy":
        let args = call.arguments as? [String: Any]
        let regular = args?["regular"] as? Bool ?? false
        NSApp.setActivationPolicy(regular ? .regular : .accessory)
        if regular {
          NSApp.activate(ignoringOtherApps: true)
        }
        result(nil)
      case "quit":
        NSApp.terminate(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
