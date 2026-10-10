import AppKit
import Charts
import SwiftUI
import UsageCore

@main
struct MacUsageApp: App {
  @StateObject private var tracker = Tracker()

  var body: some Scene {
    WindowGroup("Mac Usage", id: "dashboard") {
      Dashboard(tracker: tracker)
        .frame(minWidth: 780, minHeight: 580)
    }
    .defaultSize(width: 920, height: 700)
    MenuBarExtra("Mac Usage", systemImage: "chart.bar.xaxis") {
      MenuContent(tracker: tracker)
    }
    Settings { TrackerSettings(tracker: tracker).frame(width: 420).padding(24) }
  }
}

private struct MenuContent: View {
  @ObservedObject var tracker: Tracker
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Text(tracker.status)
    Button("Open dashboard") {
      openWindow(id: "dashboard")
      NSApp.activate(ignoringOtherApps: true)
    }
    Button(tracker.paused ? "Resume tracking" : "Pause tracking") {
      tracker.setPaused(!tracker.paused)
    }
    Divider()
    Button("Quit Mac Usage") { NSApp.terminate(nil) }
  }
}

private enum Period: String, CaseIterable {
  case today = "Today"
  case thisWeek = "This week"
  case lastWeek = "Last week"
  case history = "History"
}

private struct DayUsage: Identifiable {
  let date: Date
  let seconds: Double
  var id: Date { date }
}

private final class DashboardState: ObservableObject {
  @Published var period = Period.thisWeek
  @Published var historyDate = Date()
  @Published var confirmDelete = false
}

private struct Dashboard: View {
  @ObservedObject var tracker: Tracker
  @StateObject private var state = DashboardState()

  private var interval: DateInterval {
    let calendar = Calendar.current
    switch state.period {
    case .today: return calendar.dateInterval(of: .day, for: Date())!
    case .thisWeek: return UsageSummary.week(containing: Date())
    case .lastWeek:
      return UsageSummary.week(
        containing: calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!)
    case .history: return calendar.dateInterval(of: .month, for: state.historyDate)!
    }
  }
  private var apps: [AppUsage] { UsageSummary.apps(tracker.sessions, in: interval) }
  private var total: Double { apps.reduce(0) { $0 + $1.seconds } }
  private var days: [DayUsage] {
    var date = interval.start
    var result: [DayUsage] = []
    while date < interval.end {
      let end = Calendar.current.date(byAdding: .day, value: 1, to: date)!
      let day = DateInterval(start: date, end: min(end, interval.end))
      result.append(
        DayUsage(date: date, seconds: tracker.sessions.reduce(0) { $0 + $1.seconds(in: day) }))
      date = end
    }
    return result
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        HStack {
          VStack(alignment: .leading, spacing: 6) {
            Text("Your time, in focus.").font(.largeTitle.bold())
            Label(tracker.status, systemImage: tracker.paused ? "pause.circle" : "circle.fill")
              .foregroundStyle(.secondary)
          }
          Spacer()
          Button(tracker.paused ? "Resume" : "Pause") { tracker.setPaused(!tracker.paused) }
          Button {
            tracker.export()
          } label: {
            Label("Export", systemImage: "square.and.arrow.up")
          }
        }
        Picker("Period", selection: $state.period) {
          ForEach(Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented)
        if state.period == .history {
          HStack {
            DatePicker(
              "Month containing", selection: $state.historyDate, displayedComponents: .date)
            Spacer()
            Button("Delete this month", role: .destructive) { state.confirmDelete = true }
          }
        }
        HStack(spacing: 32) {
          metric("Active time", UsageSummary.duration(total))
          metric("Apps used", "\(apps.count)")
          metric("Sessions started", "\(apps.reduce(0) { $0 + $1.opens })")
        }
        Chart(days) { day in
          BarMark(x: .value("Day", day.date, unit: .day), y: .value("Hours", day.seconds / 3600))
            .foregroundStyle(Color.accentColor.gradient)
            .cornerRadius(4)
        }
        .chartXAxis {
          AxisMarks(values: .stride(by: .day, count: state.period == .history ? 5 : 1)) {
            AxisValueLabel(format: .dateTime.weekday(.abbreviated).day())
          }
        }
        .chartYAxisLabel("Active hours")
        .frame(height: 190)
        Text("Applications").font(.title2.bold())
        if apps.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("No activity recorded for this period.").font(.headline)
            Text("Keep Mac Usage running in the menu bar. History starts when tracking begins.")
              .foregroundStyle(.secondary)
          }.padding(.vertical, 20)
        }
        ForEach(apps) { app in
          HStack(spacing: 14) {
            AppIcon(bundleID: app.bundleID)
            VStack(alignment: .leading, spacing: 5) {
              Text(app.name).font(.headline)
              ProgressView(value: app.seconds, total: max(total, 1)).tint(.accentColor)
            }
            Spacer(minLength: 24)
            VStack(alignment: .trailing, spacing: 5) {
              Text(UsageSummary.duration(app.seconds)).monospacedDigit()
              Text("\(app.opens) sessions").font(.caption).foregroundStyle(.secondary)
            }
          }.padding(.vertical, 5)
        }
        Text("Local history · Monday–Sunday weeks · Idle time excluded")
          .font(.caption).foregroundStyle(.secondary)
      }.padding(32)
    }
    .alert("Delete this month's history?", isPresented: $state.confirmDelete) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) { tracker.deleteMonth(containing: state.historyDate) }
    } message: {
      Text(
        "\(state.historyDate.formatted(.dateTime.month(.wide).year())) will be removed permanently. Export first to keep a copy."
      )
    }
    .alert(
      "Mac Usage",
      isPresented: Binding(
        get: { tracker.errorMessage != nil },
        set: { if !$0 { tracker.errorMessage = nil } })
    ) {
      Button("OK") { tracker.errorMessage = nil }
    } message: {
      Text(tracker.errorMessage ?? "")
    }
  }

  private func metric(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.subheadline).foregroundStyle(.secondary)
      Text(value).font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit()
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct AppIcon: View {
  let bundleID: String
  var body: some View {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
      Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(
        width: 36, height: 36)
    } else {
      Image(systemName: "app.fill").font(.system(size: 30)).frame(width: 36, height: 36)
    }
  }
}

private struct TrackerSettings: View {
  @ObservedObject var tracker: Tracker
  var body: some View {
    Form {
      Toggle(
        "Launch at login",
        isOn: Binding(get: { tracker.loginEnabled }, set: tracker.setLoginEnabled))
      Picker("Stop counting after", selection: $tracker.idleThreshold) {
        Text("1 minute idle").tag(60.0)
        Text("2 minutes idle").tag(120.0)
        Text("5 minutes idle").tag(300.0)
      }
      Divider()
      Toggle("Weekly summary · Monday after 09:00", isOn: $tracker.weeklyReport)
      Toggle("Daily summary · after 09:00", isOn: $tracker.dailyReport)
      Button("Allow report notifications") { tracker.enableNotifications() }
      Text(
        "Reports are delivered while Mac Usage is running and the Mac is awake. Daily reports cover yesterday; weekly reports cover the previous Monday–Sunday."
      )
      .font(.caption).foregroundStyle(.secondary)
      Divider()
      Text(
        "Only app names, bundle identifiers, and usage timestamps are saved on this Mac. No window titles, websites, typed text, or app content are collected."
      )
      .font(.caption).foregroundStyle(.secondary)
    }
  }
}
