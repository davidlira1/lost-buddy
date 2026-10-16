//
//  CompassView.swift
//  LostBuddy
//
//  Created by David Lira on 10/15/26.
//

import SwiftUI

struct CompassView: View {
    /// Dial rotation in degrees. Negative phone heading keeps north fixed in the world.
    var dialRotation: Double
    /// Arrow rotation in degrees. Target bearing minus phone heading.
    var arrowRotation: Double
    /// Hides the arrow when heading or target bearing cannot support a live direction.
    var showsDirection: Bool = true

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    compass(side: min(proxy.size.width, proxy.size.height))
                }
            }
    }

    private func compass(side: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.09, green: 0.16, blue: 0.25),
                            DashboardPalette.compassDisk
                        ],
                        center: .center,
                        startRadius: side * 0.05,
                        endRadius: side * 0.5
                    )
                )
                .overlay {
                    Circle()
                        .stroke(DashboardPalette.ring, lineWidth: 1.5)
                }

            dial(side: side)
                .rotationEffect(.degrees(dialRotation))
                .animation(.easeOut(duration: 0.25), value: dialRotation)

            CompassNeedle()
                .fill(
                    LinearGradient(
                        colors: [DashboardPalette.arrowLight, DashboardPalette.arrow],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: side * 0.62, height: side * 0.62)
                .shadow(color: DashboardPalette.arrow.opacity(0.28), radius: side * 0.03, y: side * 0.012)
                .rotationEffect(.degrees(arrowRotation))
                .opacity(showsDirection ? 1 : 0)
                .animation(.easeOut(duration: 0.25), value: arrowRotation)
                .animation(.easeOut(duration: 0.2), value: showsDirection)

            Circle()
                .fill(.white)
                .frame(width: side * 0.065, height: side * 0.065)
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        }
        .frame(width: side, height: side)
    }

    private func dial(side: CGFloat) -> some View {
        let center = side / 2

        return ZStack {
            Circle()
                .stroke(
                    DashboardPalette.ring,
                    style: StrokeStyle(lineWidth: 1.25, dash: [2.5, 5])
                )
                .frame(width: side * 0.66, height: side * 0.66)

            CompassAxes()
                .stroke(DashboardPalette.axis, lineWidth: 1)

            cardinal("N", x: center, y: side * 0.09, side: side)
            cardinal("E", x: side * 0.91, y: center, side: side)
            cardinal("S", x: center, y: side * 0.91, side: side)
            cardinal("W", x: side * 0.09, y: center, side: side)
        }
        .frame(width: side, height: side)
    }

    private func cardinal(_ letter: String, x: CGFloat, y: CGFloat, side: CGFloat) -> some View {
        Text(letter)
            .font(.system(size: side * 0.052, weight: .medium))
            .foregroundStyle(DashboardPalette.label)
            .position(x: x, y: y)
    }
}

private struct CompassAxes: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = min(rect.width, rect.height) * 0.16
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - inset))
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.midY))
        return path
    }
}

/// Needle drawn pointing north. Rotate the view clockwise for other headings.
private struct CompassNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let tip = CGPoint(x: cx, y: cy - rect.height * 0.48)
        let right = CGPoint(x: cx + rect.width * 0.22, y: cy + rect.height * 0.05)
        let tail = CGPoint(x: cx, y: cy + rect.height * 0.30)
        let left = CGPoint(x: cx - rect.width * 0.22, y: cy + rect.height * 0.05)

        var path = Path()
        path.move(to: tip)
        path.addLine(to: right)
        path.addLine(to: tail)
        path.addLine(to: left)
        path.closeSubpath()
        return path
    }
}

#Preview {
    CompassView(dialRotation: 0, arrowRotation: 315)
        .padding(32)
        .background(DashboardPalette.background)
}
