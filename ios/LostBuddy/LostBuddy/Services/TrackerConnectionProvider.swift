//
//  TrackerConnectionProvider.swift
//  LostBuddy
//
//  Created by David Lira on 10/16/26.
//

import Foundation

protocol TrackerConnectionProvider: AnyObject {
    var isSimulated: Bool { get }
    func start()
    func stop()
    func events() -> AsyncStream<TrackerConnectionEvent>
}

/// Test and preview stand-in that yields tracker events on demand.
final class ManualTrackerConnectionProvider: TrackerConnectionProvider {
    let isSimulated: Bool
    private var continuation: AsyncStream<TrackerConnectionEvent>.Continuation?
    private(set) var isRunning = false
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(isSimulated: Bool = false) {
        self.isSimulated = isSimulated
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
        guard !isRunning else { return }
        isRunning = true
        startCount += 1
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        stopCount += 1
        continuation?.yield(.link(.disconnected))
        continuation?.finish()
        continuation = nil
    }

    func send(_ event: TrackerConnectionEvent) {
        guard isRunning else { return }
        continuation?.yield(event)
    }
}
