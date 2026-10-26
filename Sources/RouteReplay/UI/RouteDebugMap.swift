import MapKit
import SwiftUI

/// A map for watching and controlling a replay: the route as a line, a dot at the current location,
/// and buttons to pause, restart and change the speed.
///
/// Use it in SwiftUI previews and debug screens:
///
/// ```swift
/// #Preview {
///     RouteDebugMap(player: ReplayLocationProvider(route: .sample, speed: 10, loop: true))
/// }
/// ```
///
/// The map listens to the player like any other consumer, so it shares the player's playhead,
/// and its controls move every stream from that player.
public struct RouteDebugMap: View {
    @State private var model: RouteDebugMapModel

    /// Creates a map that follows and controls a replay.
    ///
    /// - Parameter player: The replay to show. The map starts listening when it appears and stops
    ///   when it disappears, which stops the replay if nothing else is listening.
    public init(player: ReplayLocationProvider) {
        _model = State(initialValue: RouteDebugMapModel(player: player))
    }

    public var body: some View {
        Map(initialPosition: .automatic) {
            MapPolyline(coordinates: model.routeCoordinates)
                .stroke(.blue, lineWidth: 4)

            if let coordinate = model.currentCoordinate {
                Annotation("Current location", coordinate: coordinate) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(radius: 2)
                }
                .annotationTitles(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom) {
            controls
        }
        .task(id: model.subscription) {
            await model.follow()
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                Task { await model.togglePlay() }
            } label: {
                if model.isPlaying && !model.hasFinished {
                    Label("Pause", systemImage: "pause.fill")
                } else {
                    Label("Play", systemImage: "play.fill")
                }
            }
            .frame(width: 24)

            Button {
                Task { await model.restart() }
            } label: {
                Label("Restart", systemImage: "backward.end.fill")
            }

            Picker("Speed", selection: speedSelection) {
                ForEach(RouteDebugMapModel.speeds, id: \.self) { speed in
                    Text("\(speed, format: .number)x").tag(speed)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // The widest count reserves the space, so the picker doesn't shift as the count grows.
            Text("\(model.pointCount) / \(model.pointCount)")
                .hidden()
                .overlay(alignment: .trailing) {
                    Text("\(model.pointIndex) / \(model.pointCount)")
                }
                .monospacedDigit()
        }
        .labelStyle(.iconOnly)
        .padding()
        .background(.regularMaterial)
    }

    private var speedSelection: Binding<Double> {
        Binding {
            model.speed
        } set: { speed in
            Task { await model.setSpeed(speed) }
        }
    }
}

#Preview {
    RouteDebugMap(player: ReplayLocationProvider(route: .sample, speed: 10, loop: true))
}
