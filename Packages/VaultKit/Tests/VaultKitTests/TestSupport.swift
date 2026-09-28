import Foundation

/// Deterministic generator so tests never depend on system randomness.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

extension SplitMix64 {
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        Int.random(in: range, using: &self)
    }

    mutating func chance(_ probability: Double) -> Bool {
        Double.random(in: 0 ..< 1, using: &self) < probability
    }

    mutating func pick<T>(_ items: [T]) -> T {
        items[int(0 ... items.count - 1)]
    }
}
