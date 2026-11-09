// BLEManager.swift
// Core engine — uses the private CBPeripheralManager API to broadcast
// arbitrary manufacturer data without GATT service registration.
//
// Private method used:
//   -[CBPeripheralManager _startAdvertisingWithAdvertisementData:andMask:andFlags:andCompletionHandler:]
//
// BluetoothManager.framework is loaded at runtime via dlopen so the
// binary still passes App Store / TrollStore signature checks (not linked).

import Foundation
import CoreBluetooth
import Combine
import UIKit

// MARK: - BLEManager

@MainActor
final class BLEManager: NSObject, ObservableObject {

    // ── Published state ───────────────────────────────────────────────────────
    @Published var isSpamming     = false
    @Published var packetsSent    = 0
    @Published var currentPayload: BLEPayload? = nil
    @Published var btState        = CBManagerState.unknown
    @Published var errorMessage: String? = nil

    // ── Settings ──────────────────────────────────────────────────────────────
    /// Seconds between advertising rotations
    @Published var interval: Double = 0.10 {
        didSet { restartTimerIfNeeded() }
    }
    /// Which payloads to cycle through (nil = all selected)
    @Published var selectedPayloads: [BLEPayload] = Payloads.all

    // ── Private ───────────────────────────────────────────────────────────────
    private var peripheral: CBPeripheralManager?
    private var spamTimer: Timer?
    private var payloadIndex = 0

    /// Cached selector — resolved once to avoid repeated string lookups
    private let privateStartSel: Selector = NSSelectorFromString(
        "_startAdvertisingWithAdvertisementData:andMask:andFlags:andCompletionHandler:"
    )
    private let privateStopSel: Selector  = NSSelectorFromString("_stopAdvertising")

    // ── Singleton ─────────────────────────────────────────────────────────────
    static let shared = BLEManager()
    private override init() { super.init() }

    // MARK: - Public API

    func start() {
        guard !isSpamming else { return }
        packetsSent  = 0
        payloadIndex = 0
        errorMessage = nil

        // CBPeripheralManager init triggers Bluetooth permission prompt if needed.
        // We pass a background queue but dispatch UI updates back to main.
        let queue = DispatchQueue.global(qos: .userInteractive)
        peripheral = CBPeripheralManager(delegate: self, queue: queue, options: [
            CBPeripheralManagerOptionShowPowerAlertKey: true
        ])
        // State change → delegate → startSpamLoop() called there
    }

    func stop() {
        spamTimer?.invalidate()
        spamTimer = nil

        if let p = peripheral {
            // Use private stop if available, fall back to public
            if p.responds(to: privateStopSel) {
                p.perform(privateStopSel)
            } else {
                p.stopAdvertising()
            }
        }
        peripheral  = nil
        isSpamming  = false
        currentPayload = nil

        haptic(.medium)
    }

    // MARK: - Internal

    private func startSpamLoop() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isSpamming = true
            self.haptic(.heavy)

            // Fire once immediately, then repeat
            self.broadcastNext()

            self.spamTimer?.invalidate()
            self.spamTimer = Timer.scheduledTimer(
                withTimeInterval: self.interval,
                repeats: true
            ) { [weak self] _ in
                self?.broadcastNext()
            }
        }
    }

    private func broadcastNext() {
        guard let peripheral, !selectedPayloads.isEmpty else { return }

        // Wrap around
        if payloadIndex >= selectedPayloads.count { payloadIndex = 0 }
        let payload = selectedPayloads[payloadIndex]
        payloadIndex += 1

        let adData: [String: Any] = [
            CBAdvertisementDataManufacturerDataKey: payload.data
        ]

        // ── Try private API first ──────────────────────────────────────────
        // Signature: (advertisementData:, mask: UInt8, flags: UInt8, completionHandler:)
        // 0x06 = LE General Discoverable | BR/EDR Not Supported
        if peripheral.responds(to: privateStartSel) {
            // NSInvocation is not available in Swift — use performSelector via ObjC trampoline
            peripheral.stopAdvertising()  // stop previous frame
            broadcastViaPrivateAPI(peripheral: peripheral, adData: adData)
        } else {
            // Public fallback (may not work without registered services on some iOS versions)
            peripheral.stopAdvertising()
            peripheral.startAdvertising(adData)
        }

        // Update UI
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentPayload = payload
            self.packetsSent   += 1
        }
    }

    /// Calls the private Obj-C selector via an ObjC helper to pass typed args.
    private func broadcastViaPrivateAPI(peripheral: CBPeripheralManager, adData: [String: Any]) {
        // Swift cannot call variadic/typed ObjC selectors with mixed C types directly.
        // We use PrivateAdvertiser (see PrivateAdvertiser.m) as an ObjC trampoline.
        PrivateAdvertiser.broadcast(adData, on: peripheral)
    }

    private func restartTimerIfNeeded() {
        guard isSpamming else { return }
        spamTimer?.invalidate()
        spamTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            self?.broadcastNext()
        }
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.impactOccurred()
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLEManager: CBPeripheralManagerDelegate {

    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        let state = peripheral.state
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.btState = state
            switch state {
            case .poweredOn:
                self.startSpamLoop()
            case .poweredOff:
                self.stop()
                self.errorMessage = "Bluetooth is off. Enable it in Settings."
            case .unauthorized:
                self.stop()
                self.errorMessage = "Bluetooth access denied. Allow in Settings → Privacy → Bluetooth."
            case .unsupported:
                self.stop()
                self.errorMessage = "This device does not support BLE advertising."
            default:
                break
            }
        }
    }

    nonisolated func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        // Non-fatal: some packets may be rejected; we keep looping
        if let error {
            print("[BLEManager] Advertising error: \(error.localizedDescription)")
        }
    }
}
