//
//  NavigationCalculator.swift
//  LostBuddy
//
//  Created by David Lira on 10/15/26.
//

import Foundation

enum NavigationCalculator {
    /// Mean Earth radius used by the haversine distance.
    static let earthRadiusMeters = 6_371_000.0
    /// Bearings are undefined when the points are effectively the same place.
    static let coincidentDistanceMeters = 1.0

    static func distanceMeters(from start: GeoCoordinate, to end: GeoCoordinate) -> Double {
        let lat1 = degreesToRadians(start.latitude)
        let lat2 = degreesToRadians(end.latitude)
        let deltaLatitude = degreesToRadians(end.latitude - start.latitude)
        let deltaLongitude = degreesToRadians(end.longitude - start.longitude)

        let haversine = sin(deltaLatitude / 2) * sin(deltaLatitude / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLongitude / 2) * sin(deltaLongitude / 2)
        let centralAngle = 2 * atan2(sqrt(haversine), sqrt(max(0, 1 - haversine)))
        let distance = earthRadiusMeters * centralAngle
        guard distance.isFinite else { return 0 }
        return max(0, distance)
    }

    /// Initial great-circle bearing, clockwise from true north. Nil when the points coincide.
    static func bearingDegrees(from start: GeoCoordinate, to end: GeoCoordinate) -> Double? {
        guard distanceMeters(from: start, to: end) >= coincidentDistanceMeters else { return nil }

        let lat1 = degreesToRadians(start.latitude)
        let lat2 = degreesToRadians(end.latitude)
        let deltaLongitude = degreesToRadians(end.longitude - start.longitude)
        let eastComponent = sin(deltaLongitude) * cos(lat2)
        let northComponent = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLongitude)
        let degrees = atan2(eastComponent, northComponent) * 180 / .pi
        return CompassRotation.normalized(degrees)
    }

    private static func degreesToRadians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }
}
