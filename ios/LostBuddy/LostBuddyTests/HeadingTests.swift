//
//  HeadingTests.swift
//  LostBuddyTests
//
//  Created by David Lira on 10/15/26.
//

import Testing
@testable import LostBuddy

struct HeadingTests {
    @Test func normalizesDegreesIncludingNegatives() {
        #expect(CompassRotation.normalized(370) == 10)
        #expect(CompassRotation.normalized(-10) == 350)
        #expect(CompassRotation.normalized(360) == 0)
        #expect(CompassRotation.normalized(-360) == 0)
        #expect(CompassRotation.normalized(0) == 0)
    }

    @Test func dialRotationIsNegativePhoneHeading() {
        #expect(CompassRotation.dialTarget(phoneHeading: 0) == 0)
        #expect(CompassRotation.dialTarget(phoneHeading: 90) == -90)
        #expect(CompassRotation.dialTarget(phoneHeading: 359) == -359)
    }

    @Test func arrowRotationIsTargetMinusPhoneHeading() {
        #expect(CompassRotation.arrowTarget(targetBearing: 315, phoneHeading: 0) == 315)
        #expect(CompassRotation.arrowTarget(targetBearing: 315, phoneHeading: 90) == 225)
        #expect(CompassRotation.arrowTarget(targetBearing: 315, phoneHeading: 10) == 305)
    }

    @Test func shortestPathWrapsAcrossNorth() {
        #expect(CompassRotation.shortestDelta(from: 359, to: 1) == 2)
        #expect(CompassRotation.shortestDelta(from: 1, to: 359) == -2)
        #expect(CompassRotation.continueRotation(previous: -359, target: -1) == -361)
        #expect(CompassRotation.continueRotation(previous: -1, target: -359) == 1)
    }

    @Test func prefersTrueHeadingAndFallsBackToMagnetic() {
        #expect(
            HeadingSelection.select(trueHeading: 12, magneticHeading: 20, accuracy: 5)
                == SelectedHeading(degrees: 12, north: .geographic)
        )
        #expect(
            HeadingSelection.select(trueHeading: -1, magneticHeading: 20, accuracy: 5)
                == SelectedHeading(degrees: 20, north: .magnetic)
        )
        #expect(
            HeadingSelection.select(trueHeading: .nan, magneticHeading: 33, accuracy: 4)
                == SelectedHeading(degrees: 33, north: .magnetic)
        )
        #expect(
            HeadingSelection.select(trueHeading: 10, magneticHeading: .nan, accuracy: 4)
                == SelectedHeading(degrees: 10, north: .geographic)
        )
    }

    @Test func rejectsInvalidSensorReadings() {
        #expect(HeadingSelection.select(trueHeading: -1, magneticHeading: -1, accuracy: 5) == nil)
        #expect(HeadingSelection.select(trueHeading: 12, magneticHeading: 20, accuracy: -1) == nil)
        #expect(HeadingSelection.select(trueHeading: .nan, magneticHeading: .infinity, accuracy: 5) == nil)
        #expect(HeadingSelection.select(trueHeading: 12, magneticHeading: 20, accuracy: .nan) == nil)
    }

    @Test func staleHeadingCallbacksDoNotEnterANewSession() {
        let sessions = HeadingSessionGate()
        let first = sessions.begin()
        #expect(first != nil)
        #expect(sessions.begin() == nil)

        let captured = sessions.current()
        #expect(sessions.accepts(captured))

        #expect(sessions.end())
        #expect(sessions.end() == false)
        #expect(sessions.accepts(captured) == false)

        let restarted = sessions.begin()
        #expect(restarted != nil)
        #expect(restarted != captured)
        #expect(sessions.accepts(captured) == false)
        #expect(sessions.accepts(sessions.current()))
    }

    @Test @MainActor func viewModelUsesProviderEventsWithoutInventingHeadings() async {
        let provider = ManualHeadingProvider()
        let model = HeadingViewModel(provider: provider, targetBearing: 315)

        model.start()
        #expect(provider.isRunning)
        #expect(model.phoneHeading == nil)

        provider.send(.unavailable(.sensorUnavailable))
        await waitUntil { model.unavailableReason == .sensorUnavailable }
        #expect(model.phoneHeading == nil)
        #expect(model.northReference == nil)
        #expect(model.dialRotation == 0)
        #expect(model.arrowRotation == 315)

        provider.send(.heading(SelectedHeading(degrees: 90, north: .magnetic)))
        await waitUntil { model.phoneHeading == 90 }
        #expect(model.unavailableReason == nil)
        #expect(model.northReference == .magnetic)
        #expect(model.dialRotation == -90)
        #expect(model.arrowRotation == 225)

        provider.send(.unavailable(.authorizationDenied))
        await waitUntil { model.unavailableReason == .authorizationDenied }
        #expect(model.phoneHeading == 90)
        #expect(model.dialRotation == -90)
        #expect(model.arrowRotation == 225)

        model.stop()
        #expect(provider.isRunning == false)
    }

    @Test @MainActor func viewModelTakesShortestPathAcrossNorth() async {
        let provider = ManualHeadingProvider()
        let model = HeadingViewModel(provider: provider, targetBearing: 315)
        model.start()

        provider.send(.heading(SelectedHeading(degrees: 359, north: .magnetic)))
        await waitUntil { model.phoneHeading == 359 }
        let dialAfterWestOfNorth = model.dialRotation

        provider.send(.heading(SelectedHeading(degrees: 1, north: .magnetic)))
        await waitUntil { model.phoneHeading == 1 }
        #expect(abs((model.dialRotation - dialAfterWestOfNorth) - -2) < 0.001)

        model.stop()
    }

    @Test @MainActor func repeatedStartAndStopRestartsUpdates() async {
        let provider = ManualHeadingProvider()
        let model = HeadingViewModel(provider: provider, targetBearing: 315)

        model.start()
        model.start()
        #expect(provider.startCount == 1)
        #expect(provider.isRunning)
        let firstSession = model.sessionID

        provider.send(.heading(SelectedHeading(degrees: 20, north: .magnetic)))
        await waitUntil { model.phoneHeading == 20 }
        #expect(model.northReference == .magnetic)
        #expect(model.dialRotation == -20)
        #expect(model.arrowRotation == 295)

        model.stop()
        model.stop()
        #expect(provider.isRunning == false)
        #expect(provider.stopCount == 1)
        #expect(model.sessionID != firstSession)

        provider.send(.heading(SelectedHeading(degrees: 200, north: .geographic)))
        await Task.yield()
        #expect(model.phoneHeading == 20)
        #expect(model.northReference == .magnetic)

        model.consume(
            .heading(SelectedHeading(degrees: 80, north: .geographic)),
            fromSession: firstSession
        )
        #expect(model.phoneHeading == 20)

        model.start()
        #expect(provider.startCount == 2)
        #expect(provider.isRunning)
        #expect(model.sessionID != firstSession)

        model.consume(
            .heading(SelectedHeading(degrees: 80, north: .geographic)),
            fromSession: firstSession
        )
        #expect(model.phoneHeading == 20)

        provider.send(.heading(SelectedHeading(degrees: 45, north: .geographic)))
        await waitUntil { model.phoneHeading == 45 }
        #expect(model.northReference == .geographic)
        #expect(model.dialRotation == -45)
        #expect(model.arrowRotation == 270)

        model.stop()
        #expect(provider.isRunning == false)
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
