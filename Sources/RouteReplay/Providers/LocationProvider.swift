import CoreLocation

/// A source of locations: real GPS in production, a replay everywhere else.
///
/// Write location features against this protocol instead of Core Location. Then pass a
/// ``LiveLocationProvider`` in the app and a ``ReplayLocationProvider`` in the simulator,
/// previews and tests.
public protocol LocationProvider: Sendable {
    /// Returns a stream of locations.
    ///
    /// When the consumer stops iterating, the provider stops sending.
    func locations() -> AsyncStream<CLLocation>
}
