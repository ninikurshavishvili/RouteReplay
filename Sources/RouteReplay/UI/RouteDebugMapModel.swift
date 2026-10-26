import CoreLocation
import Observation

@MainActor @Observable
final class RouteDebugMapModel {
    static let speeds: [Double] = [1, 5, 10, 20, 50]

    let player: ReplayLocationProvider
    let routeCoordinates: [CLLocationCoordinate2D]

    private(set) var currentCoordinate: CLLocationCoordinate2D?
    private(set) var pointIndex = 0
    private(set) var isPlaying = true
    private(set) var speed: Double = 1
    private(set) var hasFinished = false
    // The view subscribes to the replay again whenever this changes.
    private(set) var subscription = 0

    var pointCount: Int { routeCoordinates.count }

    init(player: ReplayLocationProvider) {
        self.player = player
        routeCoordinates = player.route.points.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    func follow() async {
        speed = await player.speed
        isPlaying = await player.isPlaying
        hasFinished = false

        for await location in player.locations() {
            currentCoordinate = location.coordinate
            // A looping replay starts over after the last point, and so does the count.
            pointIndex = pointIndex % pointCount + 1
        }

        // Cancelling the view's task ends the stream too, but then the view is gone or restarting.
        if !Task.isCancelled {
            hasFinished = true
        }
    }

    func togglePlay() async {
        if hasFinished {
            // A finished stream delivers nothing more, so playing again means starting over.
            await restart()
        } else if isPlaying {
            isPlaying = false
            await player.pause()
        } else {
            isPlaying = true
            await player.play()
        }
    }

    func setSpeed(_ speed: Double) async {
        self.speed = speed
        await player.setSpeed(speed)
    }

    func restart() async {
        await player.stop()
        await player.play()
        // The first point is sent only after play() returns, so it is counted after this reset.
        isPlaying = true
        hasFinished = false
        pointIndex = 0
        subscription += 1
    }
}
