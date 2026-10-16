//
//  CoreLocationHeadingProvider.swift
//  LostBuddy
//
//  Created by David Lira on 10/15/26.
//

import CoreLocation
import Foundation

/// Tracks one sensor session so a callback captured earlier cannot publish into a later one.
final class SensorSessionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var identifier = 0
    private var running = false

    /// Starts a session. Returns nil when a session is already running.
    func begin() -> Int? {
        lock.lock()
        defer { lock.unlock() }
        guard !running else { return nil }
        running = true
        identifier += 1
        return identifier
    }

    /// Ends the current session. Returns false when no session is running.
    @discardableResult
    func end() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard running else { return false }
        running = false
        identifier += 1
        return true
    }

    func current() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return identifier
    }

    func accepts(_ captured: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return running && captured == identifier
    }
}

@MainActor
final class CoreLocationHeadingProvider: NSObject, HeadingProvider, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private nonisolated let sessions = SensorSessionGate()
    private var continuation: AsyncStream<HeadingEvent>.Continuation?

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.headingFilter = 1
    }

    func events() -> AsyncStream<HeadingEvent> {
        let previous = continuation
        let stream = AsyncStream<HeadingEvent> { continuation in
            self.continuation = continuation
        }
        previous?.finish()
        return stream
    }

    func start() {
        guard sessions.begin() != nil else { return }
        guard CLLocationManager.headingAvailable() else {
            sessions.end()
            continuation?.yield(.unavailable(.sensorUnavailable))
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingHeading()
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
            stopHeadingUpdates()
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

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let captured = sessions.current()
        let trueHeading = newHeading.trueHeading
        let magneticHeading = newHeading.magneticHeading
        let accuracy = newHeading.headingAccuracy
        Task { @MainActor in
            guard self.sessions.accepts(captured) else { return }
            guard let reading = HeadingSelection.select(
                trueHeading: trueHeading,
                magneticHeading: magneticHeading,
                accuracy: accuracy
            ) else {
                return
            }
            self.continuation?.yield(.heading(reading))
        }
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        guard sessions.accepts(sessions.current()) else { return }
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingHeading()
        case .denied:
            stopHeadingUpdates()
            continuation?.yield(.unavailable(.authorizationDenied))
        case .restricted:
            stopHeadingUpdates()
            continuation?.yield(.unavailable(.authorizationRestricted))
        case .notDetermined:
            break
        @unknown default:
            stopHeadingUpdates()
            continuation?.yield(.unavailable(.authorizationDenied))
        }
    }

    /// `stopUpdatingHeading()` is unavailable on macOS. This target also builds for Mac.
    private func stopHeadingUpdates() {
        #if os(iOS) || os(visionOS)
        manager.stopUpdatingHeading()
        #endif
    }
}
