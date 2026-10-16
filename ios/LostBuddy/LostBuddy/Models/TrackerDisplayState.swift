//
//  TrackerDisplayState.swift
//  LostBuddy
//
//  Created by David Lira on 10/15/26.
//

import SwiftUI

enum ConnectionStatus {
    case connected
    case connecting
    case disconnected

    var label: String {
        switch self {
        case .connected:
            "Connected"
        case .connecting:
            "Connecting"
        case .disconnected:
            "Disconnected"
        }
    }

    var tint: Color {
        switch self {
        case .connected:
            Color(red: 0.30, green: 0.82, blue: 0.49)
        case .connecting:
            Color(red: 0.95, green: 0.72, blue: 0.28)
        case .disconnected:
            Color(red: 0.55, green: 0.64, blue: 0.72)
        }
    }
}

struct TrackerDisplayState {
    /// Bluetooth is not connected in this phase. The badge stays disconnected until a real radio exists.
    var connection: ConnectionStatus = .disconnected
}
