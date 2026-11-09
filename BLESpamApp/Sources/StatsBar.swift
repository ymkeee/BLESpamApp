// StatsBar.swift — Live stats row shown while broadcasting

import SwiftUI

struct StatsBar: View {
    let packetsSent: Int
    let interval: Double
    let payloadName: String?
    @State private var tick = false

    var body: some View {
        HStack(spacing: 0) {
            statItem(
                icon: "dot.radiowaves.left.and.right",
                value: "\(packetsSent)",
                label: "Packets",
                accent: Color(hex: "#3A8EF6")
            )
            Divider().frame(height: 36).opacity(0.2)
            statItem(
                icon: "clock.fill",
                value: intervalLabel,
                label: "Interval",
                accent: Color(hex: "#A855F7")
            )
            Divider().frame(height: 36).opacity(0.2)
            statItem(
                icon: "antenna.radiowaves.left.and.right",
                value: payloadName ?? "–",
                label: "Last Sent",
                accent: Color(hex: "#22C55E")
            )
        }
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 16)
    }

    private var intervalLabel: String {
        let ms = Int(interval * 1000)
        return "\(ms) ms"
    }

    private func statItem(icon: String, value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
