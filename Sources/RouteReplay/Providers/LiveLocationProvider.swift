import CoreLocation

/// A ``LocationProvider`` that streams real GPS locations from Core Location.
///
/// It wraps `CLLocationUpdate.liveUpdates(_:)`. The app using it must add
/// `NSLocationWhenInUseUsageDescription` to its Info.plist and request When In Use
/// authorization, for example with `CLLocationManager().requestWhenInUseAuthorization()`.
///
/// Updates that carry no location, such as authorization status updates, are skipped.
public struct LiveLocationProvider: LocationProvider {
    // `LiveConfiguration` is an enum without payloads, so sharing it across tasks is safe,
    // but Core Location does not mark it `Sendable`.
    private nonisolated(unsafe) let configuration: CLLocationUpdate.LiveConfiguration

    /// - Parameter configuration: The kind of activity the updates are tuned for.
    public init(configuration: CLLocationUpdate.LiveConfiguration = .default) {
        self.configuration = configuration
    }

    public func locations() -> AsyncStream<CLLocation> {
        Self.locations(from: CLLocationUpdate.liveUpdates(configuration)) { $0.location }
    }

    /// Bridges a sequence of updates into a location stream.
    ///
    /// Separate from Core Location so tests can drive it with a fake sequence.
    static func locations<Updates: AsyncSequence & Sendable>(
        from updates: Updates,
        location: @escaping @Sendable (Updates.Element) -> CLLocation?
    ) -> AsyncStream<CLLocation> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    for try await update in updates {
                        if let location = location(update) {
                            continuation.yield(location)
                        }
                    }
                } catch {
                    // The updates ended with an error; finishing the stream tells the consumer.
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
