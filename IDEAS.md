# Ideas (v2+ parking lot)

Anything not in the v1 scope goes here so v1 can ship.

## Recording
- Background recording (needs `NSLocationAlwaysAndWhenInUseUsageDescription` + Background Modes → Location updates)
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
