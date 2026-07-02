import Foundation
import FungibleDomain

// Content addressing for blobs. Hashes are algorithm-tagged ("sha256-…",
// "fnv1a64-…") so blobs written by older builds keep resolving: the store looks
// blobs up by the full tagged string, never by re-hashing. New writes use
// SHA-256 — collision-safe, so identical-hash ⇒ identical-bytes holds and the
// dedup skip in `writeBlob` can never silently serve the wrong points. The
// implementation is dependency-free (FIPS 180-4 in plain Swift) because
// CryptoKit doesn't exist on the Linux CI toolchain and swift-crypto would be
// this package's first external dependency.

public enum ContentHashing {
    /// SHA-256 over the bytes, returned as lowercase hex (FIPS 180-4).
    public static func sha256Hex(_ data: Data) -> String {
        var h: [UInt32] = [
            0x6a09_e667, 0xbb67_ae85, 0x3c6e_f372, 0xa54f_f53a,
            0x510e_527f, 0x9b05_688c, 0x1f83_d9ab, 0x5be0_cd19,
        ]

        // Pad: append 0x80, zeros to 56 mod 64, then the bit length as u64 BE.
        var message = [UInt8](data)
        let bitLength = UInt64(message.count) * 8
        message.append(0x80)
        while message.count % 64 != 56 { message.append(0) }
        for shift in stride(from: 56, through: 0, by: -8) {
            message.append(UInt8(truncatingIfNeeded: bitLength >> UInt64(shift)))
        }

        func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 { (x >> n) | (x << (32 - n)) }

        var w = [UInt32](repeating: 0, count: 64)
        for chunkStart in stride(from: 0, to: message.count, by: 64) {
            for i in 0..<16 {
                let o = chunkStart + i * 4
                w[i] = (UInt32(message[o]) << 24) | (UInt32(message[o + 1]) << 16)
                    | (UInt32(message[o + 2]) << 8) | UInt32(message[o + 3])
            }
            for i in 16..<64 {
                let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
                let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }

            var a = h[0], b = h[1], c = h[2], d = h[3]
            var e = h[4], f = h[5], g = h[6], hh = h[7]
            for i in 0..<64 {
                let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                let ch = (e & f) ^ (~e & g)
                let temp1 = hh &+ s1 &+ ch &+ Self.k[i] &+ w[i]
                let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ maj
                hh = g; g = f; f = e; e = d &+ temp1
                d = c; c = b; b = a; a = temp1 &+ temp2
            }
            h[0] &+= a; h[1] &+= b; h[2] &+= c; h[3] &+= d
            h[4] &+= e; h[5] &+= f; h[6] &+= g; h[7] &+= hh
        }

        return h.map { word in
            let hex = String(word, radix: 16)
            return String(repeating: "0", count: 8 - hex.count) + hex
        }.joined()
    }

    /// FNV-1a 64-bit over the bytes, returned as zero-padded lowercase hex.
    /// Retained so pre-SHA-256 tagged hashes stay documented/testable; new
    /// content hashes no longer use it.
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
        ContentHash(rawValue: "sha256-" + sha256Hex(data))
    }

    private static let k: [UInt32] = [
        0x428a_2f98, 0x7137_4491, 0xb5c0_fbcf, 0xe9b5_dba5, 0x3956_c25b, 0x59f1_11f1, 0x923f_82a4, 0xab1c_5ed5,
        0xd807_aa98, 0x1283_5b01, 0x2431_85be, 0x550c_7dc3, 0x72be_5d74, 0x80de_b1fe, 0x9bdc_06a7, 0xc19b_f174,
        0xe49b_69c1, 0xefbe_4786, 0x0fc1_9dc6, 0x240c_a1cc, 0x2de9_2c6f, 0x4a74_84aa, 0x5cb0_a9dc, 0x76f9_88da,
        0x983e_5152, 0xa831_c66d, 0xb003_27c8, 0xbf59_7fc7, 0xc6e0_0bf3, 0xd5a7_9147, 0x06ca_6351, 0x1429_2967,
        0x27b7_0a85, 0x2e1b_2138, 0x4d2c_6dfc, 0x5338_0d13, 0x650a_7354, 0x766a_0abb, 0x81c2_c92e, 0x9272_2c85,
        0xa2bf_e8a1, 0xa81a_664b, 0xc24b_8b70, 0xc76c_51a3, 0xd192_e819, 0xd699_0624, 0xf40e_3585, 0x106a_a070,
        0x19a4_c116, 0x1e37_6c08, 0x2748_774c, 0x34b0_bcb5, 0x391c_0cb3, 0x4ed8_aa4a, 0x5b9c_ca4f, 0x682e_6ff3,
        0x748f_82ee, 0x78a5_636f, 0x84c8_7814, 0x8cc7_0208, 0x90be_fffa, 0xa450_6ceb, 0xbef9_a3f7, 0xc671_78f2,
    ]
}
