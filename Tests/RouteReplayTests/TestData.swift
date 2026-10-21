//
//  TestData.swift
//  RouteReplay
//
//  Created by Nini Kurshavishvili on 21/10/2026.
//

import Foundation
import RouteReplay

enum TestData {
    static let start = Date(timeIntervalSince1970: 1_792_576_800)

    static let fullPoint = RoutePoint(
        latitude: 41.6977,
        longitude: 44.7990,
        altitude: 480,
        horizontalAccuracy: 5,
        speed: 1.4,
        course: 90,
        timestamp: start.addingTimeInterval(0.5)
    )

    static let barePoint = RoutePoint(
        latitude: 41.6981,
        longitude: 44.7995,
        horizontalAccuracy: 8,
        timestamp: start.addingTimeInterval(4.5)
    )

    static let route = RecordedRoute(
        name: "Rustaveli walk",
        recordedAt: start,
        points: [
            fullPoint,
            barePoint,
            RoutePoint(
                latitude: 41.6986,
                longitude: 44.8001,
                altitude: 482.5,
                horizontalAccuracy: 6,
                speed: 1.6,
                course: 45.5,
                timestamp: start.addingTimeInterval(9.25)
            ),
        ]
    )
}
