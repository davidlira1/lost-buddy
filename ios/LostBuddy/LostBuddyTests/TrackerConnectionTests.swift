//
//  TrackerConnectionTests.swift
//  LostBuddyTests
//
//  Created by David Lira on 10/16/26.
//

import Foundation
import Testing
@testable import LostBuddy

struct TrackerConnectionTests {
    private let now = Date(timeIntervalSince1970: 10_000)

    @Test func acceptsAFreshInOrderCoordinate() {
        let decision = TrackerLocationValidation.decide(
            candidate: candidate(timestamp: now),
            now: now,
            lastAccepted: nil
        )
        guard case .accept(let location) = decision else {
            #expect(Bool(false))
            return
        }
        #expect(location.coordinate.latitude == 1)
        #expect(location.coordinate.longitude == 2)
        #expect(location.trackerID == "tracker-1")
        #expect(location.timestamp == now)
    }

    @Test func rejectsMalformedCoordinatesAndBlankIdentifiers() {
        #expect(rejected(candidate(latitude: 91, timestamp: now)) == .malformed)
        #expect(rejected(candidate(longitude: .nan, timestamp: now)) == .malformed)
        #expect(rejected(candidate(trackerID: "   ", timestamp: now)) == .malformed)
        #expect(rejected(candidate(timestamp: now.addingTimeInterval(5))) == .malformed)
    }

    @Test func rejectsStaleAndOutOfOrderUpdates() {
        let stale = TrackerLocationValidation.decide(
            candidate: candidate(timestamp: now.addingTimeInterval(-31)),
            now: now,
            lastAccepted: nil
        )
        guard case .stale(let location) = stale else {
            #expect(Bool(false))
            return
        }
        #expect(location.coordinate.latitude == 1)

        let decision = TrackerLocationValidation.decide(
            candidate: candidate(timestamp: now.addingTimeInterval(-5)),
            now: now,
            lastAccepted: now
        )
        #expect(decision == .outOfOrder)
    }

    @Test @MainActor func sessionPublishesConnectionAndLiveLocation() async {
        let provider = ManualTrackerConnectionProvider(isSimulated: true)
        let clock = ManualNavigationClock(now: now)
        let model = TrackerConnectionViewModel(provider: provider, clock: clock)
        model.start()
        model.start()
        #expect(provider.startCount == 1)
        #expect(model.badgeLabel == "Disconnected")

        provider.send(.link(.connecting))
        await waitUntil { model.linkState == .connecting }
        #expect(model.badgeLabel == "Sim · Connecting")

        provider.send(.link(.connected))
        await waitUntil { model.linkState == .connected }
        #expect(model.badgeLabel == "Sim · Connected")
        #expect(model.lastUpdateValue == "No telemetry")

        provider.send(.location(candidate(timestamp: now)))
        await waitUntil { model.liveCoordinate != nil }
        #expect(model.liveCoordinate?.latitude == 1)
        #expect(model.liveCoordinate?.longitude == 2)
        #expect(model.lastUpdateValue != "Stale")
        #expect(model.lastUpdateValue != "No telemetry")
        #expect(model.statusCaption == "Simulated tracker. Not hardware.")
        model.stop()
    }

    @Test @MainActor func hardwareLabelsOmitTheSimulationPrefix() async {
        let provider = ManualTrackerConnectionProvider(isSimulated: false)
        let model = TrackerConnectionViewModel(provider: provider)
        model.start()
        provider.send(.link(.connected))
        await waitUntil { model.linkState == .connected }
        #expect(model.badgeLabel == "Connected")
        #expect(model.statusCaption == nil)
        model.stop()
    }

    @Test @MainActor func disconnectAndInvalidUpdatesDoNotStayLive() async {
        let provider = ManualTrackerConnectionProvider(isSimulated: true)
        let clock = ManualNavigationClock(now: now)
        let model = TrackerConnectionViewModel(provider: provider, clock: clock)
        model.start()
        provider.send(.link(.connected))
        provider.send(.location(candidate(timestamp: now)))
        await waitUntil { model.liveCoordinate != nil }

        provider.send(.location(candidate(latitude: 120, timestamp: now.addingTimeInterval(1))))
        provider.send(.location(candidate(timestamp: now.addingTimeInterval(-1))))
        provider.send(.link(.disconnected))
        await waitUntil { model.linkState == .disconnected }
        #expect(model.liveCoordinate == nil)
        #expect(model.lastKnown?.coordinate.latitude == 1)
        #expect(model.lastKnown?.timestamp == now)
        #expect(model.lastUpdateValue == "Stale")
        #expect(model.badgeLabel == "Disconnected")
        #expect(model.statusCaption == "Last known tracker location is out of date")
        model.stop()
    }

    @Test @MainActor func aStaleSampleIsKeptOnlyAsLastKnown() async {
        let provider = ManualTrackerConnectionProvider()
        let clock = ManualNavigationClock(now: now)
        let model = TrackerConnectionViewModel(provider: provider, clock: clock)
        model.start()
        provider.send(.link(.connected))
        provider.send(.location(candidate(timestamp: now.addingTimeInterval(-31))))
        await waitUntil { model.lastKnown != nil }
        #expect(model.liveCoordinate == nil)
        #expect(model.lastUpdateValue == "Stale")
        #expect(model.linkState == .connected)

        provider.send(.location(candidate(latitude: 3, timestamp: now)))
        await waitUntil { model.liveCoordinate?.latitude == 3 }
        #expect(model.lastUpdateValue != "Stale")
        model.stop()
    }

    @Test @MainActor func acceptedTrackerFixExpiresFromTheClock() async {
        let provider = ManualTrackerConnectionProvider()
        let clock = ManualNavigationClock(now: now)
        let model = TrackerConnectionViewModel(provider: provider, clock: clock, freshnessInterval: 30)
        model.start()
        provider.send(.link(.connected))
        provider.send(.location(candidate(timestamp: now)))
        await waitUntil { model.liveCoordinate != nil }

        clock.advance(by: 29)
        model.expireStaleFixIfNeeded()
        #expect(model.liveCoordinate != nil)

        clock.advance(by: 1)
        model.expireStaleFixIfNeeded()
        #expect(model.liveCoordinate == nil)
        #expect(model.lastKnown != nil)
        #expect(model.lastUpdateValue == "Stale")
        #expect(model.linkState == .connected)
        model.stop()
    }

    @Test @MainActor func resumeAfterBackgroundDropsAnExpiredTrackerFix() async {
        let provider = ManualTrackerConnectionProvider()
        let clock = ManualNavigationClock(now: now)
        let model = TrackerConnectionViewModel(provider: provider, clock: clock, freshnessInterval: 30)
        model.start()
        provider.send(.link(.connected))
        provider.send(.location(candidate(timestamp: now)))
        await waitUntil { model.liveCoordinate != nil }

        model.sceneDidEnterBackground()
        clock.advance(by: 10)
        model.sceneDidBecomeActive()
        #expect(model.liveCoordinate != nil)

        model.sceneDidEnterBackground()
        clock.advance(by: 20)
        model.sceneDidBecomeActive()
        #expect(model.liveCoordinate == nil)
        #expect(model.lastUpdateValue == "Stale")
        model.stop()
    }

    @Test @MainActor func stopCancelsAConnectingSession() async {
        let provider = ManualTrackerConnectionProvider(isSimulated: true)
        let model = TrackerConnectionViewModel(provider: provider)
        model.start()
        provider.send(.link(.connecting))
        await waitUntil { model.linkState == .connecting }

        let staleSession = model.sessionID
        model.stop()
        model.stop()
        #expect(provider.stopCount == 1)
        #expect(provider.isRunning == false)
        #expect(model.linkState == .disconnected)
        #expect(model.badgeLabel == "Disconnected")

        model.consume(.link(.connected), fromSession: staleSession)
        provider.send(.link(.connected))
        await Task.yield()
        #expect(model.linkState == .disconnected)
        #expect(model.liveCoordinate == nil)
    }

    @Test @MainActor func simulatedProviderConnectsPublishesAndDisconnects() async {
        let origin = GeoCoordinate(latitude: 37.8199, longitude: -122.4783)!
        let provider = SimulatedTrackerProvider(
            script: SimulatedTrackerScript(
                connectDelay: .milliseconds(1),
                updateInterval: .milliseconds(1),
                stepMeters: 40,
                updateCountBeforeDisconnect: 1,
                origin: origin
            )
        )
        #expect(provider.isSimulated)
        let stream = provider.events()
        provider.start()

        var events: [TrackerConnectionEvent] = []
        var iterator = stream.makeAsyncIterator()
        while events.count < 4 {
            guard let event = await iterator.next() else { break }
            events.append(event)
        }
        provider.stop()

        #expect(events.count == 4)
        #expect(events.first == .link(.connecting))
        #expect(events.dropFirst().first == .link(.connected))
        if events.count > 2, case .location(let candidate) = events[2] {
            #expect(candidate.latitude == origin.latitude)
            #expect(candidate.longitude == origin.longitude)
            #expect(candidate.trackerID == "simulated-lost-buddy")
        } else {
            #expect(Bool(false))
        }
        #expect(events.last == .link(.disconnected))
    }

    private func candidate(
        latitude: Double = 1,
        longitude: Double = 2,
        trackerID: String = "tracker-1",
        timestamp: Date
    ) -> TrackerLocationCandidate {
        TrackerLocationCandidate(
            latitude: latitude,
            longitude: longitude,
            trackerID: trackerID,
            timestamp: timestamp
        )
    }

    private func rejected(_ candidate: TrackerLocationCandidate) -> TrackerUpdateDecision {
        TrackerLocationValidation.decide(candidate: candidate, now: now, lastAccepted: nil)
    }

    @MainActor
    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() && clock.now < deadline {
            await Task.yield()
        }
    }
}
