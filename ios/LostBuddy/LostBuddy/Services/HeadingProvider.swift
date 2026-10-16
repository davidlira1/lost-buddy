//
//  HeadingProvider.swift
//  LostBuddy
//
//  Created by David Lira on 10/15/26.
//

import Foundation

protocol HeadingProvider: AnyObject {
    func start()
    func stop()
    func events() -> AsyncStream<HeadingEvent>
}

/// Test and preview stand-in that yields events on demand.
final class ManualHeadingProvider: HeadingProvider {
    private var continuation: AsyncStream<HeadingEvent>.Continuation?
    private(set) var isRunning = false
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func events() -> AsyncStream<HeadingEvent> {
        let previous = continuation
        let stream = AsyncStream<HeadingEvent> { continuation in
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

    func send(_ event: HeadingEvent) {
        guard isRunning else { return }
        continuation?.yield(event)
    }
}
