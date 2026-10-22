import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  static var pendingCalendarRequests: [[String: Any]] = []
  static var calendarIntentChannel: FlutterMethodChannel?
  static var dartReady = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard
      let registrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "CalendarIntentBridge"
      )
    else {
      fatalError("Unable to register the calendar intent channel.")
    }
    let channel = FlutterMethodChannel(
      name: "calendar/native_intents",
      binaryMessenger: registrar.messenger()
    )
    Self.calendarIntentChannel = channel
    channel.setMethodCallHandler { call, result in
      if call.method == "takePendingEvents" {
        Self.dartReady = true
        result(Self.pendingCalendarRequests)
        Self.pendingCalendarRequests.removeAll()
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard url.pathExtension.lowercased() == "ics" else { return false }
    Self.handleCalendarURL(url)
    return true
  }

  static func handleCalendarURL(_ url: URL) {
    guard url.pathExtension.lowercased() == "ics" else { return }
    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed { url.stopAccessingSecurityScopedResource() }
    }
    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch {
      dispatchCalendarRequest([
        "kind": "error",
        "code": "calendarFileReadError",
        "details": error.localizedDescription
      ])
      return
    }
    guard let contents = String(data: data, encoding: .utf8) else {
      dispatchCalendarRequest([
        "kind": "error",
        "code": "calendarFileReadError",
        "details": "The selected file is not valid UTF-8."
      ])
      return
    }

    let request: [String: Any] = ["kind": "ics", "contents": contents]
    dispatchCalendarRequest(request)
  }

  private static func dispatchCalendarRequest(_ request: [String: Any]) {
    if dartReady {
      calendarIntentChannel?.invokeMethod("incomingCalendarRequest", arguments: request)
    } else {
      pendingCalendarRequests.append(request)
    }
  }
}
