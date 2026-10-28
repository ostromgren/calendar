import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let appGroupIdentifier = "group.com.example.calendar"
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

    guard
      let widgetRegistrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "CalendarWidgetBridge"
      )
    else {
      fatalError("Unable to register the calendar widget channel.")
    }
    let widgetChannel = FlutterMethodChannel(
      name: "calendar/widget",
      binaryMessenger: widgetRegistrar.messenger()
    )
    widgetChannel.setMethodCallHandler { call, result in
      guard call.method == "syncLocalEvents" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let events = arguments["events"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_widget_events",
            message: "Local event data was missing or invalid.",
            details: nil
          )
        )
        return
      }
      guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) else {
        result(
          FlutterError(
            code: "widget_storage_unavailable",
            message: "Shared storage for the calendar widget is unavailable.",
            details: nil
          )
        )
        return
      }
      defaults.set(events, forKey: "localCalendarEvents")
      WidgetCenter.shared.reloadAllTimelines()
      result(nil)
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
