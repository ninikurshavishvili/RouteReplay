import CoreLocation
import RouteReplay
import Testing

struct RoutePointLocationTests {
    @Test(arguments: [TestData.fullPoint, TestData.barePoint])
    func roundTripThroughCLLocation(point: RoutePoint) {
        #expect(RoutePoint(point.makeLocation()) == point)
    }

    @Test func invalidCoreLocationValuesBecomeNil() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 41.6977, longitude: 44.7990),
            altitude: 480,
            horizontalAccuracy: 5,
            verticalAccuracy: -1,
            course: -1,
            speed: -1,
            timestamp: TestData.start
        )
        let point = RoutePoint(location)

        #expect(point.altitude == nil)
        #expect(point.speed == nil)
        #expect(point.course == nil)
    }

    @Test func missingValuesBecomeNegativeInCLLocation() {
        let location = TestData.barePoint.makeLocation()

        #expect(location.verticalAccuracy < 0)
        #expect(location.speed < 0)
        #expect(location.course < 0)
    }

    @Test func timestampCanBeReplaced() {
        let now = Date()
        #expect(TestData.fullPoint.makeLocation(timestamp: now).timestamp == now)
        #expect(TestData.fullPoint.makeLocation().timestamp == TestData.fullPoint.timestamp)
    }
}
