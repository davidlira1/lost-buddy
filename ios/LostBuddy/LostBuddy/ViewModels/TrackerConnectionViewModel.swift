//
//  TrackerConnectionViewModel.swift
//  LostBuddy
//
//  Created by David Lira on 10/16/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class TrackerConnectionViewModel {
    private let provider: any TrackerConnectionProvider
    private let clock: any NavigationClock
    private let freshnessInterval: TimeInterval
    private var streamTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var lastAcceptedAt: Date?
    private(set) var sessionID = 0

    let isSimulated: Bool
    private(set) var linkState: TrackerLinkState = .disconnected
    private(set) var liveLocation: TrackerLocation?
    private(set) var lastKnown: TrackerLocation?

    var liveCoordinate: GeoCoordinate? {
        liveLocation?.coordinate
    }

    var badgeLabel: String {
        switch linkState {
        case .disconnected:
            "Disconnected"
        case .connecting:
            isSimulated ? "Sim · Connecting" : "Connecting"
        case .connected:
            isSimulated ? "Sim · Connected" : "Connected"
        }
    }

    var lastUpdateValue: String {
        guard let lastKnown else { return "No telemetry" }
        guard liveLocation != nil else { return "Stale" }
        return lastKnown.timestamp.formatted(date: .omitted, time: .shortened)
    }

    /// Caption for a simulated session, or for a last-known fix that is no longer live.
    var statusCaption: String? {
        if liveLocation == nil, lastKnown != nil {
            return "Last known tracker location is out of date"
        }
        if isSimulated {
            return "Simulated tracker. Not hardware."
        }
        return nil
    }

    init(
        provider: any TrackerConnectionProvider,
        clock: any NavigationClock = SystemNavigationClock(),
        freshnessInterval: TimeInterval = TrackerLocationValidation.maximumAge
    ) {
        self.provider = provider
        self.clock = clock
        self.freshnessInterval = freshnessInterval
        self.isSimulated = provider.isSimulated
    }

    func start() {
        expireStaleFixIfNeeded()
        guard streamTask == nil else {
            if liveLocation != nil {
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
        if liveLocation != nil {
            scheduleFreshnessExpiry()
        }
    }

    func stop() {
        cancelFreshnessExpiry()
        let hadStream = streamTask != nil
        sessionID &+= 1
        streamTask?.cancel()
        streamTask = nil
        provider.stop()
        if hadStream || linkState != .disconnected || liveLocation != nil {
            linkState = .disconnected
            retireLiveFix()
        }
    }

    func sceneDidEnterBackground() {
        cancelFreshnessExpiry()
    }

    func sceneDidBecomeActive() {
        expireStaleFixIfNeeded()
        if liveLocation != nil {
            scheduleFreshnessExpiry()
        }
    }

    func expireStaleFixIfNeeded() {
        guard let location = liveLocation else { return }
        guard clock.now.timeIntervalSince(location.timestamp) >= freshnessInterval else { return }
        liveLocation = nil
        cancelFreshnessExpiry()
    }

    func consume(_ event: TrackerConnectionEvent, fromSession session: Int) {
        guard session == sessionID else { return }
        apply(event)
    }

    func apply(_ event: TrackerConnectionEvent) {
        switch event {
        case .link(let state):
            linkState = state
            if state != .connected {
                retireLiveFix()
            }
        case .location(let candidate):
            switch TrackerLocationValidation.decide(
                candidate: candidate,
                now: clock.now,
                lastAccepted: lastAcceptedAt
            ) {
            case .accept(let location):
                lastAcceptedAt = location.timestamp
                liveLocation = location
                lastKnown = location
                scheduleFreshnessExpiry()
            case .stale(let location):
                guard liveLocation == nil else { return }
                lastAcceptedAt = location.timestamp
                lastKnown = location
                cancelFreshnessExpiry()
            case .malformed, .outOfOrder:
                break
            }
        }
    }

    private func retireLiveFix() {
        liveLocation = nil
        cancelFreshnessExpiry()
    }

    private func scheduleFreshnessExpiry() {
        expiryTask?.cancel()
        guard let location = liveLocation else { return }
        let remaining = freshnessInterval - clock.now.timeIntervalSince(location.timestamp)
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
