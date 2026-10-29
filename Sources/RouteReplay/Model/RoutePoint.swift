import Foundation

/// One recorded location: a position plus the moment it was measured.
///
/// The timestamps are what make replay realistic — the gap between two points
/// decides how long the replay waits before sending the next one.
public struct RoutePoint: Codable, Sendable, Equatable, Hashable {
    /// Latitude in degrees.
    public let latitude: Double
    /// Longitude in degrees.
    public let longitude: Double
    /// Altitude in meters, or `nil` if it was not measured.
    public let altitude: Double?
    /// Radius of uncertainty for the position, in meters.
    public let horizontalAccuracy: Double
    /// Speed in meters per second, or `nil` if it was not measured.
    public let speed: Double?
    /// Direction of travel in degrees, where 0 is north, or `nil` if it was not measured.
    public let course: Double?
    /// When the location was measured.
    public let timestamp: Date

    /// Creates a point. Leave out the values that weren't measured.
    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        horizontalAccuracy: Double,
        speed: Double? = nil,
        course: Double? = nil,
        timestamp: Date
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
        self.course = course
        self.timestamp = timestamp
    }
}
