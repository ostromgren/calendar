import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  static var pendingCalendarRequests: [[String: Any]] = []
  static var calendarIntentChannel: FlutterMethodChannel?
  static var dartReady = false

  static func configureCalendarIntents(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "calendar/native_intents",
      binaryMessenger: messenger
    )
    calendarIntentChannel = channel
    channel.setMethodCallHandler { call, result in
      if call.method == "takePendingEvents" {
        dartReady = true
        result(pendingCalendarRequests)
        pendingCalendarRequests.removeAll()
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    guard filename.lowercased().hasSuffix(".ics") else { return false }
    Self.handleCalendarFile(URL(fileURLWithPath: filename))
    return true
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    for filename in filenames where filename.lowercased().hasSuffix(".ics") {
      Self.handleCalendarFile(URL(fileURLWithPath: filename))
    }
    sender.reply(toOpenOrPrint: .success)
  }

  private static func handleCalendarFile(_ url: URL) {
    let request: [String: Any]
    do {
      let data = try Data(contentsOf: url)
      guard let contents = String(data: data, encoding: .utf8) else {
        dispatchCalendarRequest([
          "kind": "error",
          "code": "calendarFileReadError",
          "details": "The selected file is not valid UTF-8."
        ])
        return
      }
      request = ["kind": "ics", "contents": contents]
    } catch {
      dispatchCalendarRequest([
        "kind": "error",
        "code": "calendarFileReadError",
        "details": error.localizedDescription
      ])
      return
    }
    dispatchCalendarRequest(request)
  }

  private static func dispatchCalendarRequest(_ request: [String: Any]) {
    if dartReady {
      calendarIntentChannel?.invokeMethod("incomingCalendarRequest", arguments: request)
    } else {
      pendingCalendarRequests.append(request)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
