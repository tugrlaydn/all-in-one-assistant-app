import Foundation
import Testing
@testable import VaultKit

@Suite("ULID")
struct ULIDTests {
    /// The example from the ULID spec: timestamp 1469918176385 ms.
    let specExample = "01ARYZ6S41TSV4RRFFQ69G5FAV"

    @Test func parsesAndReencodesTheSpecExample() throws {
        let ulid = try #require(ULID(specExample))
        #expect(ulid.description == specExample)
        #expect(ulid.date == Date(timeIntervalSince1970: 1_469_918_176.385))
    }

    @Test func encodesTheTimestampIntoTheFirstTenCharacters() {
        var generator = SplitMix64(seed: 1)
        let ulid = ULID(date: Date(timeIntervalSince1970: 1_469_918_176.385), using: &generator)
        #expect(ulid.description.prefix(10) == "01ARYZ6S41")
    }

    @Test func boundaryValues() throws {
        #expect(ULID(high: 0, low: 0).description == "00000000000000000000000000")
        #expect(ULID(high: .max, low: .max).description == "7ZZZZZZZZZZZZZZZZZZZZZZZZZ")
        #expect(try #require(ULID("7ZZZZZZZZZZZZZZZZZZZZZZZZZ")) == ULID(high: .max, low: .max))
    }

    @Test(arguments: [
        "80000000000000000000000000", // 131st bit set: overflow
        "01ARYZ6S41TSV4RRFFQ69G5FA", // 25 characters
        "01ARYZ6S41TSV4RRFFQ69G5FAVV", // 27 characters
        "01ARYZ6S41TSV4RRFFQ69G5FAU", // U is not Crockford
        "01ARYZ6S41TSV4RRFFQ69G5FA-",
        "",
    ])
    func rejectsInvalidStrings(_ string: String) {
        #expect(ULID(string) == nil)
    }

    @Test func parsingIsCaseInsensitiveAndAliasesAmbiguousLetters() throws {
        let lower = try #require(ULID(specExample.lowercased()))
        #expect(lower.description == specExample)
        #expect(ULID("0IL00000000000000000000000") == ULID("01100000000000000000000000"))
        #expect(ULID("O0000000000000000000000000") == ULID(high: 0, low: 0))
    }

    @Test func stringOrderMatchesCreationOrder() {
        var generator = SplitMix64(seed: 42)
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let ids = (0 ..< 200).map { offset in
            ULID(date: start.addingTimeInterval(Double(offset) / 1000), using: &generator)
        }
        #expect(ids == ids.sorted())
        #expect(ids.map(\.description) == ids.map(\.description).sorted())
    }

    @Test func roundTripsRandomValues() throws {
        var generator = SplitMix64(seed: 7)
        for _ in 0 ..< 1000 {
            let ulid = ULID(high: generator.next(), low: generator.next())
            #expect(try #require(ULID(ulid.description)) == ulid)
        }
    }

    @Test func codableUsesTheStringForm() throws {
        let ulid = try #require(ULID(specExample))
        let data = try JSONEncoder().encode([ulid])
        #expect(String(decoding: data, as: UTF8.self) == "[\"\(specExample)\"]")
        #expect(try JSONDecoder().decode([ULID].self, from: data) == [ulid])
    }
}
