import Foundation

extension RecordedRoute {
    /// Encodes the route as a GPX 1.1 file with one track.
    ///
    /// GPX stores position, altitude and time only, so accuracy, speed and course are left out.
    public func gpxData() -> Data {
        Data(GPXExporter.string(from: self).utf8)
    }
}

/// Writes a ``RecordedRoute`` as GPX 1.1: one track with one segment, plus the recording
/// start as the file time so it survives a save and load.
enum GPXExporter {
    static func string(from route: RecordedRoute) -> String {
        var lines = [
            #"<?xml version="1.0" encoding="UTF-8"?>"#,
            #"<gpx version="1.1" creator="RouteReplay" xmlns="http://www.topografix.com/GPX/1/1">"#,
            "  <metadata>",
            "    <time>\(RouteDateFormat.string(from: route.recordedAt))</time>",
            "  </metadata>",
            "  <trk>",
        ]
        if !route.name.isEmpty {
            lines.append("    <name>\(escaped(route.name))</name>")
        }
        lines.append("    <trkseg>")
        for point in route.points {
            lines.append(#"      <trkpt lat="\#(decimal(point.latitude))" lon="\#(decimal(point.longitude))">"#)
            if let altitude = point.altitude {
                lines.append("        <ele>\(decimal(altitude))</ele>")
            }
            lines.append("        <time>\(RouteDateFormat.string(from: point.timestamp))</time>")
            lines.append("      </trkpt>")
        }
        lines += ["    </trkseg>", "  </trk>", "</gpx>", ""]
        return lines.joined(separator: "\n")
    }

    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // GPX numbers are XML Schema decimals, which have no exponent, but `Double.description`
    // switches to one for small values (0.00005 is "5e-05"). Going through `Decimal` writes
    // the same shortest digits without it.
    private static func decimal(_ value: Double) -> String {
        Decimal(string: value.description)?.description ?? value.description
    }
}
