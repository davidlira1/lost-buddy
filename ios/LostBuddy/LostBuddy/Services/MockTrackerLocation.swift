//
//  MockTrackerLocation.swift
//  LostBuddy
//
//  Created by David Lira on 10/15/26.
//

import Foundation

/// Simulated tracker position. This is not a live BLE or LoRa fix.
enum MockTrackerFixture {
    /// Golden Gate Bridge. Far from a typical desk test.
    case goldenGateBridge
    /// A short walk from the bridge fixture. Replace this coordinate with a point near your test site.
    case nearbyWalk
}

enum MockTrackerLocation {
    /// Switch to `.nearbyWalk` and edit that coordinate before a field walk.
    static let activeFixture: MockTrackerFixture = .goldenGateBridge

    static var coordinate: GeoCoordinate {
        fixture(activeFixture)
    }

    static func fixture(_ fixture: MockTrackerFixture) -> GeoCoordinate {
        switch fixture {
        case .goldenGateBridge:
            GeoCoordinate(latitude: 37.8199, longitude: -122.4783)!
        case .nearbyWalk:
            // About 250 m east of the Golden Gate fixture.
            GeoCoordinate(latitude: 37.8199, longitude: -122.4754)!
        }
    }
}
