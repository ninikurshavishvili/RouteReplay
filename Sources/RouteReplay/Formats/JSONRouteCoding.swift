import Foundation

/// A file format a ``RecordedRoute`` can be saved as.
public enum RouteFileFormat: Sendable {
    /// RouteReplay's own JSON format.
    case json
}

/// An error thrown when a route file cannot be loaded.
public enum RouteFileError: Error, Sendable, Equatable {
    /// The file extension does not match any supported ``RouteFileFormat``.
    case unsupportedFileExtension(String)
}

extension RecordedRoute {
    /// Decodes a route from RouteReplay JSON.
    public init(jsonData: Data) throws {
        self = try JSONRouteCoding.makeDecoder().decode(RecordedRoute.self, from: jsonData)
    }

    /// Encodes the route as pretty-printed RouteReplay JSON.
    public func jsonData() throws -> Data {
        try JSONRouteCoding.makeEncoder().encode(self)
    }

    /// Loads a route from a file, choosing the format from the file extension.
    public init(contentsOf url: URL) throws {
        switch url.pathExtension.lowercased() {
        case "json":
            try self.init(jsonData: Data(contentsOf: url))
        default:
            throw RouteFileError.unsupportedFileExtension(url.pathExtension)
        }
    }

    /// Writes the route to a file in the given format.
    public func save(to url: URL, format: RouteFileFormat) throws {
        switch format {
        case .json:
            try jsonData().write(to: url, options: .atomic)
        }
    }
}

/// Encoder and decoder settings shared by everything that reads or writes route JSON.
///
/// Dates are ISO 8601 strings. The built-in `.iso8601` strategy drops fractional seconds,
/// which would make replay gaps uneven, so dates are written with milliseconds and read
/// with or without them (hand-written files usually have none).
enum JSONRouteCoding {
    private static let fractionalSeconds = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let wholeSeconds = Date.ISO8601FormatStyle()

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(fractionalSeconds))
        }
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = try? fractionalSeconds.parse(string) { return date }
            if let date = try? wholeSeconds.parse(string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO 8601 date, got \"\(string)\"."
            )
        }
        return decoder
    }
}
