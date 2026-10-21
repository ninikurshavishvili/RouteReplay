import Foundation

extension RecordedRoute {
    /// Decodes a route from GPX 1.0 or 1.1.
    ///
    /// Points come from the tracks (`<trkpt>`). A file without tracks is read from its routes
    /// (`<rtept>`), and one without those from its waypoints (`<wpt>`), which is what Xcode's
    /// location simulation files use. Points without a `<time>` follow the previous point by
    /// one second. GPX does not store accuracy, so every point gets a horizontal accuracy of 5 meters.
    ///
    /// The route is named after the first track, route or the file metadata, in that order,
    /// and is empty if none has a name.
    ///
    /// - Throws: ``RouteFileError/invalidGPX(_:line:)`` if the data is not well-formed XML or
    ///   a value cannot be read, ``RouteFileError/noPoints`` if it contains no points.
    public init(gpxData: Data) throws {
        self = try GPXImporter.route(from: gpxData, defaultName: "")
    }
}

/// Reads GPX with Foundation's `XMLParser`.
enum GPXImporter {
    // GPX has no accuracy in meters (`<hdop>` is a unitless dilution of precision), so imported
    // points get 5 m, about what a phone reports outdoors with a clear view of the sky.
    static let horizontalAccuracy: Double = 5

    // A file without any times starts at a fixed date rather than now,
    // so loading the same file twice gives equal routes.
    static let undatedStart = Date(timeIntervalSince1970: 0)

    static func route(from data: Data, defaultName: String) throws -> RecordedRoute {
        let parser = XMLParser(data: data)
        let reader = GPXReader()
        parser.delegate = reader
        parser.shouldProcessNamespaces = true
        guard parser.parse() else {
            // Data the parser rejects before reading anything, such as empty data, reports no error to the delegate.
            throw reader.error ?? GPXReader.malformedXML(parser.parserError, line: parser.lineNumber)
        }

        // Waypoints in a file that has a track or route mark places along it; they are not the path.
        let found = GPXReader.pointElements.lazy.compactMap { reader.points[$0] }.first ?? []
        guard let first = found.first else { throw RouteFileError.noPoints }

        let recordedAt = reader.fileTime ?? first.time ?? undatedStart
        var previous: Date?
        let points = found.map { point in
            let timestamp = point.time ?? previous?.addingTimeInterval(1) ?? recordedAt
            previous = timestamp
            return RoutePoint(
                latitude: point.latitude,
                longitude: point.longitude,
                altitude: point.altitude,
                horizontalAccuracy: horizontalAccuracy,
                timestamp: timestamp
            )
        }
        return RecordedRoute(
            name: reader.trackName ?? reader.routeName ?? reader.fileName ?? defaultName,
            recordedAt: recordedAt,
            points: points
        )
    }
}

/// Collects points, names and times while `XMLParser` walks a GPX file.
private final class GPXReader: NSObject, XMLParserDelegate {
    struct Point {
        var latitude: Double
        var longitude: Double
        var altitude: Double?
        var time: Date?
    }

    // In the order the importer prefers them.
    static let pointElements = ["trkpt", "rtept", "wpt"]

    // Points by the element they came from.
    private(set) var points: [String: [Point]] = [:]
    private(set) var trackName: String?
    private(set) var routeName: String?
    private(set) var fileName: String?
    private(set) var fileTime: Date?
    private(set) var error: RouteFileError?

    // Open elements, innermost last. Checking the parent keeps a waypoint's `<name>` from naming
    // the route and a `<time>` inside `<extensions>` from timing a point.
    private var openElements: [String] = []
    private var point: Point?
    private var text = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        openElements.append(elementName)
        text = ""
        guard Self.pointElements.contains(elementName) else { return }
        guard
            let latitude = coordinate("lat", limit: 90, of: elementName, attributes, parser),
            let longitude = coordinate("lon", limit: 180, of: elementName, attributes, parser)
        else { return }
        point = Point(latitude: latitude, longitude: longitude)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        openElements.removeLast()
        let parent = openElements.last ?? ""
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = ""

        switch elementName {
        case "trkpt", "rtept", "wpt":
            if let point { points[elementName, default: []].append(point) }
            point = nil
        case "ele" where Self.pointElements.contains(parent) && !value.isEmpty:
            point?.altitude = altitude(value, parser)
        case "time" where Self.pointElements.contains(parent) && !value.isEmpty:
            point?.time = date(value, parser)
        // GPX 1.1 keeps the file's time and name in `<metadata>`, GPX 1.0 directly in `<gpx>`.
        case "time" where (parent == "metadata" || parent == "gpx") && !value.isEmpty:
            fileTime = fileTime ?? date(value, parser)
        case "name" where !value.isEmpty:
            switch parent {
            case "trk": trackName = trackName ?? value
            case "rte": routeName = routeName ?? value
            case "metadata", "gpx": fileName = fileName ?? value
            default: break
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: any Error) {
        // Aborting in `fail` lands here too; keep the error `fail` recorded.
        guard error == nil else { return }
        // `lineNumber` points at the error only now; once `parse()` returns, the parser has read further.
        error = Self.malformedXML(parseError, line: parser.lineNumber)
    }

    private func coordinate(
        _ name: String,
        limit: Int,
        of element: String,
        _ attributes: [String: String],
        _ parser: XMLParser
    ) -> Double? {
        guard let text = attributes[name] else {
            fail("<\(element)> has no \(name) attribute.", parser)
            return nil
        }
        guard let value = Double(text.trimmingCharacters(in: .whitespaces)), abs(value) <= Double(limit) else {
            fail("\(name) \"\(text)\" is not a number from -\(limit) to \(limit).", parser)
            return nil
        }
        return value
    }

    private func altitude(_ text: String, _ parser: XMLParser) -> Double? {
        guard let value = Double(text), value.isFinite else {
            fail("ele \"\(text)\" is not a number.", parser)
            return nil
        }
        return value
    }

    private func date(_ text: String, _ parser: XMLParser) -> Date? {
        guard let date = RouteDateFormat.date(from: text) else {
            fail("time \"\(text)\" is not an ISO 8601 date.", parser)
            return nil
        }
        return date
    }

    private func fail(_ message: String, _ parser: XMLParser) {
        error = RouteFileError.invalidGPX(message, line: parser.lineNumber)
        parser.abortParsing()
    }

    static func malformedXML(_ parseError: (any Error)?, line: Int) -> RouteFileError {
        let code = (parseError as NSError?)?.code ?? 0
        return .invalidGPX("The data is not well-formed XML (XMLParser error \(code)).", line: line)
    }
}
