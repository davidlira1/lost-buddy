//
//  TrackerLocation.swift
//  LostBuddy
//
//  Created by David Lira on 10/16/26.
//

import Foundation

struct TrackerLocation: Equatable {
    var coordinate: GeoCoordinate
    var trackerID: String
    var timestamp: Date
}

/// A transport payload before coordinate and freshness checks.
struct TrackerLocationCandidate: Equatable {
    var latitude: Double
    var longitude: Double
    var trackerID: String
    var timestamp: Date
}

enum TrackerLinkState: Equatable {
    case disconnected
    case connecting
    case connected
}

enum TrackerConnectionEvent: Equatable {
    case link(TrackerLinkState)
    case location(TrackerLocationCandidate)
}

enum TrackerUpdateDecision: Equatable {
    case accept(TrackerLocation)
    case stale(TrackerLocation)
    case malformed
    case outOfOrder
}

enum TrackerLocationValidation {
    /// Same arrival window as a phone GPS fix.
    static let maximumAge: TimeInterval = LocationFixValidation.maximumAge

    static func decide(
        candidate: TrackerLocationCandidate,
        now: Date,
        lastAccepted: Date?
    ) -> TrackerUpdateDecision {
        let trackerID = candidate.trackerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trackerID.isEmpty,
              let coordinate = GeoCoordinate(latitude: candidate.latitude, longitude: candidate.longitude) else {
            return .malformed
        }
        let age = now.timeIntervalSince(candidate.timestamp)
        guard age.isFinite, age >= -1 else { return .malformed }
        let location = TrackerLocation(
            coordinate: coordinate,
            trackerID: trackerID,
            timestamp: candidate.timestamp
        )
        if let lastAccepted, candidate.timestamp <= lastAccepted {
            return .outOfOrder
        }
        guard age <= maximumAge else { return .stale(location) }
        return .accept(location)
    }
}
