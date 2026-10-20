import Foundation
import RouteReplay
import Testing

struct RouteCodingTests {
    @Test func jsonRoundTripKeepsEveryField() throws {
        let decoded = try RecordedRoute(jsonData: TestData.route.jsonData())
        #expect(decoded == TestData.route)
    }

    @Test func datesKeepMilliseconds() throws {
        let json = String(decoding: try TestData.route.jsonData(), as: UTF8.self)
        #expect(json.contains("\"2026-10-21T10:00:00.500Z\""))
    }

    @Test func decodesHandWrittenJSONWithoutFractionalSeconds() throws {
        let json = """
        {
          "name": "Rustaveli walk",
          "recordedAt": "2026-10-21T10:00:00Z",
          "points": [
            { "latitude": 41.6977, "longitude": 44.7990, "horizontalAccuracy": 5, "timestamp": "2026-10-21T10:00:00Z" }
          ]
        }
        """
        let route = try RecordedRoute(jsonData: Data(json.utf8))

        #expect(route.name == "Rustaveli walk")
        #expect(route.recordedAt == TestData.start)
        let point = try #require(route.points.first)
        #expect(route.points.count == 1)
        #expect(point.latitude == 41.6977)
        #expect(point.altitude == nil)
        #expect(point.timestamp == TestData.start)
    }

    @Test func encodingOmitsMissingValues() throws {
        let route = RecordedRoute(name: "One point", recordedAt: TestData.start, points: [TestData.barePoint])
        let json = String(decoding: try route.jsonData(), as: UTF8.self)

        #expect(!json.contains("altitude"))
        #expect(!json.contains("speed"))
        #expect(!json.contains("course"))
    }

    @Test func rejectsInvalidDate() {
        let json = #"{ "name": "Bad", "recordedAt": "yesterday", "points": [] }"#
        #expect(throws: DecodingError.self) {
            try RecordedRoute(jsonData: Data(json.utf8))
        }
    }

    @Test func savesAndLoadsFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        try TestData.route.save(to: url, format: .json)
        #expect(try RecordedRoute(contentsOf: url) == TestData.route)
    }

    @Test func rejectsUnknownFileExtension() {
        #expect(throws: RouteFileError.unsupportedFileExtension("kml")) {
            try RecordedRoute(contentsOf: URL(filePath: "/tmp/route.kml"))
        }
    }
}
