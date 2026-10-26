import CoreLocation

/// Records a route from a ``LocationProvider``, such as real GPS from ``LiveLocationProvider``.
///
/// A location is kept as a ``RoutePoint`` only when its horizontal accuracy is valid and no worse
/// than ``maximumAccuracy``, and it is at least ``minimumDistance`` from the last kept point.
/// That drops bad fixes, and the jitter of standing still doesn't add distance.
///
/// ```swift
/// let recorder = RouteRecorder()
///
/// // Show the path while recording:
/// for await point in await recorder.start() {
///     path.append(point)
/// }
///
/// // When the user taps Stop:
/// let route = await recorder.stop(name: "Evening walk")
/// ```
///
/// The recording runs until ``stop(name:)`` is called or the provider's stream finishes.
/// Releasing the recorder also stops it, so the provider is never left running.
///
/// With the default ``LiveLocationProvider``, the app needs `NSLocationWhenInUseUsageDescription`
/// in its Info.plist and When In Use authorization, for example from
/// `CLLocationManager().requestWhenInUseAuthorization()`.
public actor RouteRecorder {
    /// Locations closer than this to the last kept point are skipped, in meters.
    public nonisolated let minimumDistance: CLLocationDistance
    /// Locations with a larger horizontal accuracy are skipped, in meters.
    ///
    /// Horizontal accuracy is the radius of uncertainty, so a larger value is a worse fix.
    public nonisolated let maximumAccuracy: CLLocationAccuracy

    /// Whether the recorder is reading locations from its provider.
    public private(set) var isRecording = false
    /// The points kept since the last ``start()``.
    public private(set) var points: [RoutePoint] = []

    private let provider: any LocationProvider
    private var recordedAt: Date?
    private var lastKept: CLLocation?
    private var recording: Task<Void, Never>?
    // Lets locations still in flight from a stopped recording be told apart from the current one.
    private var recordingID: UUID?
    private var subscribers: [UUID: AsyncStream<RoutePoint>.Continuation] = [:]

    /// - Parameters:
    ///   - provider: Where locations come from. Real GPS by default.
    ///   - minimumDistance: Locations closer than this to the last kept point are skipped, in meters.
    ///     The default of 5 m ignores standing-still jitter but keeps the corners of a walk.
    ///   - maximumAccuracy: Locations with a worse horizontal accuracy are skipped, in meters.
    ///     The default of 30 m keeps normal outdoor fixes and drops the rough ones a phone
    ///     reports indoors or right after it starts.
    ///
    /// - Precondition: `minimumDistance` is zero or more, and `maximumAccuracy` is greater than zero.
    public init(
        provider: any LocationProvider = LiveLocationProvider(),
        minimumDistance: CLLocationDistance = 5,
        maximumAccuracy: CLLocationAccuracy = 30
    ) {
        precondition(minimumDistance >= 0, "The minimum distance can't be negative.")
        precondition(maximumAccuracy > 0, "The maximum accuracy must be greater than zero.")
        self.provider = provider
        self.minimumDistance = minimumDistance
        self.maximumAccuracy = maximumAccuracy
    }

    deinit {
        recording?.cancel()
        for continuation in subscribers.values {
            continuation.finish()
        }
    }

    /// Starts recording and returns a stream of the points kept from now on.
    ///
    /// The stream is for live UI, such as drawing the path; ignoring it is fine, and the
    /// recording continues when its consumer stops listening. It finishes when the recording ends.
    ///
    /// Calling it while already recording returns another stream and doesn't restart the recording.
    /// Points kept before that call are in ``points``.
    @discardableResult
    public func start() -> AsyncStream<RoutePoint> {
        let (stream, continuation) = AsyncStream<RoutePoint>.makeStream()
        let subscriberID = UUID()
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(subscriberID) }
        }
        subscribers[subscriberID] = continuation

        if !isRecording {
            beginRecording()
        }
        return stream
    }

    /// Stops recording and returns everything kept since ``start()``.
    ///
    /// No point is added after this returns, and every stream from ``start()`` finishes.
    /// Without any kept points the route is empty: that saves as valid JSON, but loading it
    /// back from GPX throws ``RouteFileError/noPoints``.
    ///
    /// - Parameter name: The route's name, such as "Evening walk".
    public func stop(name: String) -> RecordedRoute {
        endRecording()
        return RecordedRoute(name: name, recordedAt: recordedAt ?? .now, points: points)
    }

    /// Whether a location passes the recorder's filters.
    ///
    /// - Parameters:
    ///   - location: The new location.
    ///   - last: The last kept location, or `nil` if none has been kept yet.
    static func shouldKeep(
        _ location: CLLocation,
        after last: CLLocation?,
        minimumDistance: CLLocationDistance,
        maximumAccuracy: CLLocationAccuracy
    ) -> Bool {
        // A negative accuracy marks an invalid location.
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= maximumAccuracy else {
            return false
        }
        // Measured from the last kept location, so slow steps that are each too short still add up.
        guard let last else { return true }
        return location.distance(from: last) >= minimumDistance
    }

    // Test hook.
    var subscriberCount: Int { subscribers.count }

    // MARK: - Recording

    private func beginRecording() {
        let id = UUID()
        recordingID = id
        isRecording = true
        points = []
        lastKept = nil
        recordedAt = .now

        let locations = provider.locations()
        // Holds the recorder weakly, so releasing it runs `deinit`, which cancels this task
        // and with it the provider's stream.
        recording = Task { [weak self] in
            for await location in locations {
                await self?.record(location, recordingID: id)
            }
            await self?.providerFinished(recordingID: id)
        }
    }

    private func record(_ location: CLLocation, recordingID id: UUID) {
        guard recordingID == id else { return }
        guard Self.shouldKeep(location, after: lastKept, minimumDistance: minimumDistance, maximumAccuracy: maximumAccuracy) else {
            return
        }
        lastKept = location
        let point = RoutePoint(location)
        points.append(point)
        for continuation in subscribers.values {
            continuation.yield(point)
        }
    }

    // The provider's stream finished on its own, for example a replay that doesn't loop.
    private func providerFinished(recordingID id: UUID) {
        guard recordingID == id else { return }
        endRecording()
    }

    private func endRecording() {
        recording?.cancel()
        recording = nil
        recordingID = nil
        isRecording = false
        let continuations = subscribers.values
        subscribers.removeAll()
        for continuation in continuations {
            continuation.finish()
        }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }
}
