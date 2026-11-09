// PayloadCard.swift — Individual payload selection card

import SwiftUI

struct PayloadCard: View {
    let payload: BLEPayload
    let isSelected: Bool
    let isBroadcasting: Bool
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                // Icon
                ZStack {
                    Circle()
                        .fill(payload.color.linearGradient)
                        .frame(width: 52, height: 52)
                        .shadow(color: payload.color.primary.opacity(0.5), radius: isSelected ? 12 : 4, y: 4)

                    Image(systemName: payload.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .pulseEffect(active: isSelected && isBroadcasting, color: payload.color.primary)

                // Name
                Text(payload.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                // Category badge
                Text(payload.category.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(payload.color.primary.opacity(0.15))
                    .foregroundStyle(payload.color.primary)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .glassCard(cornerRadius: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isSelected
                            ? payload.color.linearGradient
                            : LinearGradient(colors: [.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2
                    )
            )
            .scaleEffect(pressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        ._onButtonGesture(
            pressing: { pressing in
                withAnimation { pressed = pressing }
            },
            perform: {}
        )
    }
}
