import CoreLocation
@testable import RouteReplay
import Testing

struct LiveLocationProviderTests {
    private struct SourceError: Error {}

    @Test func yieldsLocationsInOrderAndSkipsEmptyUpdates() async {
        let source = AsyncStream<CLLocation?> { continuation in
            continuation.yield(TestData.fullPoint.makeLocation())
            continuation.yield(nil)
            continuation.yield(TestData.barePoint.makeLocation())
            continuation.finish()
        }

        var received: [RoutePoint] = []
        for await location in LiveLocationProvider.locations(from: source, location: { $0 }) {
            received.append(RoutePoint(location))
        }

        #expect(received == [TestData.fullPoint, TestData.barePoint])
    }

    @Test func finishesWhenTheSourceFails() async {
        let source = AsyncThrowingStream<CLLocation?, any Error> { continuation in
            continuation.yield(TestData.fullPoint.makeLocation())
            continuation.finish(throwing: SourceError())
        }

        var count = 0
        for await _ in LiveLocationProvider.locations(from: source, location: { $0 }) {
            count += 1
        }

        #expect(count == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func cancellingTheConsumerStopsTheSource() async {
        let (source, sourceContinuation) = AsyncStream<CLLocation?>.makeStream()
        let (sourceStopped, sourceStoppedContinuation) = AsyncStream<Void>.makeStream()
        sourceContinuation.onTermination = { _ in sourceStoppedContinuation.finish() }

        let locations = LiveLocationProvider.locations(from: source, location: { $0 })
        let consumer = Task {
            for await _ in locations {}
        }
        sourceContinuation.yield(TestData.fullPoint.makeLocation())
        consumer.cancel()

        // Returns only once the source has been terminated; a leak would hang until the time limit.
        for await _ in sourceStopped {}
    }
}
