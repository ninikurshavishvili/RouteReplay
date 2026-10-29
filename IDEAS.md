# Ideas (v2+ parking lot)

Anything not in the v1 scope goes here so v1 can ship.

## Recording
- Background recording: an opt-in `CLBackgroundActivitySession` in `LiveLocationProvider`, plus Background Modes → Location updates in the app. When In Use permission is enough on iOS 17+.
- Pause / resume while recording
- Skip Core Location's cached first location, which can be minutes old (a timestamp from before `start()`)
- Store vertical accuracy in `RoutePoint` (today `makeLocation()` uses horizontal accuracy as a stand-in)

## Formats
- KML import / export
- GeoJSON import / export

## Replay
- Seek to a point
- Smooth interpolation between points

## Testing
- Helpers like "wait until the user reaches X"

## UI
- Recorder screen
- Route list

## Platforms
- Flutter plugin
- watchOS

## Geofencing
- Geofence debugger: draw regions, log enter / exit
