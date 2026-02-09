import Testing
import Foundation
@testable import PocketClaw

// MARK: - Cron Expression Parser Tests

@Suite("CronExpressionParser")
struct CronExpressionParserTests {

    // MARK: - Simple Patterns

    @Test("Every minute: * * * * *")
    func everyMinute() {
        let result = CronExpressionParser.describe("* * * * *")
        #expect(result == "Every minute")
    }

    @Test("Every 5 minutes: */5 * * * *")
    func everyFiveMinutes() {
        let result = CronExpressionParser.describe("*/5 * * * *")
        #expect(result == "Every 5 minutes")
    }

    @Test("Every 15 minutes: */15 * * * *")
    func everyFifteenMinutes() {
        let result = CronExpressionParser.describe("*/15 * * * *")
        #expect(result == "Every 15 minutes")
    }

    @Test("Every hour: 0 */1 * * *")
    func everyHour() {
        let result = CronExpressionParser.describe("0 */1 * * *")
        #expect(result == "Every hour")
    }

    @Test("Every 2 hours: 0 */2 * * *")
    func everyTwoHours() {
        let result = CronExpressionParser.describe("0 */2 * * *")
        #expect(result == "Every 2 hours")
    }

    // MARK: - Specific Times

    @Test("Daily at 2:00 AM: 0 2 * * *")
    func dailyAt2AM() {
        let result = CronExpressionParser.describe("0 2 * * *")
        #expect(result == "At 2:00 AM")
    }

    @Test("Daily at noon: 0 12 * * *")
    func dailyAtNoon() {
        let result = CronExpressionParser.describe("0 12 * * *")
        #expect(result == "At 12:00 PM")
    }

    @Test("Daily at midnight: 0 0 * * *")
    func dailyAtMidnight() {
        let result = CronExpressionParser.describe("0 0 * * *")
        #expect(result == "At 12:00 AM")
    }

    @Test("At 9:30 AM: 30 9 * * *")
    func at930AM() {
        let result = CronExpressionParser.describe("30 9 * * *")
        #expect(result == "At 9:30 AM")
    }

    // MARK: - Day of Week

    @Test("Weekdays only: 0 9 * * 1-5")
    func weekdays() {
        let result = CronExpressionParser.describe("0 9 * * 1-5")
        #expect(result == "At 9:00 AM, on weekdays")
    }

    @Test("Weekends: 0 10 * * 0,6")
    func weekends() {
        let result = CronExpressionParser.describe("0 10 * * 0,6")
        #expect(result == "At 10:00 AM, on weekends")
    }

    @Test("Monday only: 0 9 * * 1")
    func mondayOnly() {
        let result = CronExpressionParser.describe("0 9 * * 1")
        #expect(result == "At 9:00 AM, on Mon")
    }

    @Test("Mon, Wed, Fri: 0 8 * * 1,3,5")
    func monWedFri() {
        let result = CronExpressionParser.describe("0 8 * * 1,3,5")
        #expect(result == "At 8:00 AM, on Mon, Wed, Fri")
    }

    // MARK: - Day of Month

    @Test("First of month at midnight: 0 0 1 * *")
    func firstOfMonth() {
        let result = CronExpressionParser.describe("0 0 1 * *")
        #expect(result == "At 12:00 AM, on day 1 of the month")
    }

    @Test("15th of month at 3 PM: 0 15 15 * *")
    func fifteenthAt3PM() {
        let result = CronExpressionParser.describe("0 15 15 * *")
        #expect(result == "At 3:00 PM, on day 15 of the month")
    }

    // MARK: - Month

    @Test("January only: 0 0 1 1 *")
    func januaryOnly() {
        let result = CronExpressionParser.describe("0 0 1 1 *")
        #expect(result == "At 12:00 AM, on day 1 of the month, in Jan")
    }

    // MARK: - Multiple Minutes/Hours

    @Test("Multiple hours: 30 19,20,21,22 * * *")
    func multipleHours() {
        let result = CronExpressionParser.describe("30 19,20,21,22 * * *")
        // 19-22 is a consecutive range
        #expect(result.contains(":30"))
    }

    @Test("Specific minute, every hour: 45 * * * *")
    func minuteEveryHour() {
        let result = CronExpressionParser.describe("45 * * * *")
        #expect(result == "At minute 45 of every hour")
    }

    // MARK: - Edge Cases

    @Test("Returns raw expression for invalid input")
    func invalidExpression() {
        let result = CronExpressionParser.describe("bad")
        #expect(result == "bad")
    }

    @Test("Returns raw expression for too few fields")
    func tooFewFields() {
        let result = CronExpressionParser.describe("* *")
        #expect(result == "* *")
    }

    @Test("Handles extra whitespace")
    func extraWhitespace() {
        let result = CronExpressionParser.describe("  0  2  *  *  *  ")
        #expect(result == "At 2:00 AM")
    }
}

// MARK: - CronSchedule Display Tests

@Suite("CronSchedule Display")
struct CronScheduleDisplayTests {
    @Test("Every interval formats seconds")
    func intervalSeconds() {
        let schedule = CronSchedule.every(ms: 30000)
        #expect(schedule.displayExpression == "Every 30s")
    }

    @Test("Every interval formats minutes")
    func intervalMinutes() {
        let schedule = CronSchedule.every(ms: 300000)
        #expect(schedule.displayExpression == "Every 5m")
    }

    @Test("Every interval formats hours")
    func intervalHours() {
        let schedule = CronSchedule.every(ms: 7200000)
        #expect(schedule.displayExpression == "Every 2h")
    }

    @Test("Every interval formats hours and minutes")
    func intervalHoursMinutes() {
        let schedule = CronSchedule.every(ms: 5400000)
        #expect(schedule.displayExpression == "Every 1h 30m")
    }

    @Test("Every interval formats days")
    func intervalDays() {
        let schedule = CronSchedule.every(ms: 86400000)
        #expect(schedule.displayExpression == "Every 1d")
    }

    @Test("Unknown shows N/A")
    func unknownNA() {
        let schedule = CronSchedule.unknown
        #expect(schedule.displayExpression == "N/A")
    }

    @Test("Cron shows expression")
    func cronExpression() {
        let schedule = CronSchedule.cron(expr: "0 2 * * *", tz: "UTC")
        #expect(schedule.displayExpression == "0 2 * * *")
        #expect(schedule.timezone == "UTC")
    }

    @Test("Kind labels")
    func kindLabels() {
        #expect(CronSchedule.cron(expr: "0 * * * *", tz: nil).kindLabel == "cron")
        #expect(CronSchedule.every(ms: 1000).kindLabel == "interval")
        #expect(CronSchedule.unknown.kindLabel == "unknown")
    }

    @Test("Human readable for every schedule")
    func humanReadableEvery() {
        let schedule = CronSchedule.every(ms: 900000)
        #expect(schedule.humanReadable == "Every 15m")
    }

    @Test("Human readable for cron schedule")
    func humanReadableCron() {
        let schedule = CronSchedule.cron(expr: "0 2 * * *", tz: nil)
        #expect(schedule.humanReadable == "At 2:00 AM")
    }
}
