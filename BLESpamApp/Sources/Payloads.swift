// Payloads.swift
// Pre-configured Apple Continuity / Fast Pair / Swift Pair byte arrays.
//
// Byte layout for Apple (company 0x004C, little-endian):
//   [0x4C, 0x00, <type>, <length>, <data…>]
//
// The full buffer is placed into CBAdvertisementDataManufacturerDataKey.

import Foundation

// MARK: - Payload model

struct BLEPayload: Identifiable, Hashable {
    let id   = UUID()
    let name: String
    let icon: String        // SF Symbol name
    let category: PayloadCategory
    let bytes: [UInt8]      // Raw manufacturer data (company ID included)
    var color: PayloadColor

    var data: Data { Data(bytes) }
}

enum PayloadCategory: String, CaseIterable, Identifiable {
    case apple     = "Apple"
    case samsung   = "Samsung"
    case microsoft = "Microsoft"
    case custom    = "Custom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .apple:     return "applelogo"
        case .samsung:   return "s.circle.fill"
        case .microsoft: return "m.circle.fill"
        case .custom:    return "wrench.and.screwdriver.fill"
        }
    }
}

enum PayloadColor {
    case blue, purple, green, orange, pink, teal

    var gradient: [String] { // hex strings for SwiftUI Color(hex:)
        switch self {
        case .blue:   return ["#3A8EF6", "#6F3AFA"]
        case .purple: return ["#A855F7", "#6366F1"]
        case .green:  return ["#22C55E", "#16A34A"]
        case .orange: return ["#F97316", "#EF4444"]
        case .pink:   return ["#EC4899", "#F43F5E"]
        case .teal:   return ["#14B8A6", "#3B82F6"]
        }
    }
}

// MARK: - Apple Continuity payloads
// Company ID 0x004C (Apple Inc.) — little-endian → 0x4C, 0x00

private extension Array where Element == UInt8 {
    /// Prepend Apple company ID
    var apple: [UInt8] { [0x4C, 0x00] + self }
}

// MARK: - All payloads

enum Payloads {

    // ── Apple ──────────────────────────────────────────────────────────────────

    static let airPodsPro2 = BLEPayload(
        name: "AirPods Pro 2",
        icon: "airpodspro",
        category: .apple,
        bytes: ([
            // Type 0x07 = Proximity Pairing, length 0x19
            0x07, 0x19,
            0x07, 0x00, 0x20, 0x75, 0xAA, 0x30,
            0x00, 0x00, 0x45, 0x12, 0x12, 0x12,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x0F
        ] as [UInt8]).apple,
        color: .blue
    )

    static let airPods3 = BLEPayload(
        name: "AirPods 3rd Gen",
        icon: "airpods",
        category: .apple,
        bytes: ([
            0x07, 0x19,
            0x13, 0x00, 0x20, 0x75, 0xAA, 0x30,
            0x00, 0x00, 0x45, 0x12, 0x12, 0x12,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x0F
        ] as [UInt8]).apple,
        color: .teal
    )

    static let airPodsMax = BLEPayload(
        name: "AirPods Max",
        icon: "headphones",
        category: .apple,
        bytes: ([
            0x07, 0x19,
            0x0A, 0x00, 0x20, 0x75, 0xAA, 0x30,
            0x00, 0x00, 0x45, 0x12, 0x12, 0x12,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x0F
        ] as [UInt8]).apple,
        color: .purple
    )

    static let beatsStudio3 = BLEPayload(
        name: "Beats Studio 3",
        icon: "beats.headphones",
        category: .apple,
        bytes: ([
            0x07, 0x19,
            0x09, 0x00, 0x20, 0x75, 0xAA, 0x30,
            0x00, 0x00, 0x45, 0x12, 0x12, 0x12,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x0F
        ] as [UInt8]).apple,
        color: .orange
    )

    static let beatsFlex = BLEPayload(
        name: "Beats Flex",
        icon: "beats.earphones",
        category: .apple,
        bytes: ([
            0x07, 0x19,
            0x10, 0x00, 0x20, 0x75, 0xAA, 0x30,
            0x00, 0x00, 0x45, 0x12, 0x12, 0x12,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x0F
        ] as [UInt8]).apple,
        color: .green
    )

    static let appleTV = BLEPayload(
        name: "Apple TV Setup",
        icon: "appletv.fill",
        category: .apple,
        bytes: ([
            // Type 0x04 = Home Setup, length 0x05
            0x04, 0x05,
            0x03, 0xC0, 0x01, 0x00, 0x00
        ] as [UInt8]).apple,
        color: .blue
    )

    static let appleWatch = BLEPayload(
        name: "Apple Watch Pair",
        icon: "applewatch",
        category: .apple,
        bytes: ([
            0x07, 0x0A,
            0x00, 0x08,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00
        ] as [UInt8]).apple,
        color: .pink
    )

    static let iphoneTransfer = BLEPayload(
        name: "iPhone Transfer",
        icon: "iphone.radiowaves.left.and.right",
        category: .apple,
        bytes: ([
            // Type 0x05 = Airdrop Proximity
            0x05, 0x12,
            0x01, 0x00, 0x03, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00
        ] as [UInt8]).apple,
        color: .teal
    )

    static let nameDrop = BLEPayload(
        name: "NameDrop",
        icon: "person.wave.2.fill",
        category: .apple,
        bytes: ([
            0x05, 0x12,
            0x01, 0x00, 0x07, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00
        ] as [UInt8]).apple,
        color: .purple
    )

    static let airTag = BLEPayload(
        name: "AirTag Detected",
        icon: "airtag",
        category: .apple,
        bytes: ([
            // Type 0x12 = Nearby Action
            0x12, 0x05,
            0x01, 0x00, 0x4B, 0x00, 0x00
        ] as [UInt8]).apple,
        color: .orange
    )

    // ── Samsung / Google Fast Pair ─────────────────────────────────────────────
    // Company ID 0x00E0 (Google LLC)
    // Format: [0xE0, 0x00, <model_id 3 bytes>, 0x00, 0x00]

    static let galaxyBudsPro = BLEPayload(
        name: "Galaxy Buds Pro",
        icon: "earbuds",
        category: .samsung,
        bytes: [0xE0, 0x00, 0x01, 0x2B, 0x41, 0x02, 0x00, 0x00],
        color: .purple
    )

    static let galaxyBuds2 = BLEPayload(
        name: "Galaxy Buds 2",
        icon: "earbuds",
        category: .samsung,
        bytes: [0xE0, 0x00, 0x01, 0x2B, 0x41, 0x0A, 0x00, 0x00],
        color: .blue
    )

    static let galaxyBudsLive = BLEPayload(
        name: "Galaxy Buds Live",
        icon: "earbuds",
        category: .samsung,
        bytes: [0xE0, 0x00, 0x01, 0x2B, 0x41, 0x0C, 0x00, 0x00],
        color: .teal
    )

    static let pixelBudsA = BLEPayload(
        name: "Pixel Buds A",
        icon: "earbuds",
        category: .samsung,
        bytes: [0xE0, 0x00, 0x01, 0x2B, 0x41, 0x06, 0x00, 0x00],
        color: .green
    )

    // ── Microsoft Swift Pair ──────────────────────────────────────────────────
    // Company ID 0x0006 (Microsoft)
    // Format: [0x06, 0x00, 0x03, 0x00, <subtype>, 0x00]

    static let msMouse = BLEPayload(
        name: "MS Mouse",
        icon: "computermouse.fill",
        category: .microsoft,
        bytes: [0x06, 0x00, 0x03, 0x00, 0x80, 0x00],
        color: .blue
    )

    static let msKeyboard = BLEPayload(
        name: "MS Keyboard",
        icon: "keyboard.fill",
        category: .microsoft,
        bytes: [0x06, 0x00, 0x03, 0x00, 0x40, 0x00],
        color: .orange
    )

    static let msHeadset = BLEPayload(
        name: "MS Headset",
        icon: "headphones",
        category: .microsoft,
        bytes: [0x06, 0x00, 0x03, 0x00, 0x20, 0x00],
        color: .purple
    )

    // ── All payloads ──────────────────────────────────────────────────────────

    static let all: [BLEPayload] = [
        airPodsPro2, airPods3, airPodsMax,
        beatsStudio3, beatsFlex,
        appleTV, appleWatch,
        iphoneTransfer, nameDrop, airTag,
        galaxyBudsPro, galaxyBuds2, galaxyBudsLive, pixelBudsA,
        msMouse, msKeyboard, msHeadset
    ]

    static func payloads(for category: PayloadCategory) -> [BLEPayload] {
        all.filter { $0.category == category }
    }
}
