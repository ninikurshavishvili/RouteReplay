import CoreLocation

/// A ``LocationProvider`` that replays a ``RecordedRoute`` as if it were live GPS.
///
/// Points are sent one by one, waiting the recorded time gap between them divided by ``speed``.
/// All streams from ``locations()`` share one playhead, so every consumer sees the same point at
/// the same moment, and ``play()``, ``pause()``, ``stop()`` and ``setSpeed(_:)`` control all of them.
///
/// Replay never touches real GPS, so it needs no location permission.
public actor ReplayLocationProvider: LocationProvider {
    /// Route time waited between the last point and the first one when looping.
    static let loopRestartGap: TimeInterval = 1

    /// The route being replayed.
    public nonisolated let route: RecordedRoute
    /// Whether replay starts over from the first point after the last one.
    public nonisolated let loop: Bool
    /// How many times faster than real time the route is replayed.
    public private(set) var speed: Double
    /// Whether the playhead is moving. Replay starts playing as soon as a stream is consumed.
    public private(set) var isPlaying = true

    private let clock: any Clock<Duration>
    private var index = 0
    private var playback: Task<Void, Never>?
    private var subscribers: [UUID: AsyncStream<CLLocation>.Continuation] = [:]
    private var terminatedBeforeAdding: Set<UUID> = []
    private var playWaiters: [CheckedContinuation<Void, Never>] = []

    /// - Parameters:
    ///   - route: The route to replay.
    ///   - speed: How many times faster than real time to replay. Must be greater than zero.
    ///   - loop: Whether to start over from the first point after the last one.
    ///   - clock: The clock used to wait between points. Tests pass a clock they control.
    public init(
        route: RecordedRoute,
        speed: Double = 1,
        loop: Bool = false,
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        precondition(speed > 0, "Replay speed must be greater than zero.")
        self.route = route
        self.speed = speed
        self.loop = loop
        self.clock = clock
    }

    /// Returns a stream of replayed locations, each stamped with the current time.
    ///
    /// The stream joins the shared playhead. Without ``loop``, it finishes after the last point.
    public nonisolated func locations() -> AsyncStream<CLLocation> {
        let (stream, continuation) = AsyncStream<CLLocation>.makeStream()
        let id = UUID()
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }
        Task { await addSubscriber(id, continuation) }
        return stream
    }

    /// Moves the playhead again after ``pause()`` or ``stop()``.
    public func play() {
        isPlaying = true
        resumePlayWaiters()
        startPlaybackIfNeeded()
    }

    /// Holds the next point until ``play()``. A wait that is already running finishes first.
    public func pause() {
        isPlaying = false
    }

    /// Pauses and rewinds to the first point.
    public func stop() {
        isPlaying = false
        index = 0
        cancelPlayback()
    }

    /// Changes the replay speed, starting from the next gap between points.
    public func setSpeed(_ speed: Double) {
        precondition(speed > 0, "Replay speed must be greater than zero.")
        self.speed = speed
    }

    // Test hooks.
    var subscriberCount: Int { subscribers.count }
    var isWaitingForPlay: Bool { !playWaiters.isEmpty }
    var hasPlaybackTask: Bool { playback != nil }

    // MARK: - Subscribers

    private func addSubscriber(_ id: UUID, _ continuation: AsyncStream<CLLocation>.Continuation) {
        // The stream can end before this runs; its removal then arrived first.
        guard terminatedBeforeAdding.remove(id) == nil else { return }
        subscribers[id] = continuation
        startPlaybackIfNeeded()
    }

    private func removeSubscriber(_ id: UUID) {
        guard subscribers.removeValue(forKey: id) != nil else {
            terminatedBeforeAdding.insert(id)
            return
        }
        if subscribers.isEmpty {
            cancelPlayback()
        }
    }

    // MARK: - Playback

    private func startPlaybackIfNeeded() {
        guard playback == nil, !subscribers.isEmpty else { return }
        playback = Task { await run() }
    }

    private func cancelPlayback() {
        playback?.cancel()
        playback = nil
        // A cancelled loop that is waiting for play() wakes up and exits.
        resumePlayWaiters()
    }

    private func run() async {
        let points = route.points
        guard !points.isEmpty else {
            finishSubscribers()
            return
        }

        while true {
            await waitUntilPlaying()
            guard !Task.isCancelled else { return }

            let point = points[index]
            let location = point.makeLocation(timestamp: .now)
            for continuation in subscribers.values {
                continuation.yield(location)
            }

            let gap: TimeInterval
            if index + 1 < points.count {
                gap = max(0, points[index + 1].timestamp.timeIntervalSince(point.timestamp))
                index += 1
            } else if loop {
                gap = Self.loopRestartGap
                index = 0
            } else {
                finishSubscribers()
                return
            }

            do {
                try await clock.sleep(for: .seconds(gap / speed))
            } catch {
                return
            }
        }
    }

    private func waitUntilPlaying() async {
        while !isPlaying, !Task.isCancelled {
            await withCheckedContinuation { playWaiters.append($0) }
        }
    }

    private func resumePlayWaiters() {
        let waiters = playWaiters
        playWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func finishSubscribers() {
        // Subscribers stay listed until their termination handlers remove them.
        for continuation in subscribers.values {
            continuation.finish()
        }
        index = 0
        playback = nil
    }
}
