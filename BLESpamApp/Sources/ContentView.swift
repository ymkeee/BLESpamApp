// ContentView.swift — Main UI (iOS 18 Native Grouped Layout & Classic 4-Tab Bar)

import SwiftUI
import CoreBluetooth
import UIKit

struct ContentView: View {

    @StateObject private var ble = BLEManager.shared

    // Navigation & Filter state
    @State private var selectedTab: Int = 0
    @State private var selectedCategory: PayloadCategory? = nil
    @State private var searchText = ""

    // Multi-select (all selected by default)
    @State private var selectedIDs = Set<UUID>(Payloads.all.map(\.id))

    // Custom HEX inspector & input state
    @State private var customHexText = ""
    @FocusState private var isHexFieldFocused: Bool

    // Live session log entries
    @State private var packetLogs: [String] = []

    private let speedPresets: [(label: String, subtitle: String, value: Double)] = [
        ("50 ms", "Fastest", 0.05),
        ("100 ms", "Fast", 0.10),
        ("200 ms", "Normal", 0.20),
        ("500 ms", "Slow", 0.50),
        ("1000 ms", "Stealth", 1.00)
    ]

    init() {
        AppTheme.configureSystemBars()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            payloadsTab
                .tabItem {
                    Label("Payloads", systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(0)

            timingTab
                .tabItem {
                    Label("Timing", systemImage: "timer")
                }
                .tag(1)

            customTab
                .tabItem {
                    Label("Custom", systemImage: "wrench.and.screwdriver")
                }
                .tag(2)

            logsTab
                .tabItem {
                    Label("Logs", systemImage: "list.bullet.rectangle")
                }
                .tag(3)
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(.dark)
        .alert("Bluetooth Error", isPresented: .constant(ble.errorMessage != nil), actions: {
            Button("OK") { ble.errorMessage = nil }
        }, message: {
            Text(ble.errorMessage ?? "")
        })
        .onChange(of: selectedIDs) { newIDs in
            ble.selectedPayloads = Payloads.all.filter { newIDs.contains($0.id) }
        }
        .onChange(of: ble.packetsSent) { count in
            guard count > 0, let current = ble.currentPayload else { return }
            let hexPreview = current.bytes.prefix(8).map { String(format: "%02X", $0) }.joined(separator: " ")
            let suffix = current.bytes.count > 8 ? " …" : ""
            let entry = "#\(count)   \(current.name) · \(hexPreview)\(suffix)"
            packetLogs.insert(entry, at: 0)
            if packetLogs.count > 200 {
                packetLogs.removeLast()
            }
        }
    }

    // MARK: - Tab 0: Payloads

    private var payloadsTab: some View {
        NavigationView {
            List {
                // ── Broadcast Control Section ────────────────────────────────
                Section {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(ble.isSpamming ? AppTheme.warning : btStateColor)
                            .frame(width: 8, height: 8)

                        Text(ble.isSpamming ? "Broadcasting" : btStateDescription)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("\(Int(ble.interval * 1000)) ms · \(selectedIDs.count) active")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)

                    if ble.isSpamming {
                        StatsBar(
                            packetsSent: ble.packetsSent,
                            interval: ble.interval,
                            payloadName: ble.currentPayload?.name
                        )
                    }

                    StartStopButton(isSpamming: ble.isSpamming) {
                        toggleBroadcast()
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Broadcast Control")
                }

                // ── Category Filter Section ──────────────────────────────────
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryChip(
                                label: "All",
                                icon: "square.grid.2x2",
                                isActive: selectedCategory == nil
                            ) {
                                selectedCategory = nil
                            }
                            ForEach(PayloadCategory.allCases) { cat in
                                categoryChip(
                                    label: cat.rawValue,
                                    icon: cat.icon,
                                    isActive: selectedCategory == cat
                                ) {
                                    selectedCategory = (selectedCategory == cat) ? nil : cat
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } header: {
                    HStack {
                        Text("Payloads (\(filteredPayloads.count))")
                        Spacer()
                        Button(allFilteredSelected ? "Deselect All" : "Select All") {
                            toggleAllFiltered()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .textCase(nil)
                    }
                }

                // ── Payload Rows Section ─────────────────────────────────────
                Section {
                    if filteredPayloads.isEmpty {
                        Text("No payloads match your filter.")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(filteredPayloads) { payload in
                            PayloadCard(
                                payload: payload,
                                isSelected: selectedIDs.contains(payload.id),
                                isBroadcasting: ble.isSpamming && ble.currentPayload?.id == payload.id
                            ) {
                                toggleSelection(for: payload)
                            }
                        }
                    }
                } footer: {
                    Text("For educational and security research purposes only. Use responsibly.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Payloads")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search payloads")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    btStateIndicator
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Tab 1: Timing

    private var timingTab: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("Advertising Delay")
                            .font(.system(size: 16, weight: .regular))
                        Spacer()
                        Text("\(Int(ble.interval * 1000)) ms")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppTheme.accent)
                    }

                    VStack(spacing: 8) {
                        Slider(value: $ble.interval, in: 0.05...2.0, step: 0.05) {
                            Text("Interval")
                        } minimumValueLabel: {
                            Image(systemName: "hare")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } maximumValueLabel: {
                            Image(systemName: "tortoise")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .tint(AppTheme.accent)

                        HStack {
                            Text("50 ms")
                            Spacer()
                            Text("2000 ms")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Custom Interval")
                } footer: {
                    Text("Changes take effect immediately without restarting the active broadcast.")
                }

                Section {
                    ForEach(speedPresets, id: \.value) { preset in
                        Button {
                            ble.interval = preset.value
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.label)
                                        .font(.system(size: 16, weight: .regular, design: .monospaced))
                                        .foregroundStyle(.primary)
                                    Text(preset.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if abs(ble.interval - preset.value) < 0.01 {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Speed Presets")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Timing")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Tab 2: Custom

    private var customTab: some View {
        NavigationView {
            List {
                Section {
                    TextField("4C 00 07 19 07 00 …", text: $customHexText)
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        .keyboardType(.asciiCapable)
                        .focused($isHexFieldFocused)
                        .submitLabel(.done)

                    HStack {
                        Text("Validation")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(parsedCustomHexStatus.label)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(parsedCustomHexStatus.color)
                    }
                } header: {
                    Text("Raw Manufacturer Data (HEX)")
                } footer: {
                    Text("Enter manufacturer data bytes in hexadecimal (Company ID first, little-endian).")
                }

                Section {
                    ForEach(Payloads.payloads(for: .custom)) { payload in
                        PayloadCard(
                            payload: payload,
                            isSelected: selectedIDs.contains(payload.id),
                            isBroadcasting: ble.isSpamming && ble.currentPayload?.id == payload.id
                        ) {
                            customHexText = payload.bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
                            toggleSelection(for: payload)
                        }
                    }
                } header: {
                    Text("Custom Presets")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Custom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Paste") {
                        if let str = UIPasteboard.general.string {
                            customHexText = str
                        }
                    }
                    Spacer()
                    Button("Done") {
                        isHexFieldFocused = false
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Tab 3: Logs

    private var logsTab: some View {
        NavigationView {
            List {
                Section {
                    statusRow(
                        label: "Total Packets Sent",
                        value: "\(ble.packetsSent)",
                        valueColor: AppTheme.accent,
                        monospaced: true
                    )
                    statusRow(
                        label: "Broadcast State",
                        value: ble.isSpamming ? "Broadcasting" : "Idle",
                        valueColor: ble.isSpamming ? AppTheme.warning : .secondary
                    )
                    statusRow(
                        label: "Active Payload",
                        value: ble.currentPayload?.name ?? "None"
                    )
                } header: {
                    Text("Session Summary")
                }

                Section {
                    if packetLogs.isEmpty {
                        Text("No packets transmitted yet")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(packetLogs.enumerated()), id: \.offset) { _, entry in
                            Text(entry)
                                .font(.system(size: 13, weight: .regular, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                    }
                } header: {
                    Text("Live Packet Log")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        packetLogs.removeAll()
                    }
                    .disabled(packetLogs.isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Subviews & Helpers

    private var btStateIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(btStateColor)
                .frame(width: 7, height: 7)
            Text(btStateLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var btStateColor: Color {
        switch ble.btState {
        case .poweredOn:  return AppTheme.success
        case .poweredOff: return AppTheme.destructive
        default:          return AppTheme.warning
        }
    }

    private var btStateLabel: String {
        switch ble.btState {
        case .poweredOn:    return "BT On"
        case .poweredOff:   return "BT Off"
        case .unauthorized: return "Denied"
        case .unsupported:  return "Unsupported"
        default:            return "Ready"
        }
    }

    private var btStateDescription: String {
        switch ble.btState {
        case .poweredOn:    return "Ready"
        case .poweredOff:   return "Bluetooth Off"
        case .unauthorized: return "Permission Denied"
        case .unsupported:  return "Unsupported"
        default:            return "Idle"
        }
    }

    private var parsedCustomHexStatus: (label: String, color: Color) {
        let cleaned = customHexText.components(separatedBy: CharacterSet(charactersIn: " :,-")).joined()
        if cleaned.isEmpty {
            return ("Awaiting HEX input", .secondary)
        }
        guard cleaned.count >= 2, cleaned.count % 2 == 0 else {
            return ("Invalid HEX format", AppTheme.destructive)
        }
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            if UInt8(cleaned[index..<next], radix: 16) == nil {
                return ("Invalid HEX format", AppTheme.destructive)
            }
            index = next
        }
        return ("Valid (\(cleaned.count / 2) bytes)", AppTheme.success)
    }

    private func categoryChip(label: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? AppTheme.accent : AppTheme.tertiaryBackground)
            )
            .foregroundStyle(isActive ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func statusRow(
        label: String,
        value: String,
        valueColor: Color = .secondary,
        monospaced: Bool = false
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(monospaced ? .system(size: 15, weight: .semibold, design: .monospaced) : .system(size: 15))
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
    }

    private var filteredPayloads: [BLEPayload] {
        let base = selectedCategory == nil ? Payloads.all : Payloads.payloads(for: selectedCategory!)
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var allFilteredSelected: Bool {
        !filteredPayloads.isEmpty && filteredPayloads.allSatisfy { selectedIDs.contains($0.id) }
    }

    private func toggleAllFiltered() {
        if allFilteredSelected {
            filteredPayloads.forEach { selectedIDs.remove($0.id) }
        } else {
            filteredPayloads.forEach { selectedIDs.insert($0.id) }
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func toggleSelection(for payload: BLEPayload) {
        if selectedIDs.contains(payload.id) {
            selectedIDs.remove(payload.id)
        } else {
            selectedIDs.insert(payload.id)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func toggleBroadcast() {
        if ble.isSpamming {
            ble.stop()
        } else {
            ble.selectedPayloads = Payloads.all.filter { selectedIDs.contains($0.id) }
            ble.start()
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
