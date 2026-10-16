//
//  StatusCardView.swift
//  LostBuddy
//
//  Created by David Lira on 10/15/26.
//

import SwiftUI

struct StatusCardView: View {
    let systemImage: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(DashboardPalette.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(value)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(DashboardPalette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    HStack(spacing: 12) {
        StatusCardView(
            systemImage: "antenna.radiowaves.left.and.right",
            iconColor: DashboardPalette.gps,
            title: "GPS SIGNAL",
            value: "Active"
        )
        StatusCardView(
            systemImage: "clock",
            iconColor: DashboardPalette.clock,
            title: "LAST UPDATE",
            value: "2s ago"
        )
    }
    .padding()
    .background(DashboardPalette.background)
}
