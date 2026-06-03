import Foundation
import FungibleDomain

// Content addressing for blobs. We use a fast, dependency-free FNV-1a/64 hash
// for MVP-local dedup and change detection (no network round-trips yet). When
// the hosted/BYO sync drivers land and we verify integrity across the network,
// swap this for SHA-256 (CryptoKit on-device, swift-crypto server-side) — the
// `ContentHash` namespace prefix below makes the algorithm explicit so a future
// upgrade is unambiguous. Tracked as an open question in the architecture doc.

public enum ContentHashing {
    /// FNV-1a 64-bit over the bytes, returned as zero-padded lowercase hex.
    public static func fnv1a64Hex(_ data: Data) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        let prime: UInt64 = 0x0000_0100_0000_01b3
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        let hex = String(hash, radix: 16)
        let padding = String(repeating: "0", count: max(0, 16 - hex.count))
        return padding + hex
    }

    /// Algorithm-tagged content hash so the codec is forward-compatible.
    public static func contentHash(_ data: Data) -> ContentHash {
        ContentHash(rawValue: "fnv1a64-" + fnv1a64Hex(data))
    }
}
