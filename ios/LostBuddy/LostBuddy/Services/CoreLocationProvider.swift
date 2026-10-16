//
//  CoreLocationProvider.swift
//  LostBuddy
//
//  Created by David Lira on 10/15/26.
//

import CoreLocation
import Foundation

@MainActor
final class CoreLocationProvider: NSObject, LocationProvider, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private nonisolated let sessions = SensorSessionGate()
    private var continuation: AsyncStream<LocationEvent>.Continuation?

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 5
        #if os(iOS) || os(visionOS)
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = false
        #endif
    }

    func events() -> AsyncStream<LocationEvent> {
        let previous = continuation
        let stream = AsyncStream<LocationEvent> { continuation in
            self.continuation = continuation
        }
        previous?.finish()
        return stream
    }

    func start() {
        guard sessions.begin() != nil else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied:
            continuation?.yield(.unavailable(.authorizationDenied))
        case .restricted:
            continuation?.yield(.unavailable(.authorizationRestricted))
        @unknown default:
            continuation?.yield(.unavailable(.authorizationDenied))
        }
    }

    func stop() {
        let ended = sessions.end()
        if ended {
            manager.stopUpdatingLocation()
        }
        continuation?.finish()
        continuation = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let captured = sessions.current()
        Task { @MainActor in
            guard self.sessions.accepts(captured) else { return }
            self.handleAuthorization(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let captured = sessions.current()
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        let horizontalAccuracy = location.horizontalAccuracy
        let timestamp = location.timestamp
        Task { @MainActor in
            guard self.sessions.accepts(captured) else { return }
            if let coordinate = LocationFixValidation.coordinate(
                latitude: latitude,
                longitude: longitude,
                horizontalAccuracy: horizontalAccuracy,
                timestamp: timestamp,
                now: Date()
            ) {
                self.continuation?.yield(.coordinate(coordinate))
            } else {
                self.continuation?.yield(.unavailable(.inaccurate))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let captured = sessions.current()
        let code = (error as? CLError)?.code
        Task { @MainActor in
            guard self.sessions.accepts(captured) else { return }
            switch code {
            case .denied:
                self.continuation?.yield(.unavailable(.authorizationDenied))
            case .locationUnknown:
                break
            default:
                self.continuation?.yield(.unavailable(.unavailable))
            }
        }
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        guard sessions.accepts(sessions.current()) else { return }
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied:
            manager.stopUpdatingLocation()
            continuation?.yield(.unavailable(.authorizationDenied))
        case .restricted:
            manager.stopUpdatingLocation()
            continuation?.yield(.unavailable(.authorizationRestricted))
        case .notDetermined:
            break
        @unknown default:
            manager.stopUpdatingLocation()
            continuation?.yield(.unavailable(.authorizationDenied))
        }
    }
}
