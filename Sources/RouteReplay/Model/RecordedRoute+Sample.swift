import Foundation

extension RecordedRoute {
    /// A walk along Rustaveli Avenue in Tbilisi, bundled for previews, demos and tests.
    public static let sample: RecordedRoute = {
        let url = Bundle.module.url(forResource: "sample-tbilisi-walk", withExtension: "json")!
        // The file ships with the package and a test loads it, so a failure here is a packaging bug.
        return try! RecordedRoute(contentsOf: url)
    }()
}
