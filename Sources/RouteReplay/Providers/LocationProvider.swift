import CoreLocation


public protocol LocationProvider: Sendable {

    func locations() -> AsyncStream<CLLocation>
}
