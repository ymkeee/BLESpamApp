// Extensions.swift — SwiftUI helpers

import SwiftUI

// MARK: - Color from hex string

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - PayloadColor → SwiftUI Gradient

extension PayloadColor {
    var linearGradient: LinearGradient {
        LinearGradient(
            colors: gradient.map { Color(hex: $0) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var primary: Color { Color(hex: gradient[0]) }
}

// MARK: - Glassmorphism modifier

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Animated gradient text

struct GradientText: View {
    let text: String
    let colors: [Color]
    var font: Font = .title.bold()

    var body: some View {
        Text(text)
            .font(font)
            .overlay(
                LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                    .mask(Text(text).font(font))
            )
    }
}

// MARK: - Pulse animation modifier

struct PulseEffect: ViewModifier {
    @State private var pulse = false
    let active: Bool
    let color: Color

    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(color.opacity(0.3))
                    .scaleEffect(pulse ? 1.6 : 1.0)
                    .opacity(pulse ? 0 : 0.6)
                    .animation(
                        active
                            ? .easeInOut(duration: 0.9).repeatForever(autoreverses: false)
                            : .default,
                        value: pulse
                    )
            )
            .onAppear { if active { pulse = true } }
            .onChange(of: active) { newVal in pulse = newVal }
    }
}

extension View {
    func pulseEffect(active: Bool, color: Color) -> some View {
        modifier(PulseEffect(active: active, color: color))
    }
}
