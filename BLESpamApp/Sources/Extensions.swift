// Extensions.swift — SwiftUI native iOS 18 design tokens & helpers

import SwiftUI
import UIKit

// MARK: - Native iOS Design Tokens

enum AppTheme {
    static let accent = Color(uiColor: .systemBlue)          // #0A84FF
    static let destructive = Color(uiColor: .systemRed)      // #FF453A
    static let success = Color(uiColor: .systemGreen)        // #30D158
    static let warning = Color(uiColor: .systemOrange)       // #FF9F0A

    static let background = Color(uiColor: .systemGroupedBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemGroupedBackground)
    static let separator = Color(uiColor: .separator)

    /// Configures classic edge-to-edge blurred Tab Bar & Navigation Bar (pre-Liquid-Glass style)
    static func configureSystemBars() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterialDark)
        tabAppearance.backgroundColor = UIColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 0.82)
        tabAppearance.shadowColor = UIColor(white: 1.0, alpha: 0.14)

        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.systemGray
        ]
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.systemBlue
        ]

        let itemAppearances = [
            tabAppearance.stackedLayoutAppearance,
            tabAppearance.inlineLayoutAppearance,
            tabAppearance.compactInlineLayoutAppearance
        ]
        for item in itemAppearances {
            item.normal.iconColor = UIColor.systemGray
            item.normal.titleTextAttributes = normalAttrs
            item.selected.iconColor = UIColor.systemBlue
            item.selected.titleTextAttributes = selectedAttrs
        }

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().tintColor = UIColor.systemBlue
        UITabBar.appearance().unselectedItemTintColor = UIColor.systemGray

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterialDark)
        navAppearance.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 0.80)
        navAppearance.shadowColor = UIColor(white: 1.0, alpha: 0.12)
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 28, weight: .bold)
        ]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor.systemBlue
    }
}

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

// MARK: - PayloadColor → Calm Native iOS System Tints

extension PayloadColor {
    var primary: Color {
        switch self {
        case .blue:   return Color(uiColor: .systemBlue)
        case .purple: return Color(uiColor: .systemIndigo)
        case .green:  return Color(uiColor: .systemGreen)
        case .orange: return Color(uiColor: .systemOrange)
        case .pink:   return Color(uiColor: .systemPink)
        case .teal:   return Color(uiColor: .systemTeal)
        }
    }

    var linearGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Native Grouped Card Surface (preserved API)

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 12
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.secondaryBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Clean Title Text (preserved API without neon gradient)

struct GradientText: View {
    let text: String
    let colors: [Color]
    var font: Font = .headline

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(.primary)
    }
}

// MARK: - Subtle State Modifier (preserved API without radial glow)

struct PulseEffect: ViewModifier {
    let active: Bool
    let color: Color

    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func pulseEffect(active: Bool, color: Color) -> some View {
        modifier(PulseEffect(active: active, color: color))
    }
}
