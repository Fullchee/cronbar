import Foundation

/// Plain-words summary of when a launchd job runs, read from its plist.
public enum Schedule {
    public static func words(for plist: [String: Any]) -> String {
        if let calendar = plist["StartCalendarInterval"] {
            return calendarWords(calendar)
        }
        if let interval = plist["StartInterval"] as? Int {
            return intervalWords(seconds: interval)
        }
        if plist["WatchPaths"] != nil || plist["QueueDirectories"] != nil {
            return "on file change"
        }
        // KeepAlive is either a bool or a dict of conditions; any dict keeps the job alive.
        if let keepAlive = plist["KeepAlive"], (keepAlive as? Bool) != false {
            return "always running"
        }
        if plist["RunAtLoad"] as? Bool == true {
            return "at login"
        }
        return "on demand"
    }

    public static func intervalWords(seconds s: Int) -> String {
        switch s {
        case 86400: "every day"
        case let s where s > 0 && s % 86400 == 0: "every \(s / 86400) days"
        case 3600: "every hour"
        case let s where s > 0 && s % 3600 == 0: "every \(s / 3600) h"
        case let s where s > 0 && s % 60 == 0: "every \(s / 60) min"
        default: "every \(s) s"
        }
    }

    static func calendarWords(_ value: Any) -> String {
        guard let entries = value as? [[String: Any]] else {
            return entryWords(value as? [String: Any] ?? [:])
        }
        let words = entries.map(entryWords)
        guard let first = words.first, let last = words.last else { return "on demand" }
        if words.count == 1 { return first }
        let kinds = Set(words.map(kind))
        if kinds.count == 1 {
            return "\(first) … \(last.drop { $0 != " " }.dropFirst()) (\(words.count)×)"
        }
        return "\(words.count) schedules, first: \(first)"
    }

    private static func kind(_ words: String) -> Substring {
        words.prefix { $0 != " " }
    }

    static func entryWords(_ entry: [String: Any]) -> String {
        let minute = entry["Minute"] as? Int
        let hour = entry["Hour"] as? Int
        let day = entry["Day"] as? Int
        let weekday = entry["Weekday"] as? Int
        let month = entry["Month"] as? Int

        let time: String? = switch (hour, minute) {
        case let (h?, m?): String(format: "%02d:%02d", h, m)
        case let (h?, nil): String(format: "each min of %02d:xx", h)
        case let (nil, m?): String(format: ":%02d", m)
        case (nil, nil): nil
        }
        let parts: [String?]
        if let month {
            parts = ["yearly", monthName(month), day.map(String.init), weekday.map(weekdayName), time]
        } else if let day {
            parts = ["monthly day \(day)", weekday.map(weekdayName), time]
        } else if let weekday {
            parts = ["weekly", weekdayName(weekday), time]
        } else if hour != nil {
            parts = ["daily", time]
        } else if minute != nil {
            parts = ["hourly at", time]
        } else {
            parts = ["every minute"]
        }
        return parts.compactMap { $0 }.joined(separator: " ")
    }

    private static func weekdayName(_ n: Int) -> String {
        // launchd accepts both 0 and 7 for Sunday.
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return names.indices.contains(n) ? names[n] : "day\(n)"
    }

    private static func monthName(_ n: Int) -> String {
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return (1...12).contains(n) ? names[n - 1] : "month\(n)"
    }
}
