//
//  MockTrackerLocation.swift
//  LostBuddy
//
//  Created by David Lira on 10/15/26.
//

import Foundation

/// Origin for the simulated tracker path. This is not a live BLE or LoRa fix.
/// Navigation follows tracker connection updates rather than reading this coordinate directly.
enum MockTrackerFixture {
    /// Golden Gate Bridge. Far from a typical desk test.
    case goldenGateBridge
    /// Queen Mary, Long Beach. The default simulated path origin.
    case nearbyWalk
}

enum MockTrackerLocation {
    /// Queen Mary is the default simulated origin. Switch to `.goldenGateBridge` for the bridge fixture.
    static let activeFixture: MockTrackerFixture = .nearbyWalk

    static var coordinate: GeoCoordinate {
        fixture(activeFixture)
    }

    static func fixture(_ fixture: MockTrackerFixture) -> GeoCoordinate {
        switch fixture {
        case .goldenGateBridge:
            GeoCoordinate(latitude: 37.8199, longitude: -122.4783)!
        case .nearbyWalk:
            // Queen Mary
            GeoCoordinate(latitude: 33.7527, longitude: -118.1898)!
        }
    }
}
