//
//  NavigationState.swift
//  LostBuddy
//
//  Created by David Lira on 10/15/26.
//

import Foundation

enum LocationStatus: Equatable {
    case searching
    case fix
    case denied
    case restricted
    case unavailable
    case inaccurate
    case stale

    var phoneGPSValue: String {
        switch self {
        case .searching:
            "Searching"
        case .fix:
            "Fix"
        case .denied:
            "Denied"
        case .restricted, .unavailable, .inaccurate, .stale:
            "Unavailable"
        }
    }

    /// Caption for states that should replace the mock-data note. Nil while searching or fixed.
    var statusCaption: String? {
        switch self {
        case .searching, .fix:
            nil
        case .denied:
            "Location permission denied"
        case .restricted:
            "Location permission restricted"
        case .unavailable:
            "Location unavailable"
        case .inaccurate:
            "Phone location is not accurate enough"
        case .stale:
            "Phone location is out of date"
        }
    }
}

protocol NavigationClock: AnyObject {
    var now: Date { get }
}

final class SystemNavigationClock: NavigationClock {
    var now: Date { Date() }
}

final class ManualNavigationClock: NavigationClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}

enum LocationUnavailableReason: Equatable {
    case authorizationDenied
    case authorizationRestricted
    case unavailable
    case inaccurate

    var status: LocationStatus {
        switch self {
        case .authorizationDenied:
            .denied
        case .authorizationRestricted:
            .restricted
        case .unavailable:
            .unavailable
        case .inaccurate:
            .inaccurate
        }
    }
}

enum LocationEvent: Equatable {
    case coordinate(GeoCoordinate)
    case unavailable(LocationUnavailableReason)
}

enum LocationFixValidation {
    static let maximumHorizontalAccuracyMeters = 100.0
    static let maximumAge: TimeInterval = 30

    static func coordinate(
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double,
        timestamp: Date,
        now: Date
    ) -> GeoCoordinate? {
        guard horizontalAccuracy.isFinite,
              horizontalAccuracy >= 0,
              horizontalAccuracy <= maximumHorizontalAccuracyMeters else {
            return nil
        }
        let age = now.timeIntervalSince(timestamp)
        guard age.isFinite, age >= -1, age <= maximumAge else { return nil }
        return GeoCoordinate(latitude: latitude, longitude: longitude)
    }
}

enum DistanceFormat {
    static func display(meters: Double?) -> String {
        guard let meters, meters.isFinite, meters >= 0 else { return "Searching" }
        if meters < 1_000 {
            return "\(Int(meters.rounded())) m"
        }
        return String(format: "%.1f km", meters / 1_000)
    }
}
