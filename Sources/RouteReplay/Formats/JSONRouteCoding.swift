import Foundation

extension RecordedRoute {
    /// Decodes a route from RouteReplay JSON.
    public init(jsonData: Data) throws {
        self = try JSONRouteCoding.makeDecoder().decode(RecordedRoute.self, from: jsonData)
    }

    /// Encodes the route as pretty-printed RouteReplay JSON.
    public func jsonData() throws -> Data {
        try JSONRouteCoding.makeEncoder().encode(self)
    }
}

/// Encoder and decoder settings shared by everything that reads or writes route JSON.
///
/// Dates are ISO 8601 strings in ``RouteDateFormat``. The built-in `.iso8601` strategy
/// drops fractional seconds, which would make replay gaps uneven.
enum JSONRouteCoding {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(RouteDateFormat.string(from: date))
        }
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = RouteDateFormat.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO 8601 date, got \"\(string)\"."
            )
        }
        return decoder
    }
}
