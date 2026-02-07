import Foundation

// MARK: - Date Formatting

extension String {
    /// Parse an ISO 8601 date string to a Date
    var isoDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: self) { return date }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: self)
    }

    /// Format an ISO 8601 date string as relative time (e.g., "2h", "3d")
    var relativeFormatted: String {
        guard let date = isoDate else { return "" }
        return date.relativeFormatted
    }

    /// Format an ISO 8601 date string as a time (e.g., "10:30")
    var timeFormatted: String {
        guard let date = isoDate else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    /// Format an ISO 8601 date string as a date header (e.g., "January 7, 2026")
    var dateHeaderFormatted: String {
        guard let date = isoDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

extension Date {
    /// Relative time display (e.g., "2m", "3h", "1d", "2w")
    var relativeFormatted: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d"
        } else {
            let weeks = Int(interval / 604800)
            return "\(weeks)w"
        }
    }
}
