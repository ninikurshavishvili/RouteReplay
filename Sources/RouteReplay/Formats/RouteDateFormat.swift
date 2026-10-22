import Foundation

/// The date format shared by every route file format: ISO 8601 in UTC.
///
/// Dates are written with milliseconds, because whole seconds would make replay gaps uneven,
/// and read with or without them, because hand-written files usually have none.
enum RouteDateFormat {
    private static let fractionalSeconds = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let wholeSeconds = Date.ISO8601FormatStyle()

    static func string(from date: Date) -> String {
        date.formatted(fractionalSeconds)
    }

    static func date(from string: String) -> Date? {
        if let date = try? fractionalSeconds.parse(string) { return date }
        return try? wholeSeconds.parse(string)
    }
}
