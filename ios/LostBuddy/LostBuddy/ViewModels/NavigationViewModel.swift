//
//  NavigationViewModel.swift
//  LostBuddy
//
//  Created by David Lira on 10/15/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class NavigationViewModel {
    private let provider: any LocationProvider
    private var tracker: GeoCoordinate?
    private var phoneCoordinate: GeoCoordinate?
    private let clock: any NavigationClock
    private let freshnessInterval: TimeInterval
    private var streamTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var fixAcceptedAt: Date?
    private(set) var sessionID = 0

    private(set) var distanceMeters: Double?
    private(set) var bearingDegrees: Double?
    private(set) var locationStatus: LocationStatus = .searching

    var formattedDistance: String {
        if locationStatus == .fix, phoneCoordinate != nil, tracker == nil {
            return "—"
        }
        return DistanceFormat.display(meters: distanceMeters)
    }

    var phoneGPSValue: String {
        locationStatus.phoneGPSValue
    }

    var statusCaption: String? {
        locationStatus.statusCaption
    }

    init(
        provider: any LocationProvider,
        tracker: GeoCoordinate? = nil,
        clock: any NavigationClock = SystemNavigationClock(),
        freshnessInterval: TimeInterval = LocationFixValidation.maximumAge
    ) {
        self.provider = provider
        self.tracker = tracker
        self.clock = clock
        self.freshnessInterval = freshnessInterval
    }

    func start() {
        expireStaleFixIfNeeded()
        guard streamTask == nil else {
            if locationStatus == .fix {
                scheduleFreshnessExpiry()
            }
            return
        }
        sessionID &+= 1
        let session = sessionID
        let stream = provider.events()
        provider.start()
        streamTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await event in stream {
                if Task.isCancelled || session != self.sessionID {
                    break
                }
                self.consume(event, fromSession: session)
            }
            if session == self.sessionID {
                self.streamTask = nil
            }
        }
        if locationStatus == .fix {
            scheduleFreshnessExpiry()
        }
    }

    func stop() {
        cancelFreshnessExpiry()
        guard streamTask != nil else {
            provider.stop()
            return
        }
        sessionID &+= 1
        streamTask?.cancel()
        streamTask = nil
        provider.stop()
    }

    /// Stops the foreground expiry wait while iOS suspends the app. Does not request background location.
    func sceneDidEnterBackground() {
        cancelFreshnessExpiry()
    }

    /// Drops a fix that aged out while the app was suspended, then waits only for the time still left.
    func sceneDidBecomeActive() {
        expireStaleFixIfNeeded()
        if locationStatus == .fix {
            scheduleFreshnessExpiry()
        }
    }

    func updateTracker(_ coordinate: GeoCoordinate?) {
        tracker = coordinate
        recalculate()
    }

    func expireStaleFixIfNeeded() {
        guard let accepted = fixAcceptedAt else { return }
        guard clock.now.timeIntervalSince(accepted) >= freshnessInterval else { return }
        phoneCoordinate = nil
        distanceMeters = nil
        bearingDegrees = nil
        locationStatus = .stale
        fixAcceptedAt = nil
        cancelFreshnessExpiry()
    }

    func consume(_ event: LocationEvent, fromSession session: Int) {
        guard session == sessionID else { return }
        apply(event)
    }

    func apply(_ event: LocationEvent) {
        switch event {
        case .coordinate(let phone):
            phoneCoordinate = phone
            locationStatus = .fix
            fixAcceptedAt = clock.now
            scheduleFreshnessExpiry()
            recalculate()
        case .unavailable(let reason):
            fixAcceptedAt = nil
            cancelFreshnessExpiry()
            phoneCoordinate = nil
            distanceMeters = nil
            bearingDegrees = nil
            locationStatus = reason.status
        }
    }

    private func recalculate() {
        guard locationStatus == .fix, let phone = phoneCoordinate, let tracker else {
            distanceMeters = nil
            bearingDegrees = nil
            return
        }
        distanceMeters = NavigationCalculator.distanceMeters(from: phone, to: tracker)
        bearingDegrees = NavigationCalculator.bearingDegrees(from: phone, to: tracker)
    }

    private func scheduleFreshnessExpiry() {
        expiryTask?.cancel()
        guard let accepted = fixAcceptedAt else { return }
        let remaining = freshnessInterval - clock.now.timeIntervalSince(accepted)
        expiryTask = Task { @MainActor [weak self] in
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            guard let self, !Task.isCancelled else { return }
            self.expireStaleFixIfNeeded()
        }
    }

    private func cancelFreshnessExpiry() {
        expiryTask?.cancel()
        expiryTask = nil
    }
}
