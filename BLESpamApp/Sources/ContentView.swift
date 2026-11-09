// ContentView.swift — Main UI

import SwiftUI
import CoreBluetooth

struct ContentView: View {

    @StateObject private var ble = BLEManager.shared

    // Filter state
    @State private var selectedCategory: PayloadCategory? = nil
    @State private var searchText = ""

    // Multi-select
    @State private var selectedIDs = Set<UUID>(Payloads.all.map(\.id))  // all selected by default

    // Layout
    private let gridColumns = [
        GridItem(.adaptive(minimum: 100, maximum: 130), spacing: 12)
    ]

    // Background gradient animation
    @State private var animateBG = false

    var body: some View {
        ZStack {
            // ── Animated background ─────────────────────────────────────────
            backgroundLayer

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    startStopSection
                    if ble.isSpamming {
                        statsSection
                    }
                    speedSection
                    categoryFilterSection
                    payloadGridSection
                    warningFooter
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .alert("Bluetooth Error", isPresented: .constant(ble.errorMessage != nil), actions: {
            Button("OK") { ble.errorMessage = nil }
        }, message: {
            Text(ble.errorMessage ?? "")
        })
        .onAppear { animateBG = true }
        .onChange(of: selectedIDs) { newIDs in
            ble.selectedPayloads = Payloads.all.filter { newIDs.contains($0.id) }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color(hex: "#070711")
                .ignoresSafeArea()

            // Glowing orbs
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#3A8EF6").opacity(0.25), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: animateBG ? -80 : -40, y: animateBG ? -200 : -180)
                .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: animateBG)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#A855F7").opacity(0.20), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: animateBG ? 100 : 60, y: animateBG ? 300 : 320)
                .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: animateBG)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    GradientText(
                        text: "BLE Spam",
                        colors: [Color(hex: "#3A8EF6"), Color(hex: "#A855F7"), Color(hex: "#EC4899")],
                        font: .system(size: 34, weight: .black, design: .rounded)
                    )
                    Text("Proximity Payload Broadcaster")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // BT state indicator
                btStateIndicator
            }
        }
        .padding(.top, 12)
    }

    private var btStateIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(btStateColor)
                .frame(width: 8, height: 8)
                .shadow(color: btStateColor.opacity(0.8), radius: 4)
            Text(btStateLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassCard(cornerRadius: 20)
    }

    private var btStateColor: Color {
        switch ble.btState {
        case .poweredOn:  return Color(hex: "#22C55E")
        case .poweredOff: return Color(hex: "#EF4444")
        default:          return Color(hex: "#F59E0B")
        }
    }

    private var btStateLabel: String {
        switch ble.btState {
        case .poweredOn:      return "BT ON"
        case .poweredOff:     return "BT OFF"
        case .unauthorized:   return "Denied"
        case .unsupported:    return "N/A"
        default:              return "..."
        }
    }

    // MARK: - Start/Stop

    private var startStopSection: some View {
        VStack(spacing: 8) {
            StartStopButton(isSpamming: ble.isSpamming) {
                if ble.isSpamming {
                    ble.stop()
                } else {
                    // Apply selection
                    ble.selectedPayloads = Payloads.all.filter { selectedIDs.contains($0.id) }
                    ble.start()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Stats

    private var statsSection: some View {
        StatsBar(
            packetsSent: ble.packetsSent,
            interval: ble.interval,
            payloadName: ble.currentPayload?.name
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.spring(), value: ble.isSpamming)
    }

    // MARK: - Speed Slider

    private var speedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Broadcast Speed", systemImage: "speedometer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(ble.interval * 1000)) ms")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#3A8EF6"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#3A8EF6").opacity(0.12))
                    .clipShape(Capsule())
            }

            Slider(value: $ble.interval, in: 0.05...2.0, step: 0.05) {
                Text("Interval")
            } minimumValueLabel: {
                Text("Fast").font(.caption2).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("Slow").font(.caption2).foregroundStyle(.secondary)
            }
            .tint(Color(hex: "#3A8EF6"))
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - Category Filter

    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // "All" chip
                categoryChip(label: "All", icon: "square.grid.2x2.fill", isActive: selectedCategory == nil) {
                    withAnimation(.spring()) { selectedCategory = nil }
                }
                ForEach(PayloadCategory.allCases) { cat in
                    categoryChip(
                        label: cat.rawValue,
                        icon: cat.icon,
                        isActive: selectedCategory == cat
                    ) {
                        withAnimation(.spring()) {
                            selectedCategory = (selectedCategory == cat) ? nil : cat
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func categoryChip(label: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isActive
                    ? LinearGradient(
                        colors: [Color(hex: "#3A8EF6"), Color(hex: "#6F3AFA")],
                        startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.white.opacity(0.07)], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(isActive ? .white : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isActive ? 0 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Payload Grid

    private var filteredPayloads: [BLEPayload] {
        let base = selectedCategory == nil ? Payloads.all : Payloads.payloads(for: selectedCategory!)
        return base
    }

    private var payloadGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Payloads")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(selectedIDs.count) selected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                // Select all / none
                Button(selectedIDs.count == filteredPayloads.count ? "None" : "All") {
                    withAnimation {
                        if selectedIDs.count == filteredPayloads.count {
                            filteredPayloads.forEach { selectedIDs.remove($0.id) }
                        } else {
                            filteredPayloads.forEach { selectedIDs.insert($0.id) }
                        }
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: "#3A8EF6"))
            }

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(filteredPayloads) { payload in
                    PayloadCard(
                        payload: payload,
                        isSelected: selectedIDs.contains(payload.id),
                        isBroadcasting: ble.isSpamming
                    ) {
                        withAnimation(.spring(response: 0.25)) {
                            if selectedIDs.contains(payload.id) {
                                selectedIDs.remove(payload.id)
                            } else {
                                selectedIDs.insert(payload.id)
                            }
                        }
                        let sel = UISelectionFeedbackGenerator()
                        sel.selectionChanged()
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var warningFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(hex: "#F59E0B"))
                .font(.system(size: 12))
            Text("For educational and research purposes only. Use responsibly.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
