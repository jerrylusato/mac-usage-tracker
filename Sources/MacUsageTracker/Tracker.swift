import AppKit
import Combine
import CoreGraphics
import ServiceManagement
import UsageCore
import UserNotifications

@MainActor
final class Tracker: NSObject, ObservableObject {
  @Published private(set) var sessions: [UsageSession] = []
  @Published private(set) var status = "Starting"
  @Published var errorMessage: String?
  @Published var paused = false
  @Published var idleThreshold: Double =
    UserDefaults.standard.object(forKey: "idleThreshold") as? Double ?? 120
  {
    didSet { UserDefaults.standard.set(idleThreshold, forKey: "idleThreshold") }
  }
  @Published var dailyReport = UserDefaults.standard.bool(forKey: "dailyReport") {
    didSet { UserDefaults.standard.set(dailyReport, forKey: "dailyReport") }
  }
  @Published var weeklyReport =
    UserDefaults.standard.object(forKey: "weeklyReport") as? Bool ?? true
  {
    didSet { UserDefaults.standard.set(weeklyReport, forKey: "weeklyReport") }
  }
  @Published private(set) var loginEnabled = SMAppService.mainApp.status == .enabled
  private var recorder = UsageRecorder()
  private var timer: Timer?
  private var available = true
  private var dirty = false
  private var lastSave = Date()
  private var storageReady = true
  private var reportsInFlight: Set<String> = []
  private let storeURL: URL

  override init() {
    storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("MacUsageTracker/sessions.json")
    super.init()
    do {
      if FileManager.default.fileExists(atPath: storeURL.path) {
        sessions = try JSONDecoder().decode([UsageSession].self, from: Data(contentsOf: storeURL))
        recorder = UsageRecorder(sessions: sessions)
      }
    } catch {
      storageReady = false
      errorMessage =
        "Could not read saved history. Tracking is stopped to protect it: \(error.localizedDescription)"
    }
    let center = NSWorkspace.shared.notificationCenter
    for event in [
      NSWorkspace.didActivateApplicationNotification, NSWorkspace.didWakeNotification,
      NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification,
    ] {
      center.addObserver(self, selector: #selector(resume(_:)), name: event, object: nil)
    }
    for event in [
      NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
      NSWorkspace.sessionDidResignActiveNotification,
    ] {
      center.addObserver(self, selector: #selector(suspend(_:)), name: event, object: nil)
    }
    NotificationCenter.default.addObserver(
      self, selector: #selector(terminate),
      name: NSApplication.willTerminateNotification, object: nil)
    tick()
    timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.tick() }
    }
    timer?.tolerance = 0.5
  }

  @objc private func resume(_ notification: Notification) {
    if notification.name != NSWorkspace.didActivateApplicationNotification { available = true }
    tick()
  }

  @objc private func suspend(_ notification: Notification) {
    tick()
    available = false
    tick()
    save()
  }

  @objc private func terminate() {
    tick()
    save()
  }

  func setPaused(_ value: Bool) {
    tick()
    paused = value
    tick()
    save()
  }

  private func tick() {
    guard storageReady else {
      status = "Storage unavailable"
      return
    }
    let now = Date()
    let app = NSWorkspace.shared.frontmostApplication
    let idle = CGEventSource.secondsSinceLastEventType(
      .combinedSessionState,
      eventType: CGEventType(rawValue: UInt32.max)!)
    recorder.sample(
      at: now, bundleID: app?.bundleIdentifier, name: app?.localizedName ?? "Unknown app",
      idleSeconds: idle, idleThreshold: idleThreshold, enabled: !paused, available: available)
    sessions = recorder.sessions
    dirty = true
    status =
      paused
      ? "Paused"
      : (!available
        ? "Screen asleep or session inactive"
        : (idle >= idleThreshold ? "Idle" : "Tracking · \(app?.localizedName ?? "Unknown app")"))
    if now.timeIntervalSince(lastSave) >= 30 {
      save()
      checkReports(now: now)
    }
  }

  private func save() {
    guard storageReady, dirty else { return }
    do {
      try FileManager.default.createDirectory(
        at: storeURL.deletingLastPathComponent(),
        withIntermediateDirectories: true)
      try JSONEncoder().encode(sessions).write(to: storeURL, options: .atomic)
      dirty = false
      lastSave = Date()
    } catch { errorMessage = "Could not save history: \(error.localizedDescription)" }
  }

  func export() {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "mac-usage.json"
    panel.allowedContentTypes = [.json]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do { try JSONEncoder().encode(sessions).write(to: url, options: .atomic) } catch {
      errorMessage = "Export failed: \(error.localizedDescription)"
    }
  }

  func deleteMonth(containing date: Date) {
    guard let month = Calendar.current.dateInterval(of: .month, for: date), storageReady else {
      return
    }
    // Preserve portions of sessions outside the deleted month.
    sessions = sessions.flatMap { session -> [UsageSession] in
      guard session.seconds(in: month) > 0 else { return [session] }
      var retained: [UsageSession] = []
      if session.start < month.start {
        retained.append(
          UsageSession(
            bundleID: session.bundleID, name: session.name,
            start: session.start, end: month.start))
      }
      if session.end > month.end {
        retained.append(
          UsageSession(
            bundleID: session.bundleID, name: session.name,
            start: month.end, end: session.end))
      }
      return retained
    }
    recorder.reset(sessions: sessions)
    dirty = true
    save()
  }

  func setLoginEnabled(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      loginEnabled = SMAppService.mainApp.status == .enabled
      if enabled && !loginEnabled {
        errorMessage = "Approve Mac Usage in System Settings → General → Login Items."
      }
    } catch { errorMessage = "Login setting failed: \(error.localizedDescription)" }
  }

  func enableNotifications() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
      granted, error in
      Task { @MainActor in
        if let error {
          self.errorMessage = error.localizedDescription
        } else if !granted {
          self.errorMessage = "Enable notifications for Mac Usage in System Settings."
        }
      }
    }
  }

  private func checkReports(now: Date) {
    let calendar = Calendar.current
    guard calendar.component(.hour, from: now) >= 9 else { return }
    let today = calendar.startOfDay(for: now)
    if dailyReport, let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
      report(
        key: "daily", interval: DateInterval(start: yesterday, end: today),
        title: "Yesterday on your Mac")
    }
    if weeklyReport && calendar.component(.weekday, from: now) == 2 {
      let thisWeek = UsageSummary.week(containing: now)
      if let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek.start) {
        report(
          key: "weekly", interval: DateInterval(start: previous, end: thisWeek.start),
          title: "Last week on your Mac")
      }
    }
  }

  private func report(key: String, interval: DateInterval, title: String) {
    let marker = interval.end.timeIntervalSince1970
    guard UserDefaults.standard.double(forKey: "report.\(key)") != marker else { return }
    guard reportsInFlight.insert(key).inserted else { return }
    Task { @MainActor in
      defer { reportsInFlight.remove(key) }
      let center = UNUserNotificationCenter.current()
      let settings = await center.notificationSettings()
      guard settings.authorizationStatus == .authorized else { return }
      let apps = UsageSummary.apps(sessions, in: interval)
      let content = UNMutableNotificationContent()
      content.title = title
      content.body =
        "\(UsageSummary.duration(apps.reduce(0) { $0 + $1.seconds })) active time. "
        + apps.prefix(3).map { "\($0.name): \(UsageSummary.duration($0.seconds))" }.joined(
          separator: " · ")
      let request = UNNotificationRequest(
        identifier: "\(key)-\(marker)", content: content, trigger: nil)
      do {
        try await center.add(request)
        UserDefaults.standard.set(marker, forKey: "report.\(key)")
      } catch { errorMessage = "Report failed: \(error.localizedDescription)" }
    }
  }
}
