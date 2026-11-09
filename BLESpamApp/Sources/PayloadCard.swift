// PayloadCard.swift — Native iOS grouped row for payload selection

import SwiftUI

struct PayloadCard: View {
    let payload: BLEPayload
    let isSelected: Bool
    let isBroadcasting: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Settings-style rounded icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(payload.color.primary)
                        .frame(width: 30, height: 30)

                    Image(systemName: payload.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                // Title & metadata
                VStack(alignment: .leading, spacing: 2) {
                    Text(payload.name)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(payload.category.rawValue) · \(payload.bytes.count) B")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if isBroadcasting && isSelected {
                    Image(systemName: "waveform")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.warning)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(isSelected ? AppTheme.accent : Color(uiColor: .tertiaryLabel))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
