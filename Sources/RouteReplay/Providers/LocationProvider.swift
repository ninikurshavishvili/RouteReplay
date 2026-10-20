import CoreLocation

/// A source of locations.
///
/// Apps read locations through this protocol and never know whether they are real or replayed:
/// give them a ``LiveLocationProvider`` in production and a replay in previews and tests.
public protocol LocationProvider: Sendable {
    /// Returns a new stream of locations.
    ///
    /// Each call starts an independent stream. Cancelling the task that iterates it,
    /// or discarding the stream, stops the underlying updates.
    func locations() -> AsyncStream<CLLocation>
}
