import Foundation

public struct UsageSession: Codable, Equatable, Identifiable {
  public let id: UUID
  public let bundleID: String
  public let name: String
  public let start: Date
  public var end: Date

  public init(bundleID: String, name: String, start: Date, end: Date) {
    self.id = UUID()
    self.bundleID = bundleID
    self.name = name
    self.start = start
    self.end = end
  }

  public func seconds(in interval: DateInterval) -> TimeInterval {
    max(0, min(end, interval.end).timeIntervalSince(max(start, interval.start)))
  }
}

public struct AppUsage: Identifiable {
  public var id: String { bundleID }
  public let bundleID: String
  public let name: String
  public let seconds: TimeInterval
  public let opens: Int
}

public enum UsageSummary {
  public static func apps(_ sessions: [UsageSession], in interval: DateInterval) -> [AppUsage] {
    let groups = Dictionary(
      grouping: sessions.filter { $0.seconds(in: interval) > 0 }, by: \.bundleID)
    return groups.map { id, entries in
      AppUsage(
        bundleID: id, name: entries.last?.name ?? id,
        seconds: entries.reduce(0) { $0 + $1.seconds(in: interval) },
        opens: entries.filter { $0.start >= interval.start && $0.start < interval.end }.count)
    }.sorted { $0.seconds == $1.seconds ? $0.bundleID < $1.bundleID : $0.seconds > $1.seconds }
  }

  public static func week(containing date: Date, calendar: Calendar = .current) -> DateInterval {
    var monday = calendar
    monday.firstWeekday = 2
    monday.minimumDaysInFirstWeek = 4
    return monday.dateInterval(of: .weekOfYear, for: date)!
  }

  public static func duration(_ seconds: TimeInterval) -> String {
    let minutes = max(0, Int(seconds / 60))
    return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
  }
}

/// Accrues the previous foreground app, capped at the idle boundary.
/// Gaps longer than two polling periods are discarded, never backfilled.
public struct UsageRecorder {
  public private(set) var sessions: [UsageSession]
  private var previousDate: Date?
  private var previousApp: (id: String, name: String)?
  private var previousActive = false
  private var canMerge = false

  public init(sessions: [UsageSession] = []) { self.sessions = sessions }

  public mutating func sample(
    at now: Date, bundleID: String?, name: String,
    idleSeconds: TimeInterval, idleThreshold: TimeInterval,
    enabled: Bool, available: Bool
  ) {
    let active = enabled && available && idleSeconds < idleThreshold && bundleID != nil
    if let start = previousDate, let app = previousApp, previousActive {
      let gap = now.timeIntervalSince(start)
      if gap > 0 && gap <= 12 && enabled && available {
        let end = min(now, now.addingTimeInterval(idleThreshold - max(0, idleSeconds)))
        if end > start {
          if canMerge, let last = sessions.last, last.bundleID == app.id,
            abs(last.end.timeIntervalSince(start)) < 0.01
          {
            sessions[sessions.count - 1].end = end
          } else {
            sessions.append(UsageSession(bundleID: app.id, name: app.name, start: start, end: end))
          }
        }
      } else {
        canMerge = false
      }
    }
    canMerge = active && previousActive && previousApp?.id == bundleID
    previousDate = now
    previousApp = bundleID.map { ($0, name) }
    previousActive = active
  }

  public mutating func reset(sessions: [UsageSession]) {
    self = UsageRecorder(sessions: sessions)
  }
}
