import CoreLocation
@testable import RouteReplay
import Testing

struct ReplayTimingTests {
    @Test func replaysEveryPointInOrderThenFinishes() async {
        let player = ReplayLocationProvider(route: makeRoute(pointCount: 5, gap: 0), clock: TestClock())

        var received: [Int] = []
        for await location in player.locations() {
            received.append(Int(location.coordinate.longitude))
        }

        #expect(received == [0, 1, 2, 3, 4])
    }

    @Test func waitsTheRecordedGapDividedBySpeed() async {
        let clock = TestClock()
        let player = ReplayLocationProvider(route: makeRoute(pointCount: 3, gap: 10), speed: 10, clock: clock)
        let points = PointReader(player.locations())

        #expect(await points.next() == 0)
        await clock.waitForSleepers()
        clock.advance(by: .milliseconds(900))
        #expect(clock.sleeperCount == 1)
        clock.advance(by: .milliseconds(100))
        #expect(await points.next() == 1)
        await clock.waitForSleepers()
        clock.advance(by: .seconds(1))
        #expect(await points.next() == 2)
        #expect(await points.next() == nil)

        #expect(clock.sleeps == [.seconds(1), .seconds(1)])
    }

    @Test func pauseHoldsTheNextPointUntilPlay() async {
        let clock = TestClock()
        let player = ReplayLocationProvider(route: makeRoute(pointCount: 3, gap: 10), clock: clock)
        let points = PointReader(player.locations())

        #expect(await points.next() == 0)
        await clock.waitForSleepers()
        clock.advance(by: .seconds(10))
        #expect(await points.next() == 1)

        await player.pause()
        await clock.waitForSleepers()
        clock.advance(by: .seconds(10))
        // The gap is over, but point 2 is held back while paused.
        await waitUntil { await player.isWaitingForPlay }

        await player.play()
        #expect(await points.next() == 2)
    }

    @Test func loopStartsOverAfterTheLastPoint() async {
        let clock = TestClock()
        let player = ReplayLocationProvider(route: makeRoute(pointCount: 2, gap: 0), loop: true, clock: clock)
        let points = PointReader(player.locations())

        #expect(await points.next() == 0)
        #expect(await points.next() == 1)
        await clock.waitForSleepers()
        clock.advance(by: .seconds(ReplayLocationProvider.loopRestartGap))
        #expect(await points.next() == 0)
        #expect(await points.next() == 1)
    }

    @Test func speedChangeAppliesFromTheNextGap() async {
        let clock = TestClock()
        let player = ReplayLocationProvider(route: makeRoute(pointCount: 3, gap: 10), clock: clock)
        let points = PointReader(player.locations())

        #expect(await points.next() == 0)
        await clock.waitForSleepers()
        await player.setSpeed(10)
        clock.advance(by: .seconds(10))
        #expect(await points.next() == 1)
        await clock.waitForSleepers()
        clock.advance(by: .seconds(1))
        #expect(await points.next() == 2)

        #expect(clock.sleeps == [.seconds(10), .seconds(1)])
    }

    @Test func stopRewindsToTheFirstPoint() async {
        let clock = TestClock()
        let player = ReplayLocationProvider(route: makeRoute(pointCount: 3, gap: 10), clock: clock)
        let points = PointReader(player.locations())

        #expect(await points.next() == 0)
        await clock.waitForSleepers()
        clock.advance(by: .seconds(10))
        #expect(await points.next() == 1)

        await player.stop()
        #expect(await player.isPlaying == false)
        await player.play()
        #expect(await points.next() == 0)
    }

    @Test func emptyRouteFinishesImmediately() async {
        let player = ReplayLocationProvider(route: makeRoute(pointCount: 0, gap: 0), clock: TestClock())
        let points = PointReader(player.locations())

        #expect(await points.next() == nil)
    }

    @Test func onePointRouteSendsItOnceThenFinishes() async {
        let clock = TestClock()
        let player = ReplayLocationProvider(route: makeRoute(pointCount: 1, gap: 0), clock: clock)
        let points = PointReader(player.locations())

        #expect(await points.next() == 0)
        #expect(await points.next() == nil)
        #expect(clock.sleeps.isEmpty)
    }

    @Test func onePointRouteLoopsTheSamePoint() async {
        let clock = TestClock()
        let player = ReplayLocationProvider(route: makeRoute(pointCount: 1, gap: 0), loop: true, clock: clock)
        let points = PointReader(player.locations())

        #expect(await points.next() == 0)
        await clock.waitForSleepers()
        clock.advance(by: .seconds(ReplayLocationProvider.loopRestartGap))
        #expect(await points.next() == 0)
        #expect(clock.sleeps.first == .seconds(ReplayLocationProvider.loopRestartGap))
    }

    @Test func timestampsGoingBackwardsReplayWithoutWaiting() async {
        let clock = TestClock()
        let route = makeRoute(pointCount: 3, gap: 10)
        let unsorted = RecordedRoute(
            name: route.name,
            recordedAt: route.recordedAt,
            points: [route.points[0], route.points[2], route.points[1]]
        )
        let player = ReplayLocationProvider(route: unsorted, clock: clock)
        let points = PointReader(player.locations())

        #expect(await points.next() == 0)
        await clock.waitForSleepers()
        clock.advance(by: .seconds(20))
        #expect(await points.next() == 2)
        // Point 1 was measured before point 2, so the gap is negative and there's no wait.
        #expect(await points.next() == 1)
        #expect(await points.next() == nil)

        #expect(clock.sleeps == [.seconds(20), .zero])
    }

    @Test func infiniteSpeedReplaysEveryPointWithoutWaiting() async {
        let clock = TestClock()
        let player = ReplayLocationProvider(route: makeRoute(pointCount: 4, gap: 3_600), speed: .infinity, clock: clock)

        var received: [Int] = []
        for await location in player.locations() {
            received.append(Int(location.coordinate.longitude))
        }

        #expect(received == [0, 1, 2, 3])
        #expect(clock.sleeps == [.zero, .zero, .zero])
    }

    @Test func lateStreamJoinsTheSharedPlayhead() async {
        let clock = TestClock()
        let player = ReplayLocationProvider(route: makeRoute(pointCount: 3, gap: 10), clock: clock)
        let first = PointReader(player.locations())

        #expect(await first.next() == 0)
        await clock.waitForSleepers()
        clock.advance(by: .seconds(10))
        #expect(await first.next() == 1)

        let second = PointReader(player.locations())
        await waitUntil { await player.subscriberCount == 2 }
        await clock.waitForSleepers()
        clock.advance(by: .seconds(10))
        #expect(await first.next() == 2)
        #expect(await second.next() == 2)
    }

    @Test func replayedLocationsCarryTheCurrentTime() async {
        let player = ReplayLocationProvider(route: makeRoute(pointCount: 1, gap: 0), clock: TestClock())
        let start = Date()

        var timestamps: [Date] = []
        for await location in player.locations() {
            timestamps.append(location.timestamp)
        }

        #expect(timestamps.count == 1)
        #expect(timestamps.allSatisfy { $0 >= start })
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellingTheConsumerStopsPlayback() async {
        let clock = TestClock()
        let player = ReplayLocationProvider(route: makeRoute(pointCount: 3, gap: 10), clock: clock)
        let locations = player.locations()
        let consumer = Task {
            for await _ in locations {}
        }
        // Playback is running and waiting to send point 1.
        await clock.waitForSleepers()

        consumer.cancel()

        // Returns only once the playback loop's sleep is cancelled; a leak would hang until the time limit.
        await waitUntil { clock.sleeperCount == 0 }
        #expect(await player.hasPlaybackTask == false)
    }
}

/// A route whose point `i` sits at longitude `i`, so received locations are easy to identify.
private func makeRoute(pointCount: Int, gap: TimeInterval) -> RecordedRoute {
    RecordedRoute(
        name: "Replay test",
        recordedAt: TestData.start,
        points: (0..<pointCount).map { index in
            RoutePoint(
                latitude: 41.69,
                longitude: Double(index),
                horizontalAccuracy: 5,
                timestamp: TestData.start.addingTimeInterval(Double(index) * gap)
            )
        }
    )
}

/// Reads replayed points one at a time as point indices.
private final class PointReader {
    private var iterator: AsyncStream<CLLocation>.Iterator

    init(_ stream: AsyncStream<CLLocation>) {
        iterator = stream.makeAsyncIterator()
    }

    /// The index of the next point, or `nil` once the stream has finished.
    func next() async -> Int? {
        await iterator.next().map { Int($0.coordinate.longitude) }
    }
}

/// Polls until `condition` holds, or until the test is cancelled by its time limit.
private func waitUntil(_ condition: () async -> Bool) async {
    while !Task.isCancelled, await !condition() {
        await Task.yield()
    }
}
