import CoreLocation
@testable import RouteReplay
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RouteDebugMapModelTests {
    private let points = TestData.route.points

    @Test func firstCoordinateArrivesOnceFollowStarts() async {
        let player = ReplayLocationProvider(route: TestData.route, speed: 5, clock: TestClock())
        let model = RouteDebugMapModel(player: player)
        let following = Task { await model.follow() }
        defer { following.cancel() }

        await waitUntil { model.pointIndex == 1 }

        #expect(model.isAt(points[0]))
        #expect(model.speed == 5)
        #expect(model.isPlaying)
        #expect(model.pointCount == 3)
    }

    @Test func secondCoordinateArrivesAfterTheGap() async {
        let clock = TestClock()
        let model = RouteDebugMapModel(player: ReplayLocationProvider(route: TestData.route, clock: clock))
        let following = Task { await model.follow() }
        defer { following.cancel() }
        await waitUntil { model.pointIndex == 1 }

        await clock.waitForSleepers()
        clock.advance(by: .seconds(4))
        await waitUntil { model.pointIndex == 2 }

        #expect(model.isAt(points[1]))
    }

    @Test func togglePlayPauses() async {
        let clock = TestClock()
        let player = ReplayLocationProvider(route: TestData.route, clock: clock)
        let model = RouteDebugMapModel(player: player)
        let following = Task { await model.follow() }
        defer { following.cancel() }
        await waitUntil { model.pointIndex == 1 }

        await model.togglePlay()
        #expect(model.isPlaying == false)
        #expect(await player.isPlaying == false)

        await clock.waitForSleepers()
        clock.advance(by: .seconds(4))
        // The gap is over, but the second point is held back while paused.
        await waitUntil { await player.isWaitingForPlay }
        #expect(model.pointIndex == 1)

        await model.togglePlay()
        await waitUntil { model.pointIndex == 2 }
        #expect(model.isPlaying)
    }

    @Test func restartGoesBackToTheFirstPoint() async {
        let clock = TestClock()
        let model = RouteDebugMapModel(player: ReplayLocationProvider(route: TestData.route, clock: clock))
        let following = Task { await model.follow() }
        defer { following.cancel() }
        await waitUntil { model.pointIndex == 1 }
        await clock.waitForSleepers()
        clock.advance(by: .seconds(4))
        await waitUntil { model.pointIndex == 2 }

        let subscription = model.subscription
        await model.restart()
        await waitUntil { model.pointIndex == 1 }

        #expect(model.isAt(points[0]))
        #expect(model.isPlaying)
        #expect(model.subscription == subscription + 1)
    }

    @Test func streamEndingSetsHasFinished() async {
        let clock = TestClock()
        let model = RouteDebugMapModel(player: ReplayLocationProvider(route: TestData.route, clock: clock))
        let following = Task { await model.follow() }

        await playToTheEnd(clock)
        await following.value

        #expect(model.hasFinished)
        #expect(model.pointIndex == 3)
        #expect(model.isAt(points[2]))
    }

    @Test func playAfterTheEndStartsOver() async {
        let clock = TestClock()
        let player = ReplayLocationProvider(route: TestData.route, clock: clock)
        let model = RouteDebugMapModel(player: player)
        let finishing = Task { await model.follow() }
        await playToTheEnd(clock)
        await finishing.value
        // By the time someone taps play, the finished stream has left the player.
        await waitUntil { await player.subscriberCount == 0 }

        let subscription = model.subscription
        await model.togglePlay()
        #expect(model.hasFinished == false)
        #expect(model.subscription == subscription + 1)

        // The view's task does this when the subscription changes.
        let following = Task { await model.follow() }
        defer { following.cancel() }
        await waitUntil { model.pointIndex == 1 }
        #expect(model.isAt(points[0]))
    }

    /// Sends the second and third points of `TestData.route`, after which the replay finishes.
    private func playToTheEnd(_ clock: TestClock) async {
        await clock.waitForSleepers()
        clock.advance(by: .seconds(4))
        await clock.waitForSleepers()
        clock.advance(by: .seconds(4.75))
    }
}

private extension RouteDebugMapModel {
    func isAt(_ point: RoutePoint) -> Bool {
        currentCoordinate?.latitude == point.latitude && currentCoordinate?.longitude == point.longitude
    }
}

/// Polls until `condition` holds, or until the test is cancelled by its time limit.
@MainActor
private func waitUntil(_ condition: @MainActor () async -> Bool) async {
    while !Task.isCancelled, await !condition() {
        await Task.yield()
    }
}
