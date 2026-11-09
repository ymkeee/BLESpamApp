// StatsBar.swift — Compact native telemetry row shown while broadcasting

import SwiftUI

struct StatsBar: View {
    let packetsSent: Int
    let interval: Double
    let payloadName: String?

    var body: some View {
        HStack(spacing: 12) {
            statColumn(label: "Sent", value: "\(packetsSent)")
            Divider()
                .frame(height: 28)
            statColumn(label: "Interval", value: intervalLabel)
            Divider()
                .frame(height: 28)
            statColumn(label: "Active Payload", value: payloadName ?? "—", monospaced: false)
        }
        .padding(.vertical, 6)
    }

    private var intervalLabel: String {
        "\(Int(interval * 1000)) ms"
    }

    private func statColumn(label: String, value: String, monospaced: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(
                    monospaced
                        ? .system(size: 14, weight: .semibold, design: .monospaced)
                        : .system(size: 14, weight: .medium)
                )
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
