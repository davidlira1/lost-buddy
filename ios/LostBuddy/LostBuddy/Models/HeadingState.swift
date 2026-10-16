//
//  HeadingState.swift
//  LostBuddy
//
//  Created by David Lira on 10/15/26.
//

import Foundation

enum HeadingUnavailableReason: Equatable {
    case sensorUnavailable
    case authorizationDenied
    case authorizationRestricted

    var message: String {
        switch self {
        case .sensorUnavailable:
            "Compass unavailable"
        case .authorizationDenied:
            "Heading permission denied"
        case .authorizationRestricted:
            "Heading permission restricted"
        }
    }
}

enum NorthReference: Equatable {
    case geographic
    case magnetic
}

struct SelectedHeading: Equatable {
    var degrees: Double
    var north: NorthReference
}

enum HeadingEvent: Equatable {
    case heading(SelectedHeading)
    case unavailable(HeadingUnavailableReason)
}

enum CompassRotation {
    /// Degrees in `[0, 360)`.
    static func normalized(_ degrees: Double) -> Double {
        guard degrees.isFinite else { return 0 }
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        if remainder < 0 {
            return remainder + 360
        }
        return remainder == 360 ? 0 : remainder
    }

    /// Shortest signed step from `from` to `to`, in `(-180, 180]`.
    static func shortestDelta(from: Double, to: Double) -> Double {
        var delta = normalized(to - from)
        if delta > 180 {
            delta -= 360
        }
        return delta
    }

    /// Moves `previous` toward `target` by the shortest signed delta.
    static func continueRotation(previous: Double, target: Double) -> Double {
        previous + shortestDelta(from: previous, to: target)
    }

    static func dialTarget(phoneHeading: Double) -> Double {
        -phoneHeading
    }

    static func arrowTarget(targetBearing: Double, phoneHeading: Double) -> Double {
        targetBearing - phoneHeading
    }
}

enum HeadingSelection {
    /// Prefers a valid true heading. An invalid true heading still allows a valid magnetic fallback.
    static func select(trueHeading: Double, magneticHeading: Double, accuracy: Double) -> SelectedHeading? {
        guard accuracy.isFinite, accuracy >= 0 else { return nil }
        if trueHeading.isFinite, trueHeading >= 0 {
            return SelectedHeading(
                degrees: CompassRotation.normalized(trueHeading),
                north: .geographic
            )
        }
        if magneticHeading.isFinite, magneticHeading >= 0 {
            return SelectedHeading(
                degrees: CompassRotation.normalized(magneticHeading),
                north: .magnetic
            )
        }
        return nil
    }
}
