import Foundation

/// A file format a ``RecordedRoute`` can be saved as.
public enum RouteFileFormat: Sendable {
    /// RouteReplay's own JSON format.
    case json
    /// GPX 1.1, readable by most map and fitness apps.
    ///
    /// GPX stores position, altitude and time only, so accuracy, speed and course are not saved.
    case gpx
}

/// An error thrown when a route file cannot be loaded.
public enum RouteFileError: Error, Sendable, Equatable {
    /// The file extension does not match any supported ``RouteFileFormat``.
    case unsupportedFileExtension(String)
    /// The data is not readable GPX: the message says what is wrong and `line` says where.
    case invalidGPX(String, line: Int)
    /// The GPX data is readable but contains no track, route or waypoint points.
    case noPoints
}

extension RecordedRoute {
    /// Loads a route from a file, choosing the format from the file extension.
    ///
    /// A GPX file that does not name its track is named after the file.
    public init(contentsOf url: URL) throws {
        switch url.pathExtension.lowercased() {
        case "json":
            try self.init(jsonData: Data(contentsOf: url))
        case "gpx":
            self = try GPXImporter.route(
                from: Data(contentsOf: url),
                defaultName: url.deletingPathExtension().lastPathComponent
            )
        default:
            throw RouteFileError.unsupportedFileExtension(url.pathExtension)
        }
    }

    /// Writes the route to a file in the given format.
    public func save(to url: URL, format: RouteFileFormat) throws {
        switch format {
        case .json:
            try jsonData().write(to: url, options: .atomic)
        case .gpx:
            try gpxData().write(to: url, options: .atomic)
        }
    }
}
