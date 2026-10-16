//
//  SimulatedTrackerProvider.swift
//  LostBuddy
//
//  Created by David Lira on 10/16/26.
//

import Foundation

struct SimulatedTrackerScript: Equatable {
    var connectDelay: Duration = .milliseconds(400)
    var updateInterval: Duration = .seconds(2)
    var stepMeters: Double = 40
    /// Nil keeps publishing until stop. A count disconnects after that many fixes.
    var updateCountBeforeDisconnect: Int? = nil
    var trackerID: String = "simulated-lost-buddy"
    /// Nil uses `MockTrackerLocation.coordinate` when the session starts.
    var origin: GeoCoordinate? = nil
}

/// Selects the tracker transport used by the app.
///
/// Simulated sessions return `SimulatedTrackerProvider()`. A future hardware
/// session should return `CoreBluetoothTrackerProvider()` from this function.
/// That type conforms to `TrackerConnectionProvider` and keeps CoreBluetooth
/// inside its own file. Views and navigation stay on the protocol.
enum TrackerTransport {
    @MainActor
    static func makeProvider() -> any TrackerConnectionProvider {
        SimulatedTrackerProvider()
    }
}

/// Mimics a BLE LostBuddy device without importing CoreBluetooth.
@MainActor
final class SimulatedTrackerProvider: TrackerConnectionProvider {
    let isSimulated = true
    private let script: SimulatedTrackerScript
    private var continuation: AsyncStream<TrackerConnectionEvent>.Continuation?
    private var task: Task<Void, Never>?
    private var sessionID = 0

    init(script: SimulatedTrackerScript = SimulatedTrackerScript()) {
        self.script = script
    }

    func events() -> AsyncStream<TrackerConnectionEvent> {
        let previous = continuation
        let stream = AsyncStream<TrackerConnectionEvent> { continuation in
            self.continuation = continuation
        }
        previous?.finish()
        return stream
    }

    func start() {
        guard task == nil else { return }
        sessionID &+= 1
        let session = sessionID
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.run(session: session)
            if session == self.sessionID {
                self.task = nil
            }
        }
    }

    func stop() {
        guard task != nil else { return }
        sessionID &+= 1
        task?.cancel()
        task = nil
        continuation?.yield(.link(.disconnected))
    }

    private func run(session: Int) async {
        guard session == sessionID else { return }
        continuation?.yield(.link(.connecting))
        if script.connectDelay > .zero {
            try? await Task.sleep(for: script.connectDelay)
        }
        guard session == sessionID, !Task.isCancelled else { return }
        continuation?.yield(.link(.connected))

        let origin = script.origin ?? MockTrackerLocation.coordinate
        var index = 0
        while session == sessionID, !Task.isCancelled {
            if let limit = script.updateCountBeforeDisconnect, index >= limit {
                continuation?.yield(.link(.disconnected))
                return
            }
            let coordinate = Self.east(of: origin, meters: script.stepMeters * Double(index))
            continuation?.yield(.location(TrackerLocationCandidate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                trackerID: script.trackerID,
                timestamp: Date()
            )))
            index += 1
            if let limit = script.updateCountBeforeDisconnect, index >= limit {
                continuation?.yield(.link(.disconnected))
                return
            }
            try? await Task.sleep(for: script.updateInterval)
        }
    }

    /// Moves east by a short equirectangular step. Navigation distance still uses `NavigationCalculator`.
    private static func east(of origin: GeoCoordinate, meters: Double) -> GeoCoordinate {
        guard meters != 0 else { return origin }
        let metersPerDegree = 111_320.0 * cos(origin.latitude * .pi / 180)
        guard metersPerDegree.isFinite, abs(metersPerDegree) > 1 else { return origin }
        var longitude = origin.longitude + meters / metersPerDegree
        while longitude > 180 { longitude -= 360 }
        while longitude < -180 { longitude += 360 }
        return GeoCoordinate(latitude: origin.latitude, longitude: longitude) ?? origin
    }
}
