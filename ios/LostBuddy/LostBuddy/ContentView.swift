//
//  ContentView.swift
//  LostBuddy
//
//  Created by David Lira on 10/15/26.
//

import SwiftUI

enum DashboardPalette {
    static let background = Color(red: 0.051, green: 0.110, blue: 0.180)
    static let card = Color(red: 0.102, green: 0.165, blue: 0.235)
    static let compassDisk = Color(red: 0.067, green: 0.125, blue: 0.196)
    static let label = Color(red: 0.62, green: 0.71, blue: 0.79)
    static let title = Color(red: 0.80, green: 0.87, blue: 0.93)
    static let ring = Color(red: 0.62, green: 0.73, blue: 0.82).opacity(0.38)
    static let axis = Color(red: 0.70, green: 0.79, blue: 0.87).opacity(0.32)
    static let arrow = Color(red: 0.11, green: 0.66, blue: 0.61)
    static let arrowLight = Color(red: 0.64, green: 0.95, blue: 0.86)
    static let gps = Color(red: 0.31, green: 0.86, blue: 0.58)
    static let clock = Color(red: 0.38, green: 0.64, blue: 0.96)
}

struct ContentView: View {
    @State private var tracker = TrackerDisplayState()
    @State private var headingModel: HeadingViewModel

    @MainActor
    init(headingProvider: any HeadingProvider) {
        _headingModel = State(
            initialValue: HeadingViewModel(
                provider: headingProvider,
                targetBearing: TrackerDisplayState().directionDegrees
            )
        )
    }

    @MainActor
    init() {
        self.init(headingProvider: CoreLocationHeadingProvider())
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            statusCaption
                .padding(.top, 8)
            Spacer(minLength: 20)
            distanceSection
            Spacer(minLength: 12)
            CompassView(
                dialRotation: headingModel.dialRotation,
                arrowRotation: headingModel.arrowRotation
            )
            .padding(.horizontal, 8)
            Spacer(minLength: 16)
            statusCards
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DashboardPalette.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { headingModel.start() }
        .onDisappear { headingModel.stop() }
    }

    private var statusCaption: some View {
        Text(headingModel.statusMessage ?? "Bluetooth, GPS, and last update are mock")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(DashboardPalette.label)
            .multilineTextAlignment(.center)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("LOST BUDDY")
                .font(.system(size: 22, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(DashboardPalette.title)
                .lineLimit(1)

            Spacer(minLength: 8)

            connectionBadge
        }
    }

    private var connectionBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "bluetooth")
                .font(.system(size: 13, weight: .semibold))
            Text(tracker.connection.label)
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(tracker.connection.tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(tracker.connection.tint.opacity(0.18), in: Capsule())
    }

    private var distanceSection: some View {
        VStack(spacing: 6) {
            Text("TRACKER DISTANCE")
                .font(.system(size: 13, weight: .medium))
                .tracking(2.2)
                .foregroundStyle(DashboardPalette.label)

            Text("\(tracker.distanceMeters) m")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }

    private var statusCards: some View {
        HStack(spacing: 12) {
            StatusCardView(
                systemImage: "antenna.radiowaves.left.and.right",
                iconColor: DashboardPalette.gps,
                title: "GPS SIGNAL",
                value: tracker.gpsSignal
            )
            StatusCardView(
                systemImage: "clock",
                iconColor: DashboardPalette.clock,
                title: "LAST UPDATE",
                value: tracker.lastUpdate
            )
        }
    }
}

#Preview {
    ContentView(headingProvider: ManualHeadingProvider())
}
