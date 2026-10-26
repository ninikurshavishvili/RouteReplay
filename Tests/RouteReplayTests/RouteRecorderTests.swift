import CoreLocation
import Foundation
@testable import RouteReplay
import Testing

struct RouteRecorderTests {
    // MARK: - Filter

    @Test(arguments: [-1.0, 30.5, 100])
    func dropsInvalidAndInaccurateLocations(accuracy: Double) {
        #expect(!shouldKeep(point(0, accuracy: accuracy), after: nil))
    }

    @Test(arguments: [0.0, 5, 30])
    func keepsAccuracyUpToTheMaximum(accuracy: Double) {
        #expect(shouldKeep(point(0, accuracy: accuracy), after: nil))
    }

    @Test func dropsLocationsCloserThanTheMinimumDistanceToTheLastKeptOne() {
        #expect(!shouldKeep(point(2), after: point(0)))
        #expect(!shouldKeep(point(4), after: point(0)))
        #expect(shouldKeep(point(6), after: point(0)))
        #expect(shouldKeep(point(0), after: nil))
    }

    // MARK: - Recording

    @Test func recordsAReplayKeepingOnlyGoodPointsInOrder() async {
        let walk = RecordedRoute(
            name: "Replayed walk",
            recordedAt: TestData.start,
            points: [
                point(0),
                point(10, accuracy: 100),
                point(20),
                point(22),
                point(30, accuracy: -1),
                point(40),
            ]
        )
        let recorder = RouteRecorder(provider: ReplayLocationProvider(route: walk, clock: TestClock()))
        let before = Date.now

        var streamed: [RoutePoint] = []
        for await point in await recorder.start() {
            streamed.append(point)
        }
        let route = await recorder.stop(name: "Evening walk")

        // Replayed locations carry the current time, so compare where the points are.
        #expect(route.points.map(\.latitude) == [point(0), point(20), point(40)].map(\.latitude))
        #expect(streamed == route.points)
        #expect(route.name == "Evening walk")
        #expect(route.recordedAt >= before)
        #expect(route.recordedAt <= .now)
    }

    @Test func theRecordingEndsWhenTheProviderFinishes() async {
        let walk = RecordedRoute(name: "Short walk", recordedAt: TestData.start, points: [point(0), point(10)])
        let recorder = RouteRecorder(provider: ReplayLocationProvider(route: walk, clock: TestClock()))

        for await _ in await recorder.start() {}

        #expect(await recorder.isRecording == false)
        #expect(await recorder.points.count == 2)
    }

    @Test func stoppingBeforeAnyPointReturnsAnEmptyRoute() async {
        let recorder = RouteRecorder(provider: ManualProvider())

        let route = await recorder.stop(name: "Nothing yet")

        #expect(route.name == "Nothing yet")
        #expect(route.points.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func stopFinishesTheStreamEndsTheProviderAndIgnoresLaterLocations() async {
        let provider = ManualProvider()
        let recorder = RouteRecorder(provider: provider)
        var points = await recorder.start().makeAsyncIterator()

        provider.send(point(0))
        #expect(await points.next() == point(0))
        let route = await recorder.stop(name: "Walk")

        #expect(await points.next() == nil)
        // Returns only once the provider's stream has ended; a leak would hang until the time limit.
        await waitUntil { provider.stoppedStreamCount == 1 }
        provider.send(point(10))
        #expect(route.points == [point(0)])
        #expect(await recorder.points == [point(0)])
        #expect(await recorder.isRecording == false)
    }

    @Test(.timeLimit(.minutes(1)))
    func ignoringTheStreamKeepsRecording() async {
        let provider = ManualProvider()
        let recorder = RouteRecorder(provider: provider)

        await recorder.start()
        provider.send(point(0))
        provider.send(point(10))

        await waitUntil { await recorder.points.count == 2 }
        // The ignored stream was released, and with it its place in the recorder.
        await waitUntil { await recorder.subscriberCount == 0 }
        #expect(await recorder.isRecording)
        #expect(await recorder.stop(name: "Walk").points == [point(0), point(10)])
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellingTheConsumerKeepsRecordingUntilStop() async {
        let provider = ManualProvider()
        let recorder = RouteRecorder(provider: provider)
        let points = await recorder.start()
        let consumer = Task {
            for await _ in points {}
        }

        provider.send(point(0))
        await waitUntil { await recorder.points.count == 1 }
        consumer.cancel()
        await waitUntil { await recorder.subscriberCount == 0 }
        provider.send(point(10))
        await waitUntil { await recorder.points.count == 2 }

        #expect(provider.stoppedStreamCount == 0)
        _ = await recorder.stop(name: "Walk")
        await waitUntil { provider.stoppedStreamCount == 1 }
    }

    @Test(.timeLimit(.minutes(1)))
    func startingWhileRecordingReturnsAnotherStreamWithoutRestarting() async {
        let provider = ManualProvider()
        let recorder = RouteRecorder(provider: provider)
        var first = await recorder.start().makeAsyncIterator()
        provider.send(point(0))
        #expect(await first.next() == point(0))

        var second = await recorder.start().makeAsyncIterator()
        provider.send(point(10))

        #expect(await first.next() == point(10))
        #expect(await second.next() == point(10))
        #expect(await recorder.points == [point(0), point(10)])
        #expect(provider.streamCount == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func releasingTheRecorderEndsTheProvider() async {
        let provider = ManualProvider()
        var recorder: RouteRecorder? = RouteRecorder(provider: provider)
        await recorder?.start()
        provider.send(point(0))
        await waitUntil { await recorder?.points.count == 1 }

        recorder = nil

        // Returns only once the provider's stream has ended; a leak would hang until the time limit.
        await waitUntil { provider.stoppedStreamCount == 1 }
    }

    @Test func defaultsKeepPointsFiveMetersApartWithAccuracyUpToThirtyMeters() {
        let recorder = RouteRecorder()

        #expect(recorder.minimumDistance == 5)
        #expect(recorder.maximumAccuracy == 30)
    }
}

/// A point `meters` north of Freedom Square. All points share one time, so a replay sends them without waiting.
private func point(_ meters: Double, accuracy: Double = 5) -> RoutePoint {
    RoutePoint(
        // A degree of latitude is about 111 km, so this is close enough for distances a meter apart.
        latitude: 41.6934 + meters / 111_195,
        longitude: 44.8015,
        horizontalAccuracy: accuracy,
        timestamp: TestData.start
    )
}

/// The recorder's filter with its default settings.
private func shouldKeep(_ point: RoutePoint, after last: RoutePoint?) -> Bool {
    RouteRecorder.shouldKeep(
        point.makeLocation(),
        after: last?.makeLocation(),
        minimumDistance: 5,
        maximumAccuracy: 30
    )
}

/// A provider the test feeds by hand. Every call to `locations()` makes a new stream.
private final class ManualProvider: LocationProvider, @unchecked Sendable {
    // All state is guarded by `lock`.
    private let lock = NSLock()
    private var continuations: [AsyncStream<CLLocation>.Continuation] = []
    private var stoppedStreams = 0

    /// How many streams the recorder has asked for.
    var streamCount: Int { lock.withLock { continuations.count } }
    /// How many streams have ended, for example because the recorder stopped reading them.
    var stoppedStreamCount: Int { lock.withLock { stoppedStreams } }

    func locations() -> AsyncStream<CLLocation> {
        let (stream, continuation) = AsyncStream<CLLocation>.makeStream()
        continuation.onTermination = { [weak self] _ in self?.streamStopped() }
        lock.withLock { continuations.append(continuation) }
        return stream
    }

    /// Sends a point on the newest stream.
    func send(_ point: RoutePoint) {
        let continuation = lock.withLock { continuations.last }
        continuation?.yield(point.makeLocation())
    }

    private func streamStopped() {
        lock.withLock { stoppedStreams += 1 }
    }
}

/// Polls until `condition` holds, or until the test is cancelled by its time limit.
private func waitUntil(_ condition: () async -> Bool) async {
    while !Task.isCancelled, await !condition() {
        await Task.yield()
    }
}
