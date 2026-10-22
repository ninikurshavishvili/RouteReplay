import Foundation
import RouteReplay
import Testing

struct GPXTests {
    /// A watch export: two track segments, a waypoint marking a sight, and heart rate extensions.
    private static let watchExport = Bundle.module.url(forResource: "RustaveliWalk", withExtension: "gpx")!

    private static func date(_ string: String) throws -> Date {
        try Date(string, strategy: .iso8601)
    }

    @Test func exportWritesOneTrackPointPerPoint() {
        let gpx = String(decoding: TestData.route.gpxData(), as: UTF8.self)

        let coordinates = gpx.matches(of: /<trkpt lat="([^"]+)" lon="([^"]+)">/).map { "\($0.1) \($0.2)" }
        #expect(coordinates == ["41.6977 44.799", "41.6981 44.7995", "41.6986 44.8001"])
        let times = gpx.matches(of: /<time>([^<]+)<\/time>/).map { String($0.1) }
        #expect(times == [
            "2026-10-21T10:00:00.000Z",  // the recording start, in <metadata>
            "2026-10-21T10:00:00.500Z",
            "2026-10-21T10:00:04.500Z",
            "2026-10-21T10:00:09.250Z",
        ])
        // The second point has no altitude.
        #expect(gpx.matches(of: /<ele>/).count == 2)
        #expect(gpx.contains(#"<gpx version="1.1" creator="RouteReplay""#))
    }

    @Test func exportKeepsPositionAltitudeAndTime() throws {
        let route = try RecordedRoute(gpxData: TestData.route.gpxData())

        #expect(route.name == TestData.route.name)
        #expect(route.recordedAt == TestData.route.recordedAt)
        #expect(route.points == TestData.route.points.map {
            RoutePoint(
                latitude: $0.latitude,
                longitude: $0.longitude,
                altitude: $0.altitude,
                horizontalAccuracy: 5,
                timestamp: $0.timestamp
            )
        })
    }

    @Test func exportWritesSmallNumbersWithoutExponent() {
        let point = RoutePoint(
            latitude: 0.00005,
            longitude: -0.0000125,
            altitude: 0.00001,
            horizontalAccuracy: 5,
            timestamp: TestData.start
        )
        let route = RecordedRoute(name: "Null Island", recordedAt: TestData.start, points: [point])
        let gpx = String(decoding: route.gpxData(), as: UTF8.self)

        #expect(gpx.contains(#"<trkpt lat="0.00005" lon="-0.0000125">"#))
        #expect(gpx.contains("<ele>0.00001</ele>"))
    }

    @Test func exportEscapesTheName() throws {
        let route = RecordedRoute(name: #"Tom & Jerry's <"best"> walk"#, recordedAt: TestData.start, points: [TestData.fullPoint])
        let gpx = String(decoding: route.gpxData(), as: UTF8.self)

        #expect(gpx.contains(#"<name>Tom &amp; Jerry's &lt;&quot;best&quot;&gt; walk</name>"#))
        #expect(try RecordedRoute(gpxData: route.gpxData()).name == route.name)
    }

    @Test func importsWatchExport() throws {
        let route = try RecordedRoute(contentsOf: Self.watchExport)

        #expect(route.name == "Freedom Square & Rustaveli walk")
        #expect(route.recordedAt == (try Self.date("2026-10-18T06:12:01Z")))
        // Both segments, without the waypoint.
        #expect(route.points.count == 14)
        let first = try #require(route.points.first)
        #expect(first.latitude == 41.693396)
        #expect(first.longitude == 44.801528)
        #expect(first.altitude == 452.4)
        #expect(first.horizontalAccuracy == 5)
        #expect(first.timestamp == (try Self.date("2026-10-18T06:12:04Z")))
        #expect(route.points.last?.timestamp == (try Self.date("2026-10-18T06:15:24Z")))
    }

    @Test func importsXcodeWaypointsWithoutTimes() throws {
        let gpx = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="Xcode">
            <wpt lat="41.6934" lon="44.8015">
                <name>Freedom Square</name>
                <!-- Without times, Xcode moves between the waypoints at a fixed speed. -->
            </wpt>
            <wpt lat="41.6977" lon="44.7984">
                <name>Opera</name>
            </wpt>
            <wpt lat="41.7013" lon="44.7947">
                <name>Rustaveli</name>
            </wpt>
        </gpx>
        """
        let route = try RecordedRoute(gpxData: Data(gpx.utf8))

        #expect(route.points.map(\.latitude) == [41.6934, 41.6977, 41.7013])
        #expect(route.points.map(\.longitude) == [44.8015, 44.7984, 44.7947])
        #expect(route.points.allSatisfy { $0.altitude == nil })
        let start = route.recordedAt
        #expect(route.points.map(\.timestamp) == [start, start + 1, start + 2])
        // Waypoint names name places, not the route.
        #expect(route.name == "")
    }

    @Test func importsRoutePointsAndFillsInMissingTimes() throws {
        let gpx = """
        <gpx version="1.1" creator="Planner">
          <wpt lat="41.6977" lon="44.7984"><name>Opera</name></wpt>
          <rte>
            <name>To the metro</name>
            <rtept lat="41.6934" lon="44.8015"><time>2026-10-21T10:00:00Z</time></rtept>
            <rtept lat="41.6977" lon="44.7984"></rtept>
            <rtept lat="41.7013" lon="44.7947"><time>2026-10-21T10:05:00Z</time></rtept>
          </rte>
        </gpx>
        """
        let route = try RecordedRoute(gpxData: Data(gpx.utf8))

        #expect(route.name == "To the metro")
        #expect(route.recordedAt == TestData.start)
        #expect(route.points.map(\.timestamp) == [TestData.start, TestData.start + 1, TestData.start + 300])
    }

    @Test func gpxRoundTrip() throws {
        let imported = try RecordedRoute(contentsOf: Self.watchExport)
        #expect(try RecordedRoute(gpxData: imported.gpxData()) == imported)
    }

    @Test func savesAndLoadsFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).gpx")
        defer { try? FileManager.default.removeItem(at: url) }

        try TestData.route.save(to: url, format: .gpx)
        #expect(try RecordedRoute(contentsOf: url) == RecordedRoute(gpxData: TestData.route.gpxData()))
    }

    @Test func unnamedFileIsNamedAfterTheFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString) Tbilisi.gpx")
        defer { try? FileManager.default.removeItem(at: url) }

        try Data(#"<gpx version="1.1"><wpt lat="41.6934" lon="44.8015"/></gpx>"#.utf8).write(to: url)
        #expect(try RecordedRoute(contentsOf: url).name == url.deletingPathExtension().lastPathComponent)
    }

    @Test func rejectsMalformedXML() {
        let gpx = """
        <gpx version="1.1">
          <trk><trkseg>
            <trkpt lat="41.6977" lon="44.7990">
          </trkseg></trk>
        </gpx>
        """
        let error = #expect(throws: RouteFileError.self) {
            try RecordedRoute(gpxData: Data(gpx.utf8))
        }
        guard case .invalidGPX(_, let line) = error else {
            Issue.record("Expected invalidGPX, got \(String(describing: error))")
            return
        }
        #expect(line == 4)
    }

    @Test(arguments: ["", #"{ "name": "Rustaveli walk" }"#])
    func rejectsDataThatIsNotXML(text: String) {
        let error = #expect(throws: RouteFileError.self) {
            try RecordedRoute(gpxData: Data(text.utf8))
        }
        guard case .invalidGPX = error else {
            Issue.record("Expected invalidGPX, got \(String(describing: error))")
            return
        }
    }

    @Test(arguments: [
        (#"<trkpt lat="north" lon="44.799"/>"#, #"lat "north" is not a number from -90 to 90."#),
        (#"<trkpt lat="41.6977" lon="200"/>"#, #"lon "200" is not a number from -180 to 180."#),
        (#"<trkpt lat="41.6977"/>"#, "<trkpt> has no lon attribute."),
        (#"<trkpt lat="41.6977" lon="44.799"><ele>high</ele></trkpt>"#, #"ele "high" is not a number."#),
        (#"<trkpt lat="41.6977" lon="44.799"><time>yesterday</time></trkpt>"#, #"time "yesterday" is not an ISO 8601 date."#),
    ])
    func rejectsInvalidValue(trackPoint: String, message: String) {
        let gpx = #"<gpx version="1.1"><trk><trkseg>\#(trackPoint)</trkseg></trk></gpx>"#
        #expect(throws: RouteFileError.invalidGPX(message, line: 1)) {
            try RecordedRoute(gpxData: Data(gpx.utf8))
        }
    }

    @Test func rejectsFileWithoutPoints() {
        let gpx = #"<gpx version="1.1" creator="Xcode"><metadata><name>Empty</name></metadata></gpx>"#
        #expect(throws: RouteFileError.noPoints) {
            try RecordedRoute(gpxData: Data(gpx.utf8))
        }
    }
}
