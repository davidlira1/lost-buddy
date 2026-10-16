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
    private var targetBearing: Double?
    private var streamTask: Task<Void, Never>?
    private(set) var sessionID = 0

    private(set) var phoneHeading: Double?
    private(set) var northReference: NorthReference?
    private(set) var dialRotation: Double = 0
    private(set) var arrowRotation: Double = 0
    private(set) var unavailableReason: HeadingUnavailableReason?

    var statusMessage: String? {
        unavailableReason?.message
    }

    var showsLiveDirection: Bool {
        unavailableReason == nil && phoneHeading != nil && targetBearing != nil
    }

    var directionIsApproximate: Bool {
        showsLiveDirection && northReference == .magnetic
    }

    init(provider: any HeadingProvider) {
        self.provider = provider
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

    /// Stores the geographic target bearing. The arrow moves only when a phone heading is also known.
    func updateTargetBearing(_ bearing: Double?) {
        guard let bearing, bearing.isFinite else {
            targetBearing = nil
            return
        }
        targetBearing = CompassRotation.normalized(bearing)
        refreshArrow()
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
            refreshArrow()
        case .unavailable(let reason):
            unavailableReason = reason
        }
    }

    private func refreshArrow() {
        guard showsLiveDirection, let heading = phoneHeading, let bearing = targetBearing else { return }
        arrowRotation = CompassRotation.continueRotation(
            previous: arrowRotation,
            target: CompassRotation.arrowTarget(targetBearing: bearing, phoneHeading: heading)
        )
    }
}
