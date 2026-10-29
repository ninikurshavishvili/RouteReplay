import CoreLocation

extension RoutePoint {
    /// Creates a point from a Core Location location.
    ///
    /// Altitude, speed and course are `nil` when Core Location marks them invalid with a negative value.
    public init(_ location: CLLocation) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.verticalAccuracy >= 0 ? location.altitude : nil,
            horizontalAccuracy: location.horizontalAccuracy,
            speed: location.speed >= 0 ? location.speed : nil,
            course: location.course >= 0 ? location.course : nil,
            timestamp: location.timestamp
        )
    }

    /// Makes a Core Location location from the point. Missing values become Core Location's invalid values.
    ///
    /// - Parameter timestamp: The time to stamp on the location, or `nil` for the point's own time.
    public func makeLocation(timestamp: Date? = nil) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude ?? 0,
            horizontalAccuracy: horizontalAccuracy,
            // The model does not store vertical accuracy, so horizontal accuracy stands in for it.
            verticalAccuracy: altitude == nil ? -1 : horizontalAccuracy,
            course: course ?? -1,
            speed: speed ?? -1,
            timestamp: timestamp ?? self.timestamp
        )
    }
}
