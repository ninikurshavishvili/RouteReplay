# RouteReplay

[![Tests](https://github.com/ninikurshavishvili/RouteReplay/actions/workflows/tests.yml/badge.svg)](https://github.com/ninikurshavishvili/RouteReplay/actions/workflows/tests.yml)

Record a GPS route once, then replay it as if it were live: in the simulator, in SwiftUI previews and in unit tests.

<!-- GIF -->

Testing location code usually means walking around with your phone. Xcode can simulate a GPX route while the app runs, but not in previews or unit tests, and you can't pause it or speed it up from your code. RouteReplay lets you record a walk once and replay it at your desk, as fast as you like.

## Installation

In Xcode, choose **File → Add Package Dependencies…** and paste:

```text
https://github.com/ninikurshavishvili/RouteReplay.git
```

Or add it to `Package.swift`:

```swift
.package(url: "https://github.com/ninikurshavishvili/RouteReplay.git", from: "0.1.0")
```

It needs iOS 17 or macOS 14 and Swift 6. It has no dependencies.

## Usage

Read locations through `LocationProvider` instead of Core Location:

```swift
import CoreLocation
import Observation
import RouteReplay

@MainActor @Observable
final class WalkTracker {
    private(set) var lastLocation: CLLocation?
    private let provider: any LocationProvider

    init(provider: any LocationProvider) {
        self.provider = provider
    }

    func start() async {
        for await location in provider.locations() {
            lastLocation = location
        }
    }
}
```

Then give it real GPS in the app and a replay everywhere else:

```swift
let live = WalkTracker(provider: LiveLocationProvider())

let route = try RecordedRoute(contentsOf: walkURL)  // a .json or .gpx file
let replay = WalkTracker(provider: ReplayLocationProvider(route: route, speed: 10, loop: true))
```

The replay waits the recorded time between points, divided by `speed`, and stamps each location with the current time, so your code treats it as fresh GPS. You can call `pause()`, `play()`, `stop()` and `setSpeed(_:)` while it runs. Every stream from one player shares the same position in the route, so a map and a tracker stay in step.

### Recording a route

```swift
let recorder = RouteRecorder()

for await point in await recorder.start() {
    path.append(point)  // draw the path as it grows
}

// When the user taps Stop:
let route = await recorder.stop(name: "Evening walk")
try route.save(to: fileURL, format: .json)  // or .gpx
```

The recorder skips fixes worse than 30 m and points closer than 5 m to the last one, so standing still doesn't add distance. Both limits are parameters.

### Previews and tests

`RouteDebugMap` shows a replay on a map with play, restart and speed buttons. `RecordedRoute.sample` is a walk in Tbilisi that comes with the package.

```swift
#Preview {
    RouteDebugMap(player: ReplayLocationProvider(route: .sample, speed: 10, loop: true))
}
```

A replay needs no device and no permission. With `speed: .infinity` it sends every point without waiting:

```swift
@Test func replaysTheWholeWalk() async {
    let provider = ReplayLocationProvider(route: .sample, speed: .infinity)

    var count = 0
    for await _ in provider.locations() {
        count += 1
    }

    #expect(count == RecordedRoute.sample.points.count)
}
```

## Good to know

- Your code has to read locations through `LocationProvider`. Code that uses `CLLocationManager` directly needs a small refactor first.
- It covers location updates only: no heading, region monitoring or visits.
- Recording stops when the app goes to the background. Background recording is on the [ideas list](IDEAS.md).
- GPX has no accuracy, speed or course fields, so imported points get 5 m accuracy and exported files leave those out. JSON keeps everything.
- `LiveLocationProvider`, and `RouteRecorder` with its default provider, need `NSLocationWhenInUseUsageDescription` in Info.plist and When In Use permission.

## Demo app

[Retrace](https://github.com/ninikurshavishvili/Retrace) is a small iPhone app built on RouteReplay. It records walks, lists them and replays them on a map.

## Contributing

Issues and pull requests are welcome. Run the tests with `swift test`.

## License

MIT. See [LICENSE](LICENSE).
