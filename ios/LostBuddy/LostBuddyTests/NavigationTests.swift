//
//  NavigationTests.swift
//  LostBuddyTests
//
//  Created by David Lira on 10/15/26.
//

import Foundation
import Testing
@testable import LostBuddy

struct NavigationTests {
    private let origin = GeoCoordinate(latitude: 0, longitude: 0)!
    private let oneDegreeNorth = GeoCoordinate(latitude: 1, longitude: 0)!
    private let oneDegreeSouth = GeoCoordinate(latitude: -1, longitude: 0)!
    private let oneDegreeEast = GeoCoordinate(latitude: 0, longitude: 1)!
    private let oneDegreeWest = GeoCoordinate(latitude: 0, longitude: -1)!

    @Test func acceptsCoordinatesInsideRange() {
        #expect(GeoCoordinate(latitude: 0, longitude: 0) != nil)
        #expect(GeoCoordinate(latitude: 90, longitude: 180) != nil)
        #expect(GeoCoordinate(latitude: -90, longitude: -180) != nil)
        #expect(GeoCoordinate(latitude: 37.8199, longitude: -122.4783) != nil)
    }

    @Test func rejectsOutOfRangeCoordinates() {
        #expect(GeoCoordinate(latitude: 90.0001, longitude: 0) == nil)
        #expect(GeoCoordinate(latitude: -90.0001, longitude: 0) == nil)
        #expect(GeoCoordinate(latitude: 0, longitude: 180.0001) == nil)
        #expect(GeoCoordinate(latitude: 0, longitude: -180.0001) == nil)
        #expect(GeoCoordinate(latitude: .nan, longitude: 0) == nil)
        #expect(GeoCoordinate(latitude: 0, longitude: .infinity) == nil)
    }

    @Test func distanceIsZeroForIdenticalCoordinatesAndSymmetric() {
        #expect(NavigationCalculator.distanceMeters(from: origin, to: origin) == 0)
        let northbound = NavigationCalculator.distanceMeters(from: origin, to: oneDegreeNorth)
        let southbound = NavigationCalculator.distanceMeters(from: oneDegreeNorth, to: origin)
        #expect(abs(northbound - southbound) < 0.001)
        let expected = NavigationCalculator.earthRadiusMeters * .pi / 180
        #expect(abs(northbound - expected) < 1)
    }

    @Test func bearingFollowsCardinalDirections() {
        expectAngle(NavigationCalculator.bearingDegrees(from: origin, to: oneDegreeNorth), 0)
        expectAngle(NavigationCalculator.bearingDegrees(from: origin, to: oneDegreeEast), 90)
        expectAngle(NavigationCalculator.bearingDegrees(from: origin, to: oneDegreeSouth), 180)
        expectAngle(NavigationCalculator.bearingDegrees(from: origin, to: oneDegreeWest), 270)
    }

    @Test func bearingIsNormalizedAndUndefinedWhenPointsCoincide() {
        let almostEast = GeoCoordinate(latitude: 0, longitude: 0.000001)!
        #expect(NavigationCalculator.bearingDegrees(from: origin, to: origin) == nil)
        #expect(NavigationCalculator.bearingDegrees(from: origin, to: almostEast) == nil)

        let wrapped = NavigationCalculator.bearingDegrees(
            from: GeoCoordinate(latitude: 10, longitude: 170)!,
            to: GeoCoordinate(latitude: 10, longitude: -170)!
        )
        #expect(wrapped != nil)
        if let value = wrapped {
            #expect(value >= 0)
            #expect(value < 360)
        }
    }

    @Test func longitudeWrapUsesTheShortArc() {
        let westOfDateline = GeoCoordinate(latitude: 0, longitude: 179)!
        let eastOfDateline = GeoCoordinate(latitude: 0, longitude: -179)!
        let distance = NavigationCalculator.distanceMeters(from: westOfDateline, to: eastOfDateline)
        let twoDegrees = 2 * NavigationCalculator.earthRadiusMeters * .pi / 180
        #expect(abs(distance - twoDegrees) < 1)
        expectAngle(NavigationCalculator.bearingDegrees(from: westOfDateline, to: eastOfDateline), 90)
        #expect(NavigationCalculator.distanceMeters(from: GeoCoordinate(latitude: 89.9, longitude: 10)!, to: GeoCoordinate(latitude: 89.9, longitude: 20)!).isFinite)
    }

    @Test func formatsDistanceInMetersOrKilometers() {
        #expect(DistanceFormat.display(meters: nil) == "Searching")
        #expect(DistanceFormat.display(meters: 248.4) == "248 m")
        #expect(DistanceFormat.display(meters: 999) == "999 m")
        #expect(DistanceFormat.display(meters: 1_000) == "1.0 km")
        #expect(DistanceFormat.display(meters: 1_500) == "1.5 km")
    }

    @Test func rejectsInaccurateOrStaleFixes() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(
            LocationFixValidation.coordinate(
                latitude: 10, longitude: 20, horizontalAccuracy: 15,
                timestamp: now.addingTimeInterval(-5), now: now
            ) == GeoCoordinate(latitude: 10, longitude: 20)
        )
        #expect(
            LocationFixValidation.coordinate(
                latitude: 10, longitude: 20, horizontalAccuracy: -1,
                timestamp: now, now: now
            ) == nil
        )
        #expect(
            LocationFixValidation.coordinate(
                latitude: 10, longitude: 20, horizontalAccuracy: 150,
                timestamp: now, now: now
            ) == nil
        )
        #expect(
            LocationFixValidation.coordinate(
                latitude: 10, longitude: 20, horizontalAccuracy: 10,
                timestamp: now.addingTimeInterval(-31), now: now
            ) == nil
        )
        #expect(
            LocationFixValidation.coordinate(
                latitude: 91, longitude: 20, horizontalAccuracy: 10,
                timestamp: now, now: now
            ) == nil
        )
    }

    @Test func mockTrackerFixturesStayInOneConfiguration() {
        #expect(MockTrackerLocation.activeFixture == .goldenGateBridge)
        #expect(MockTrackerLocation.coordinate == MockTrackerLocation.fixture(.goldenGateBridge))
        #expect(MockTrackerLocation.coordinate.latitude == 37.8199)
        #expect(MockTrackerLocation.coordinate.longitude == -122.4783)

        let nearby = MockTrackerLocation.fixture(.nearbyWalk)
        let bridge = MockTrackerLocation.fixture(.goldenGateBridge)
        #expect(nearby != bridge)
        let walk = NavigationCalculator.distanceMeters(from: nearby, to: bridge)
        #expect(walk > 100)
        #expect(walk < 500)
    }

    @Test @MainActor func locationUpdatesRecalculateDistanceAndBearing() async {
        let provider = ManualLocationProvider()
        let tracker = origin
        let model = NavigationViewModel(provider: provider, tracker: tracker)

        model.start()
        model.start()
        #expect(provider.startCount == 1)

        provider.send(.coordinate(oneDegreeNorth))
        await waitUntil { model.distanceMeters != nil }
        let expectedDistance = NavigationCalculator.distanceMeters(from: oneDegreeNorth, to: tracker)
        #expect(abs((model.distanceMeters ?? -1) - expectedDistance) < 0.001)
        expectAngle(model.bearingDegrees, 180)
        #expect(model.locationStatus == .fix)
        #expect(model.phoneGPSValue == "Fix")
        #expect(model.formattedDistance.contains("km"))

        provider.send(.unavailable(.authorizationDenied))
        await waitUntil { model.locationStatus == .denied }
        #expect(model.distanceMeters == nil)
        #expect(model.bearingDegrees == nil)
        #expect(model.phoneGPSValue == "Denied")
        #expect(model.formattedDistance == "Searching")

        model.stop()
        model.stop()
        #expect(provider.stopCount == 1)
        #expect(provider.isRunning == false)

        provider.send(.coordinate(oneDegreeEast))
        await Task.yield()
        #expect(model.distanceMeters == nil)

        let staleSession = model.sessionID
        model.start()
        #expect(provider.startCount == 2)
        model.consume(.coordinate(oneDegreeEast), fromSession: staleSession)
        #expect(model.bearingDegrees == nil)

        provider.send(.coordinate(oneDegreeEast))
        await waitUntil { model.bearingDegrees != nil }
        expectAngle(model.bearingDegrees, 270)
        model.stop()
    }

    @Test @MainActor func coincidentFixClearsDirectionButKeepsZeroDistance() async {
        let provider = ManualLocationProvider()
        let model = NavigationViewModel(provider: provider, tracker: origin)
        model.start()
        provider.send(.coordinate(origin))
        await waitUntil { model.locationStatus == .fix }
        #expect(model.distanceMeters == 0)
        #expect(model.bearingDegrees == nil)
        #expect(model.formattedDistance == "0 m")
        model.stop()
    }

    @Test @MainActor func acceptedFixExpiresFromTheInjectableClock() async {
        let provider = ManualLocationProvider()
        let clock = ManualNavigationClock(now: Date(timeIntervalSince1970: 1_000))
        let model = NavigationViewModel(
            provider: provider,
            tracker: origin,
            clock: clock,
            freshnessInterval: 30
        )
        model.start()
        provider.send(.coordinate(oneDegreeNorth))
        await waitUntil { model.locationStatus == .fix }

        clock.advance(by: 29)
        model.expireStaleFixIfNeeded()
        #expect(model.locationStatus == .fix)
        #expect(model.distanceMeters != nil)

        clock.advance(by: 1)
        model.expireStaleFixIfNeeded()
        #expect(model.locationStatus == .stale)
        #expect(model.distanceMeters == nil)
        #expect(model.bearingDegrees == nil)
        #expect(model.phoneGPSValue == "Unavailable")
        #expect(model.statusCaption == "Phone location is out of date")
        model.stop()
    }

    @Test @MainActor func resumeAfterBackgroundDropsAnExpiredFix() async {
        let provider = ManualLocationProvider()
        let clock = ManualNavigationClock(now: Date(timeIntervalSince1970: 5_000))
        let model = NavigationViewModel(
            provider: provider,
            tracker: origin,
            clock: clock,
            freshnessInterval: 30
        )
        model.start()
        provider.send(.coordinate(oneDegreeEast))
        await waitUntil { model.locationStatus == .fix }

        model.sceneDidEnterBackground()
        clock.advance(by: 10)
        model.sceneDidBecomeActive()
        #expect(model.locationStatus == .fix)
        #expect(model.bearingDegrees != nil)

        model.sceneDidEnterBackground()
        clock.advance(by: 30)
        model.sceneDidBecomeActive()
        #expect(model.locationStatus == .stale)
        #expect(model.distanceMeters == nil)
        #expect(model.bearingDegrees == nil)

        provider.send(.coordinate(oneDegreeNorth))
        await waitUntil { model.locationStatus == .fix }
        #expect(model.distanceMeters != nil)
        model.stop()
    }

    @Test @MainActor func aNewerFixResetsTheFreshnessWindow() async {
        let provider = ManualLocationProvider()
        let clock = ManualNavigationClock(now: Date(timeIntervalSince1970: 8_000))
        let model = NavigationViewModel(
            provider: provider,
            tracker: origin,
            clock: clock,
            freshnessInterval: 30
        )
        model.start()
        provider.send(.coordinate(oneDegreeEast))
        await waitUntil { model.locationStatus == .fix }

        clock.advance(by: 20)
        provider.send(.coordinate(oneDegreeNorth))
        await waitUntil {
            guard let bearing = model.bearingDegrees else { return false }
            return abs(bearing - 180) < 0.05
        }
        clock.advance(by: 20)
        model.expireStaleFixIfNeeded()
        #expect(model.locationStatus == .fix)

        clock.advance(by: 10)
        model.expireStaleFixIfNeeded()
        #expect(model.locationStatus == .stale)
        model.stop()
    }

    private func expectAngle(_ actual: Double?, _ expected: Double) {
        #expect(actual != nil)
        guard let actual else { return }
        #expect(abs(CompassRotation.shortestDelta(from: actual, to: expected)) < 0.05)
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
