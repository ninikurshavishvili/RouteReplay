# ``RouteReplay``

Record a real GPS route once, then replay it as live location in the simulator, in SwiftUI previews and in unit tests.

## Overview

Your code reads locations from a ``LocationProvider``. In the app that's ``LiveLocationProvider``, real GPS from Core Location. Everywhere else it's ``ReplayLocationProvider``, which plays a ``RecordedRoute`` back with its recorded timing, at any speed. The code that uses the locations is the same in both cases.

Record routes on a device with ``RouteRecorder``, save them as JSON or GPX, and watch a replay with ``RouteDebugMap``. ``RecordedRoute/sample`` is a walk in Tbilisi that ships with the package, for previews and demos.

## Topics

### Essentials

- <doc:GettingStarted>

### Providers

- ``LocationProvider``
- ``LiveLocationProvider``
- ``ReplayLocationProvider``

### Recording

- ``RouteRecorder``

### Routes and files

- ``RecordedRoute``
- ``RoutePoint``
- ``RouteFileFormat``
- ``RouteFileError``

### Debug UI

- ``RouteDebugMap``
