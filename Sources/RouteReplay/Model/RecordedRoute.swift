import Foundation

/// A route recorded from real GPS: an ordered list of points with a name.
public struct RecordedRoute: Codable, Sendable, Equatable {
    /// A human-readable name, such as "Rustaveli walk".
    public let name: String
    /// When the recording started.
    public let recordedAt: Date
    /// The recorded points, in the order they were measured.
    public let points: [RoutePoint]

    public init(name: String, recordedAt: Date, points: [RoutePoint]) {
        self.name = name
        self.recordedAt = recordedAt
        self.points = points
    }
}
