import Foundation

// MARK: - Cron Job

struct CronJob: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let schedule: CronSchedule
    let nextRunAtMs: Double?
    var enabled: Bool
    let agentId: String?
    let sessionTarget: String?
    let wakeMode: String?
    let payload: CronPayload?
    let delivery: CronDelivery?
    let createdAtMs: Double?
    let updatedAtMs: Double?

    var isActive: Bool { enabled }

    /// Human-readable next run time
    var nextRunDisplay: String? {
        guard let ms = nextRunAtMs else { return nil }
        let date = Date(timeIntervalSince1970: ms / 1000.0)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// The payload message serves as the cron job's "documentation"
    var content: String? {
        payload?.message
    }

    enum CodingKeys: String, CodingKey {
        case id, name, schedule, enabled, agentId, sessionTarget
        case wakeMode, payload, delivery, createdAtMs, updatedAtMs, state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unnamed Job"
        schedule = try container.decodeIfPresent(CronSchedule.self, forKey: .schedule) ?? .unknown
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        agentId = try container.decodeIfPresent(String.self, forKey: .agentId)
        sessionTarget = try container.decodeIfPresent(String.self, forKey: .sessionTarget)
        wakeMode = try container.decodeIfPresent(String.self, forKey: .wakeMode)
        payload = try container.decodeIfPresent(CronPayload.self, forKey: .payload)
        delivery = try container.decodeIfPresent(CronDelivery.self, forKey: .delivery)
        createdAtMs = try container.decodeIfPresent(Double.self, forKey: .createdAtMs)
        updatedAtMs = try container.decodeIfPresent(Double.self, forKey: .updatedAtMs)

        // nextRunAtMs lives inside state.nextRunAtMs
        if let stateObj = try container.decodeIfPresent(CronState.self, forKey: .state) {
            nextRunAtMs = stateObj.nextRunAtMs
        } else {
            nextRunAtMs = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(schedule, forKey: .schedule)
        try container.encode(enabled, forKey: .enabled)
        try container.encodeIfPresent(agentId, forKey: .agentId)
        try container.encodeIfPresent(sessionTarget, forKey: .sessionTarget)
        try container.encodeIfPresent(wakeMode, forKey: .wakeMode)
        try container.encodeIfPresent(payload, forKey: .payload)
        try container.encodeIfPresent(delivery, forKey: .delivery)
    }

    // Manual init for previews
    init(id: String, name: String, schedule: CronSchedule, nextRunAtMs: Double? = nil,
         enabled: Bool = true, agentId: String? = nil, sessionTarget: String? = nil,
         wakeMode: String? = nil, payload: CronPayload? = nil, delivery: CronDelivery? = nil) {
        self.id = id
        self.name = name
        self.schedule = schedule
        self.nextRunAtMs = nextRunAtMs
        self.enabled = enabled
        self.agentId = agentId
        self.sessionTarget = sessionTarget
        self.wakeMode = wakeMode
        self.payload = payload
        self.delivery = delivery
        self.createdAtMs = nil
        self.updatedAtMs = nil
    }
}

// MARK: - Hashable

extension CronJob: Hashable {
    static func == (lhs: CronJob, rhs: CronJob) -> Bool {
        lhs.id == rhs.id && lhs.enabled == rhs.enabled && lhs.nextRunAtMs == rhs.nextRunAtMs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Cron State

private struct CronState: Codable {
    let nextRunAtMs: Double?
}

// MARK: - Cron Payload

struct CronPayload: Codable, Sendable, Hashable {
    let message: String?
    let kind: String?
}

// MARK: - Cron Delivery

struct CronDelivery: Codable, Sendable, Hashable {
    let channel: String?
    let to: String?
    let mode: String?
}

// MARK: - Cron Schedule

/// Schedule can be:
/// - `{ kind: "cron", expr: "0 * * * *", tz: "Europe/London" }` — cron expression
/// - `{ kind: "every", everyMs: 900000 }` — interval in milliseconds
/// - a plain string
enum CronSchedule: Codable, Sendable, Hashable {
    case cron(expr: String, tz: String?)
    case every(ms: Double)
    case unknown

    var displayExpression: String {
        switch self {
        case .cron(let expr, _): expr
        case .every(let ms): formatInterval(ms)
        case .unknown: "N/A"
        }
    }

    var timezone: String? {
        switch self {
        case .cron(_, let tz): tz
        case .every, .unknown: nil
        }
    }

    var kindLabel: String {
        switch self {
        case .cron: "cron"
        case .every: "interval"
        case .unknown: "unknown"
        }
    }

    /// Human-readable description of the schedule
    var humanReadable: String {
        switch self {
        case .cron(let expr, _):
            CronExpressionParser.describe(expr)
        case .every(let ms):
            formatInterval(ms)
        case .unknown:
            "Unknown schedule"
        }
    }

    private func formatInterval(_ ms: Double) -> String {
        let seconds = ms / 1000.0
        if seconds < 60 {
            return "Every \(Int(seconds))s"
        } else if seconds < 3600 {
            let mins = Int(seconds / 60)
            return "Every \(mins)m"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            let mins = Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)
            return mins > 0 ? "Every \(hours)h \(mins)m" : "Every \(hours)h"
        } else {
            let days = Int(seconds / 86400)
            return "Every \(days)d"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            // Plain string — treat as cron expression
            self = .cron(expr: str, tz: nil)
        } else {
            let obj = try CronScheduleObject(from: decoder)
            if obj.kind == "every", let ms = obj.everyMs {
                self = .every(ms: ms)
            } else if let expr = obj.expr {
                self = .cron(expr: expr, tz: obj.tz)
            } else {
                self = .unknown
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .cron(let expr, let tz):
            try container.encode(CronScheduleObject(kind: "cron", expr: expr, tz: tz, everyMs: nil))
        case .every(let ms):
            try container.encode(CronScheduleObject(kind: "every", expr: nil, tz: nil, everyMs: ms))
        case .unknown:
            try container.encode("N/A")
        }
    }
}

private struct CronScheduleObject: Codable {
    let kind: String?
    let expr: String?
    let tz: String?
    let everyMs: Double?
}

// MARK: - Cron Expression Parser

/// Parses standard 5-field cron expressions into human-readable descriptions.
/// Fields: minute hour day-of-month month day-of-week
enum CronExpressionParser {
    private static let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let monthNames = [
        "", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]

    static func describe(_ expr: String) -> String {
        let fields = expr.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
        guard fields.count >= 5 else { return expr }

        let minute = fields[0]
        let hour = fields[1]
        let dom = fields[2]
        let month = fields[3]
        let dow = fields[4]

        var parts: [String] = []

        // Time description
        parts.append(describeTime(minute: minute, hour: hour))

        // Day-of-week
        if dow != "*" {
            parts.append(describeDow(dow))
        }

        // Day-of-month
        if dom != "*" {
            parts.append("on day \(dom) of the month")
        }

        // Month
        if month != "*" {
            parts.append("in \(describeMonth(month))")
        }

        return parts.joined(separator: ", ")
    }

    private static func describeTime(minute: String, hour: String) -> String {
        // Every minute
        if minute == "*" && hour == "*" {
            return "Every minute"
        }

        // Step patterns: */5 = every 5 minutes
        if minute.hasPrefix("*/"), hour == "*" {
            let step = String(minute.dropFirst(2))
            return "Every \(step) minutes"
        }

        if minute == "0" && hour.hasPrefix("*/") {
            let step = String(hour.dropFirst(2))
            return step == "1" ? "Every hour" : "Every \(step) hours"
        }

        // Specific minute, every hour
        if hour == "*" {
            return "At minute \(minute) of every hour"
        }

        // Every minute during specific hours
        if minute == "*" {
            return "Every minute during \(describeHours(hour))"
        }

        // Specific time(s)
        let minutes = expandField(minute)
        let hours = expandField(hour)

        if hours.count == 1 && minutes.count == 1 {
            return "At \(formatTime(hours[0], minutes[0]))"
        }

        if hours.count == 1 {
            let minStr = minutes.map { String(format: ":%02d", $0) }.joined(separator: " and ")
            return "At \(formatHour(hours[0]))\(minStr)"
        }

        if minutes.count == 1 {
            let hourStr = describeHours(hour)
            return "At \(String(format: ":%02d", minutes[0])) during \(hourStr)"
        }

        // Multiple hours and minutes — build time windows
        let minStr = minutes.map { String(format: ":%02d", $0) }.joined(separator: " and ")
        let hourStr = describeHours(hour)
        return "At \(minStr) past \(hourStr)"
    }

    private static func describeHours(_ field: String) -> String {
        let hours = expandField(field)
        if hours.count <= 3 {
            return hours.map { formatHour($0) }.joined(separator: ", ")
        }
        // Check if consecutive range
        if let first = hours.first, let last = hours.last,
           hours.count == (last - first + 1) {
            return "\(formatHour(first))–\(formatHour(last))"
        }
        return hours.map { formatHour($0) }.joined(separator: ", ")
    }

    private static func describeDow(_ field: String) -> String {
        let days = expandField(field, max: 6)
        if days.count == 5 && !days.contains(0) && !days.contains(6) {
            return "on weekdays"
        }
        if days.count == 2 && days.contains(0) && days.contains(6) {
            return "on weekends"
        }
        let names = days.compactMap { $0 < dayNames.count ? dayNames[$0] : nil }
        if names.count <= 3 {
            return "on \(names.joined(separator: ", "))"
        }
        return "on \(names.dropLast().joined(separator: ", ")) and \(names.last ?? "")"
    }

    private static func describeMonth(_ field: String) -> String {
        let months = expandField(field)
        let names = months.compactMap { $0 < monthNames.count ? monthNames[$0] : nil }
        return names.joined(separator: ", ")
    }

    // MARK: - Helpers

    /// Expand a cron field like "1,3,5" or "19-22" or "*/5" into sorted integer array
    private static func expandField(_ field: String, max: Int = 59) -> [Int] {
        var result = Set<Int>()
        let parts = field.split(separator: ",").map(String.init)
        for part in parts {
            if part.contains("/") {
                let sub = part.split(separator: "/").map(String.init)
                let step = Int(sub.last ?? "1") ?? 1
                let start: Int
                if sub.first == "*" {
                    start = 0
                } else if sub.first?.contains("-") == true {
                    let range = sub.first!.split(separator: "-").compactMap { Int($0) }
                    if range.count == 2 {
                        var i = range[0]
                        while i <= range[1] {
                            result.insert(i)
                            i += step
                        }
                        continue
                    }
                    start = 0
                } else {
                    start = Int(sub.first ?? "0") ?? 0
                }
                var i = start
                while i <= max {
                    result.insert(i)
                    i += step
                }
            } else if part.contains("-") {
                let range = part.split(separator: "-").compactMap { Int($0) }
                if range.count == 2 {
                    for i in range[0]...range[1] { result.insert(i) }
                }
            } else if let n = Int(part) {
                result.insert(n)
            }
        }
        return result.sorted()
    }

    private static func formatTime(_ hour: Int, _ minute: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", h, minute, ampm)
    }

    private static func formatHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h) \(ampm)"
    }
}

// MARK: - Preview Data

extension CronJob {
    static let preview = CronJob(
        id: "daily-backup",
        name: "Daily backup",
        schedule: .cron(expr: "0 2 * * *", tz: "Europe/London"),
        nextRunAtMs: Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000,
        enabled: true,
        agentId: "main",
        payload: CronPayload(
            message: "Run the daily backup script and report results.",
            kind: "agentTurn"
        )
    )

    static let previewList: [CronJob] = [
        CronJob(id: "daily-backup", name: "Daily backup",
                schedule: .cron(expr: "0 2 * * *", tz: "Europe/London"),
                nextRunAtMs: Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000,
                enabled: true, agentId: "main",
                payload: CronPayload(message: "Run the daily backup.", kind: "agentTurn")),
        CronJob(id: "health-check", name: "Hourly health check",
                schedule: .every(ms: 900000),
                nextRunAtMs: Date().addingTimeInterval(600).timeIntervalSince1970 * 1000,
                enabled: true),
        CronJob(id: "weekly-report", name: "Weekly report",
                schedule: .cron(expr: "0 9 * * 1", tz: nil),
                enabled: false,
                payload: CronPayload(message: "Generate the weekly summary report.", kind: "agentTurn"))
    ]
}
