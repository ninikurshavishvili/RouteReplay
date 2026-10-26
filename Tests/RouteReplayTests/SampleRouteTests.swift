import Foundation
import RouteReplay
import Testing

struct SampleRouteTests {
    @Test func loads() {
        #expect(RecordedRoute.sample.name == "Rustaveli Avenue walk")
    }

    @Test func hasAtLeastTwentyPoints() {
        #expect(RecordedRoute.sample.points.count >= 20)
    }

    @Test func timestampsStrictlyIncrease() {
        let points = RecordedRoute.sample.points
        #expect(zip(points, points.dropFirst()).allSatisfy { $0.timestamp < $1.timestamp })
    }

    @Test func everyPointIsInTbilisi() {
        #expect(RecordedRoute.sample.points.allSatisfy { point in
            (41.6...41.8).contains(point.latitude) && (44.7...44.9).contains(point.longitude)
        })
    }

    @Test func survivesJSONRoundTrip() throws {
        let decoded = try RecordedRoute(jsonData: RecordedRoute.sample.jsonData())
        #expect(decoded == RecordedRoute.sample)
    }
}
