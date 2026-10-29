# Getting started

Record a route on an iPhone, save it, and replay it wherever your code needs location.

## Overview

The whole package rests on one protocol, ``LocationProvider``. Code that depends on it can't tell real GPS from a replay, so you can test it without walking around.

### Depend on the protocol

Take a ``LocationProvider`` instead of creating a `CLLocationManager`:

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

In the app, pass real GPS:

```swift
let tracker = WalkTracker(provider: LiveLocationProvider())
```

``LiveLocationProvider`` needs `NSLocationWhenInUseUsageDescription` in the app's Info.plist and When In Use authorization.

### Record a route

``RouteRecorder`` reads any provider and keeps the points that are accurate enough and far enough apart:

```swift
let recorder = RouteRecorder()

for await point in await recorder.start() {
    path.append(point)
}

// When the user taps Stop:
let route = await recorder.stop(name: "Evening walk")
```

Recording runs while the app is in the foreground.

### Save and load it

```swift
try route.save(to: fileURL, format: .json)
let loaded = try RecordedRoute(contentsOf: fileURL)
```

``RecordedRoute/init(contentsOf:)`` reads `.json` and `.gpx` files, including the GPX files Xcode uses for location simulation.

### Replay it

```swift
let player = ReplayLocationProvider(route: loaded, speed: 10, loop: true)
let tracker = WalkTracker(provider: player)
```

The replay waits the recorded gap between points, divided by the speed, and stamps each location with the current time. ``ReplayLocationProvider/pause()``, ``ReplayLocationProvider/play()``, ``ReplayLocationProvider/stop()`` and ``ReplayLocationProvider/setSpeed(_:)`` work while it runs, and every stream from one player shares its playhead.

### Watch it in a preview

```swift
#Preview {
    RouteDebugMap(player: ReplayLocationProvider(route: .sample, speed: 10, loop: true))
}
```

### Use it in unit tests

A replay needs no device and no permission. A high speed, or `.infinity`, keeps the test fast:

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

To control time yourself, pass your own `Clock` to ``ReplayLocationProvider/init(route:speed:loop:clock:)``.
