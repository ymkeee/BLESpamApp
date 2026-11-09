// StartStopButton.swift — Animated broadcast toggle button

import SwiftUI

struct StartStopButton: View {
    let isSpamming: Bool
    let onTap: () -> Void

    @State private var scale: CGFloat = 1.0

    // Rotating gradient animation
    @State private var rotationAngle: Double = 0

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                scale = 0.92
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                    scale = 1.0
                }
            }
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            onTap()
        }) {
            ZStack {
                // Spinning gradient ring (only when active)
                if isSpamming {
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "#3A8EF6"),
                                    Color(hex: "#6F3AFA"),
                                    Color(hex: "#EC4899"),
                                    Color(hex: "#3A8EF6"),
                                ]),
                                center: .center
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(rotationAngle))
                        .onAppear {
                            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                rotationAngle = 360
                            }
                        }
                        .onDisappear { rotationAngle = 0 }
                }

                // Button body
                Circle()
                    .fill(
                        isSpamming
                            ? LinearGradient(
                                colors: [Color(hex: "#EF4444"), Color(hex: "#B91C1C")],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(
                                colors: [Color(hex: "#3A8EF6"), Color(hex: "#6F3AFA")],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 78, height: 78)
                    .shadow(
                        color: (isSpamming ? Color(hex: "#EF4444") : Color(hex: "#3A8EF6")).opacity(0.6),
                        radius: isSpamming ? 20 : 12,
                        y: 6
                    )

                // Icon
                Image(systemName: isSpamming ? "stop.fill" : "wifi.router.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .scaleEffect(scale)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: isSpamming)

        // Label below
        Text(isSpamming ? "BROADCASTING" : "TAP TO START")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(isSpamming ? Color(hex: "#EF4444") : .secondary)
            .padding(.top, 4)
    }
}
