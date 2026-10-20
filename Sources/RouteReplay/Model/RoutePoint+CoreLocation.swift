import CoreLocation

extension RoutePoint {

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
