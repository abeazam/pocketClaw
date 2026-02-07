import Foundation

// MARK: - Cron Job

struct CronJob: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let schedule: CronSchedule
    let nextRun: String?
    var status: String  // "active" or "paused"
    let description: String?
    var content: String?

    var isActive: Bool { status == "active" }
}

// MARK: - Cron Schedule

/// Schedule can be a plain string or an object { kind, expr, tz }
enum CronSchedule: Codable, Sendable {
    case simple(String)
    case complex(kind: String, expr: String, tz: String?)

    var expression: String {
        switch self {
        case .simple(let expr): expr
        case .complex(_, let expr, _): expr
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .simple(str)
        } else {
            let obj = try CronScheduleObject.init(from: decoder)
            self = .complex(kind: obj.kind ?? "cron", expr: obj.expr, tz: obj.tz)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .simple(let str):
            try container.encode(str)
        case .complex(let kind, let expr, let tz):
            try container.encode(CronScheduleObject(kind: kind, expr: expr, tz: tz))
        }
    }
}

private struct CronScheduleObject: Codable {
    let kind: String?
    let expr: String
    let tz: String?
}

// MARK: - Preview Data

extension CronJob {
    static let preview = CronJob(
        id: "cron-1",
        name: "Daily backup",
        schedule: .simple("0 2 * * *"),
        nextRun: "2026-02-08T02:00:00Z",
        status: "active",
        description: "Backs up all agent data daily",
        content: nil
    )
}
