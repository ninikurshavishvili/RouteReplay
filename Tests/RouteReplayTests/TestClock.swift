import Foundation

/// A clock whose time moves only when a test calls ``advance(by:)``, so timing tests run instantly.
final class TestClock: Clock, @unchecked Sendable {
    struct Instant: InstantProtocol {
        var offset: Duration

        func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Duration {
            other.offset - offset
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    private struct Sleeper {
        let id: UUID
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    // All state is guarded by `lock`.
    private let lock = NSLock()
    private var current = Instant(offset: .zero)
    private var sleepers: [Sleeper] = []
    private var cancelledSleeperIDs: Set<UUID> = []
    private var requestedSleeps: [Duration] = []

    var now: Instant { lock.withLock { current } }
    var minimumResolution: Duration { .zero }

    /// Every duration the code under test asked to sleep for, in order.
    var sleeps: [Duration] { lock.withLock { requestedSleeps } }
    /// How many sleeps are waiting for time to move.
    var sleeperCount: Int { lock.withLock { sleepers.count } }

    func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let result: Result<Void, any Error>? = lock.withLock {
                    requestedSleeps.append(current.duration(to: deadline))
                    if cancelledSleeperIDs.remove(id) != nil { return .failure(CancellationError()) }
                    if deadline <= current { return .success(()) }
                    sleepers.append(Sleeper(id: id, deadline: deadline, continuation: continuation))
                    return nil
                }
                if let result {
                    continuation.resume(with: result)
                }
            }
        } onCancel: {
            let sleeper: Sleeper? = lock.withLock {
                guard let index = sleepers.firstIndex(where: { $0.id == id }) else {
                    // Cancelled before the sleep registered; it will see this and throw.
                    cancelledSleeperIDs.insert(id)
                    return nil
                }
                return sleepers.remove(at: index)
            }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Moves time forward and wakes every sleep whose deadline has passed.
    func advance(by duration: Duration) {
        let due: [Sleeper] = lock.withLock {
            current = current.advanced(by: duration)
            let due = sleepers.filter { $0.deadline <= current }
            sleepers.removeAll { $0.deadline <= current }
            return due
        }
        for sleeper in due {
            sleeper.continuation.resume()
        }
    }

    /// Suspends until `count` sleeps are waiting, so a test never advances time too early.
    /// Gives up if the test is cancelled, for example by its time limit.
    func waitForSleepers(count: Int = 1) async {
        while !Task.isCancelled, sleeperCount < count {
            await Task.yield()
        }
    }
}
