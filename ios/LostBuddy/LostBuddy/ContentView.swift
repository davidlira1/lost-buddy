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
    @Environment(\.scenePhase) private var scenePhase
    @State private var tracker = TrackerDisplayState()
    @State private var headingModel: HeadingViewModel
    @State private var navigationModel: NavigationViewModel

    @MainActor
    init(headingProvider: any HeadingProvider, locationProvider: any LocationProvider) {
        _headingModel = State(initialValue: HeadingViewModel(provider: headingProvider))
        _navigationModel = State(
            initialValue: NavigationViewModel(
                provider: locationProvider,
                tracker: MockTrackerLocation.coordinate
            )
        )
    }

    @MainActor
    init() {
        self.init(
            headingProvider: CoreLocationHeadingProvider(),
            locationProvider: CoreLocationProvider()
        )
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
                arrowRotation: headingModel.arrowRotation,
                showsDirection: headingModel.showsLiveDirection
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
        .onAppear {
            headingModel.start()
            navigationModel.start()
            headingModel.updateTargetBearing(navigationModel.bearingDegrees)
        }
        .onDisappear {
            headingModel.stop()
            navigationModel.stop()
        }
        .onChange(of: navigationModel.bearingDegrees) { _, bearing in
            headingModel.updateTargetBearing(bearing)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                navigationModel.sceneDidBecomeActive()
            case .background:
                navigationModel.sceneDidEnterBackground()
            default:
                break
            }
        }
    }

    private var statusCaption: some View {
        Text(captionText)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(DashboardPalette.label)
            .multilineTextAlignment(.center)
    }

    private var captionText: String {
        if let locationCaption = navigationModel.statusCaption {
            return locationCaption
        }
        if let headingCaption = headingModel.statusMessage {
            return headingCaption
        }
        if !headingModel.showsLiveDirection {
            return "Direction unavailable"
        }
        if headingModel.directionIsApproximate {
            return "Direction is approximate (magnetic heading)"
        }
        return "Bluetooth is mock. No tracker telemetry."
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

            Text(navigationModel.formattedDistance)
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
                title: "PHONE GPS",
                value: navigationModel.phoneGPSValue
            )
            StatusCardView(
                systemImage: "clock",
                iconColor: DashboardPalette.clock,
                title: "LAST UPDATE",
                value: "No telemetry"
            )
        }
    }
}

#Preview {
    ContentView(
        headingProvider: ManualHeadingProvider(),
        locationProvider: ManualLocationProvider()
    )
}
