//
//  LocationProvider.swift
//  LostBuddy
//
//  Created by David Lira on 10/15/26.
//

import Foundation

protocol LocationProvider: AnyObject {
    func start()
    func stop()
    func events() -> AsyncStream<LocationEvent>
}

/// Test and preview stand-in that yields location events on demand.
final class ManualLocationProvider: LocationProvider {
    private var continuation: AsyncStream<LocationEvent>.Continuation?
    private(set) var isRunning = false
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func events() -> AsyncStream<LocationEvent> {
        let previous = continuation
        let stream = AsyncStream<LocationEvent> { continuation in
            self.continuation = continuation
        }
        previous?.finish()
        return stream
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        startCount += 1
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        stopCount += 1
        continuation?.finish()
        continuation = nil
    }

    func send(_ event: LocationEvent) {
        guard isRunning else { return }
        continuation?.yield(event)
    }
}
