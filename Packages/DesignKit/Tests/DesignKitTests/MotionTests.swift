import SwiftUI
import Testing
@testable import DesignKit

@Suite("Motion")
struct MotionTests {
    @Test func reduceMotionAlwaysCrossfades() {
        let crossfade = Animation.easeInOut(duration: Motion.crossfadeDuration)
        #expect(Motion.animation(.quick, reduceMotion: true) == crossfade)
        #expect(Motion.animation(.settle, reduceMotion: true) == crossfade)
    }

    @Test func quickIsFasterThanSettle() {
        #expect(Motion.quickResponse < Motion.settleResponse)
        #expect(Motion.animation(.quick, reduceMotion: false) != Motion.animation(.settle, reduceMotion: false))
    }
}
