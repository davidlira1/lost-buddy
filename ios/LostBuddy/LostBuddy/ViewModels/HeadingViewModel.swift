//
//  HeadingViewModel.swift
//  LostBuddy
//
//  Created by David Lira on 10/15/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class HeadingViewModel {
    private let provider: any HeadingProvider
    private let targetBearing: Double
    private var streamTask: Task<Void, Never>?
    private(set) var sessionID = 0

    private(set) var phoneHeading: Double?
    private(set) var northReference: NorthReference?
    private(set) var dialRotation: Double = 0
    private(set) var arrowRotation: Double
    private(set) var unavailableReason: HeadingUnavailableReason?

    var statusMessage: String? {
        unavailableReason?.message
    }

    init(provider: any HeadingProvider, targetBearing: Double) {
        self.provider = provider
        self.targetBearing = targetBearing
        arrowRotation = targetBearing
    }

    func start() {
        guard streamTask == nil else { return }
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
    }

    func stop() {
        guard streamTask != nil else {
            provider.stop()
            return
        }
        sessionID &+= 1
        streamTask?.cancel()
        streamTask = nil
        provider.stop()
    }

    func consume(_ event: HeadingEvent, fromSession session: Int) {
        guard session == sessionID else { return }
        apply(event)
    }

    func apply(_ event: HeadingEvent) {
        switch event {
        case .heading(let reading):
            guard reading.degrees.isFinite else { return }
            let heading = CompassRotation.normalized(reading.degrees)
            phoneHeading = heading
            northReference = reading.north
            unavailableReason = nil
            dialRotation = CompassRotation.continueRotation(
                previous: dialRotation,
                target: CompassRotation.dialTarget(phoneHeading: heading)
            )
            arrowRotation = CompassRotation.continueRotation(
                previous: arrowRotation,
                target: CompassRotation.arrowTarget(targetBearing: targetBearing, phoneHeading: heading)
            )
        case .unavailable(let reason):
            unavailableReason = reason
        }
    }
}
