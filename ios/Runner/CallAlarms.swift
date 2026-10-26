import AlarmKit
import AppIntents
import Flutter
import SwiftUI
import UserNotifications

/// Alarm modu, iOS 26+: doz saatinde Dynamic Island'da ve kilit ekranında
/// "Ertele" / "Aç" butonlu alarm (AlarmKit). Dart tarafı
/// notification_service.dart; daha eski iOS'ta orası bildirime düşer.
enum CallAlarms {
  static let channelName = "takeapill/call"
  private static let actionsKey = "takeapill.alarmActions"

  /// Ana motorun kanalı; butonlar açık uygulamaya buradan haber verir.
  private static var mainChannel: FlutterMethodChannel?

  /// Ana motor ve bildirim butonlarının arka plan motoru için ayrı ayrı.
  static func register(messenger: FlutterBinaryMessenger, main: Bool) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler(handle)
    if main { mainChannel = channel }
  }

  private static func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "takeAlarmActions":
      let defaults = UserDefaults.standard
      result(defaults.stringArray(forKey: actionsKey) ?? [])
      defaults.removeObject(forKey: actionsKey)
    case "alarmState", "requestAlarms", "scheduleAlarms":
      guard #available(iOS 26.0, *) else {
        result(call.method == "alarmState" ? "unsupported" : false)
        return
      }
      Task { @MainActor in
        do {
          result(try await handleAlarm(call))
        } catch {
          result(FlutterError(code: "alarm", message: "\(error)", details: nil))
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 26.0, *)
  @MainActor
  private static func handleAlarm(_ call: FlutterMethodCall) async throws -> Any? {
    let manager = AlarmManager.shared
    switch call.method {
    case "alarmState":
      switch manager.authorizationState {
      case .authorized: return "authorized"
      case .notDetermined: return "notDetermined"
      default: return "denied"
      }
    case "requestAlarms":
      if manager.authorizationState == .notDetermined {
        return try await manager.requestAuthorization() == .authorized
      }
      return manager.authorizationState == .authorized
    default:  // scheduleAlarms
      // Plan her senkronda baştan kurulur; uygulamanın tüm alarmları bizimdir.
      for alarm in try manager.alarms {
        try? manager.cancel(id: alarm.id)
      }
      for case let args as [String: Any] in call.arguments as? [Any] ?? [] {
        if let spec = CallSpec(args) { try await schedule(spec) }
      }
      return nil
    }
  }

  @available(iOS 26.0, *)
  static func schedule(_ spec: CallSpec) async throws {
    let alert = AlarmPresentation.Alert(
      title: LocalizedStringResource(stringLiteral: spec.title),
      stopButton: AlarmButton(
        text: "Ertele", textColor: .white, systemImageName: "zzz"),
      secondaryButton: AlarmButton(
        text: "Aç", textColor: .white, systemImageName: "pills.fill"),
      secondaryButtonBehavior: .custom
    )
    let attributes = AlarmAttributes<CallMetadata>(
      presentation: AlarmPresentation(alert: alert),
      metadata: CallMetadata(),
      tintColor: Color(red: 0.06, green: 0.46, blue: 0.43)
    )
    _ = try await AlarmManager.shared.schedule(
      id: UUID(),
      configuration: .alarm(
        schedule: .fixed(spec.at),
        attributes: attributes,
        stopIntent: DeclineCallIntent(spec),
        secondaryIntent: AnswerCallIntent(payload: spec.payload),
        sound: .named("alarm.caf")
      )
    )
  }

  /// Buton işlemi "eylem|payload|ms" olarak saklanır; Dart açılışta, öne
  /// gelince ya da (uygulama açıksa) hemen işler.
  static func record(_ action: String, payload: String, at: Date) {
    let defaults = UserDefaults.standard
    var actions = defaults.stringArray(forKey: actionsKey) ?? []
    actions.append("\(action)|\(payload)|\(Int64(at.timeIntervalSince1970 * 1000))")
    defaults.set(actions, forKey: actionsKey)
    DispatchQueue.main.async { mainChannel?.invokeMethod("alarmActions", arguments: nil) }
  }
}

struct CallSpec {
  let at: Date
  let title: String
  let payload: String
  let snoozeMinutes: Int
  /// Ertelenince kaldırılacak bekleyen bildirimler ("Aldın mı?").
  let cancelIds: [String]

  init(at: Date, title: String, payload: String, snoozeMinutes: Int, cancelIds: [String]) {
    self.at = at
    self.title = title
    self.payload = payload
    self.snoozeMinutes = snoozeMinutes
    self.cancelIds = cancelIds
  }

  init?(_ args: [String: Any]) {
    guard let ms = args["at"] as? Int64 ?? (args["at"] as? Int).map(Int64.init),
      let title = args["title"] as? String,
      let payload = args["payload"] as? String,
      let snooze = args["snoozeMinutes"] as? Int
    else { return nil }
    self.init(
      at: Date(timeIntervalSince1970: Double(ms) / 1000),
      title: title,
      payload: payload,
      snoozeMinutes: snooze,
      cancelIds: (args["cancelIds"] as? [Int] ?? []).map(String.init)
    )
  }
}

@available(iOS 26.0, *)
struct CallMetadata: AlarmMetadata {}

/// "Ertele": uygulamayı açmadan dozu erteler; erteleme alarmını burada kurar,
/// Dart'a da kaydeder ki plan yenilenince erteleme korunsun.
@available(iOS 26.0, *)
struct DeclineCallIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Ertele"
  static let isDiscoverable = false

  @Parameter(title: "Doz") var payload: String
  @Parameter(title: "Başlık") var name: String
  @Parameter(title: "Erteleme") var snoozeMinutes: Int
  @Parameter(title: "Bildirimler") var cancelIds: String

  init() {}

  init(_ spec: CallSpec) {
    payload = spec.payload
    name = spec.title
    snoozeMinutes = spec.snoozeMinutes
    cancelIds = spec.cancelIds.joined(separator: ",")
  }

  func perform() async throws -> some IntentResult {
    let now = Date()
    let ids = cancelIds.split(separator: ",").map(String.init)
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    try await CallAlarms.schedule(
      CallSpec(
        at: now.addingTimeInterval(Double(snoozeMinutes) * 60),
        title: name,
        payload: payload,
        snoozeMinutes: snoozeMinutes,
        cancelIds: []
      )
    )
    // Alarm kurulduktan sonra: açık uygulama planı yenilerken bunu silip
    // aynı saate yeniden kurar; tersi sırada iki alarm çalabilirdi.
    CallAlarms.record("decline", payload: payload, at: now)
    return .result()
  }
}

/// "Aç": uygulamayı Bugün ekranında açar; doz orada işaretlenir.
@available(iOS 26.0, *)
struct AnswerCallIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Aç"
  static let isDiscoverable = false
  static let openAppWhenRun = true

  @Parameter(title: "Doz") var payload: String

  init() {}

  init(payload: String) {
    self.payload = payload
  }

  func perform() async throws -> some IntentResult {
    CallAlarms.record("answer", payload: payload, at: Date())
    return .result()
  }
}
