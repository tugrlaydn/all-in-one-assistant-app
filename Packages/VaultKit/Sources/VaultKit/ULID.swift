import Foundation

/// A Universally Unique Lexicographically Sortable Identifier — the `id` of every vault item (FORMAT §4.1).
///
/// 128 bits: a 48-bit millisecond Unix timestamp followed by 80 random bits, written as 26 characters
/// of Crockford base32. Sorting the strings sorts the items by creation time, and the id never changes
/// when a file is renamed. Spec: https://github.com/ulid/spec
public struct ULID: Hashable, Comparable, Sendable {
    /// The upper 64 bits: 48 bits of timestamp, then the first 16 random bits.
    public let high: UInt64
    /// The lower 64 random bits.
    public let low: UInt64

    static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ".utf8)
    static let maxTimestamp: UInt64 = (1 << 48) - 1

    public init(high: UInt64, low: UInt64) {
        self.high = high
        self.low = low
    }

    /// A new ULID for `date`, with randomness from `generator`.
    public init(date: Date = Date(), using generator: inout some RandomNumberGenerator) {
        // Nearest, not floor: `x.385 * 1000` can land a hair below 385 in binary floating point.
        let milliseconds = UInt64(max(0, (date.timeIntervalSince1970 * 1000).rounded()))
        let timestamp = min(milliseconds, Self.maxTimestamp)
        let randomHigh = UInt64(UInt16.random(in: .min ... .max, using: &generator))
        self.init(high: timestamp << 16 | randomHigh, low: UInt64.random(in: .min ... .max, using: &generator))
    }

    /// A new ULID for `date`, with system randomness.
    public init(date: Date = Date()) {
        var generator = SystemRandomNumberGenerator()
        self.init(date: date, using: &generator)
    }

    /// Parses a 26-character Crockford base32 string. Case-insensitive; `I`/`L` read as 1, `O` as 0.
    public init?(_ string: String) {
        let bytes = Array(string.utf8)
        guard bytes.count == 26 else { return nil }
        var high: UInt64 = 0
        var low: UInt64 = 0
        for (index, byte) in bytes.enumerated() {
            guard let value = Self.decode(byte) else { return nil }
            // 26 × 5 = 130 bits; the first character may only use its lowest 3 bits.
            if index == 0, value > 7 { return nil }
            high = high << 5 | low >> 59
            low = low << 5 | UInt64(value)
        }
        self.init(high: high, low: low)
    }

    /// The creation time, to the millisecond.
    public var date: Date {
        Date(timeIntervalSince1970: TimeInterval(high >> 16) / 1000)
    }

    public static func < (lhs: ULID, rhs: ULID) -> Bool {
        (lhs.high, lhs.low) < (rhs.high, rhs.low)
    }

    private static func decode(_ byte: UInt8) -> UInt8? {
        switch byte {
        case UInt8(ascii: "0"), UInt8(ascii: "O"), UInt8(ascii: "o"):
            return 0
        case UInt8(ascii: "1"), UInt8(ascii: "I"), UInt8(ascii: "i"), UInt8(ascii: "L"), UInt8(ascii: "l"):
            return 1
        case UInt8(ascii: "2") ... UInt8(ascii: "9"):
            return byte - UInt8(ascii: "0")
        default:
            // Crockford excludes I, L, O (aliased above) and U.
            let upper = byte & ~0x20
            guard let index = alphabet.firstIndex(of: upper), index >= 10 else { return nil }
            return UInt8(index)
        }
    }
}

extension ULID: CustomStringConvertible, LosslessStringConvertible {
    public var description: String {
        var chars = [UInt8](repeating: 0, count: 26)
        var high = high
        var low = low
        for index in stride(from: 25, through: 0, by: -1) {
            chars[index] = Self.alphabet[Int(low & 31)]
            low = low >> 5 | (high & 31) << 59
            high >>= 5
        }
        return String(decoding: chars, as: UTF8.self)
    }
}

extension ULID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let ulid = ULID(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a ULID: \(string)")
        }
        self = ulid
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
