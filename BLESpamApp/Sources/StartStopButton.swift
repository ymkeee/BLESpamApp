// StartStopButton.swift — Native iOS broadcast control button

import SwiftUI
import UIKit

struct StartStopButton: View {
    let isSpamming: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 8) {
                Image(systemName: isSpamming ? "stop.fill" : "dot.radiowaves.left.and.right")
                    .font(.system(size: 16, weight: .semibold))
                Text(isSpamming ? "Stop Broadcast" : "Start Broadcast")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSpamming ? AppTheme.destructive : AppTheme.accent)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSpamming)
    }
}
