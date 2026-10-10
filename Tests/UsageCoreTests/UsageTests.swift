import Foundation
import XCTest

@testable import UsageCore

final class UsageTests: XCTestCase {
  private let origin = Date(timeIntervalSince1970: 0)

  private func sample(
    _ recorder: inout UsageRecorder, _ seconds: Double, app: String = "a",
    idle: Double = 0, enabled: Bool = true, available: Bool = true
  ) {
    recorder.sample(
      at: origin.addingTimeInterval(seconds), bundleID: app, name: app,
      idleSeconds: idle, idleThreshold: 120, enabled: enabled, available: available)
  }

  func testContinuousUsageMergesAndSwitchStartsNewSession() {
    var recorder = UsageRecorder()
    sample(&recorder, 0)
    sample(&recorder, 5)
    sample(&recorder, 10, app: "b")
    sample(&recorder, 15, app: "b")
    XCTAssertEqual(recorder.sessions.count, 2)
    XCTAssertEqual(recorder.sessions[0].end.timeIntervalSince(origin), 10)
    XCTAssertEqual(recorder.sessions[1].bundleID, "b")
    XCTAssertEqual(recorder.sessions[1].end.timeIntervalSince(recorder.sessions[1].start), 5)
  }

  func testIdleBoundaryClipsAndReturnStartsSeparateSession() {
    var recorder = UsageRecorder()
    sample(&recorder, 0, idle: 118)
    sample(&recorder, 5, idle: 123)
    sample(&recorder, 10, idle: 128)
    sample(&recorder, 15, idle: 0)
    sample(&recorder, 20, idle: 0)
    XCTAssertEqual(recorder.sessions.count, 2)
    XCTAssertEqual(recorder.sessions[0].end.timeIntervalSince(origin), 2)
    XCTAssertEqual(recorder.sessions[1].start.timeIntervalSince(origin), 15)
  }

  func testLongGapDoesNotAccrueSleepTime() {
    var recorder = UsageRecorder()
    sample(&recorder, 0)
    sample(&recorder, 5)
    sample(&recorder, 3600)
    sample(&recorder, 3605)
    XCTAssertEqual(recorder.sessions.count, 2)
    XCTAssertEqual(recorder.sessions.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }, 10)
  }

  func testPauseAndInactiveSessionExcludeTime() {
    var recorder = UsageRecorder()
    sample(&recorder, 0)
    sample(&recorder, 5)
    sample(&recorder, 5, enabled: false)
    sample(&recorder, 10, enabled: false)
    sample(&recorder, 15, available: false)
    sample(&recorder, 20)
    sample(&recorder, 25)
    XCTAssertEqual(recorder.sessions.count, 2)
    XCTAssertEqual(recorder.sessions.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }, 10)
  }

  func testMissingAppAndClockGoingBackwardDoNotProduceNegativeTime() {
    var recorder = UsageRecorder()
    sample(&recorder, 10)
    sample(&recorder, 5)
    recorder.sample(
      at: origin.addingTimeInterval(8), bundleID: nil, name: "",
      idleSeconds: 0, idleThreshold: 120, enabled: true, available: true)
    XCTAssertTrue(recorder.sessions.allSatisfy { $0.end > $0.start })
  }

  func testCalendarBoundarySplitsDurationWithoutDuplicatingOpens() {
    let session = UsageSession(
      bundleID: "a", name: "A", start: origin.addingTimeInterval(-10),
      end: origin.addingTimeInterval(10))
    let before = UsageSummary.apps(
      [session], in: DateInterval(start: origin.addingTimeInterval(-100), end: origin))
    let after = UsageSummary.apps(
      [session], in: DateInterval(start: origin, end: origin.addingTimeInterval(100)))
    XCTAssertEqual(before[0].seconds, 10)
    XCTAssertEqual(after[0].seconds, 10)
    XCTAssertEqual(before[0].opens, 1)
    XCTAssertEqual(after[0].opens, 0)
  }

  func testMondayWeekAndDSTUseCalendarDays() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let sunday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))!
    let week = UsageSummary.week(containing: sunday, calendar: calendar)
    XCTAssertEqual(calendar.component(.weekday, from: week.start), 2)
    XCTAssertEqual(calendar.component(.day, from: week.start), 2)
    XCTAssertEqual(week.duration, 167 * 3600)
  }

  func testSerializationRoundTripPreservesHistory() throws {
    let sessions = [
      UsageSession(bundleID: "a", name: "A", start: origin, end: origin.addingTimeInterval(5))
    ]
    XCTAssertEqual(
      try JSONDecoder().decode([UsageSession].self, from: JSONEncoder().encode(sessions)), sessions)
  }
}
