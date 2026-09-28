import Foundation
import Testing
@testable import DesignKit

@Suite("HorizonLayout")
struct HorizonLayoutTests {
    @Test(arguments: [(1200.0, 7, 3), (800.0, 7, 0), (1440.0, 9, 8), (300.0, 2, 1)])
    func widthsFillTheWindowExactly(total: Double, count: Int, focused: Int) {
        let widths = HorizonLayout.columnWidths(totalWidth: total, count: count, focused: focused)
        #expect(widths.count == count)
        #expect(abs(widths.reduce(0, +) - total) < 0.0001)
    }

    @Test func focusedColumnIsTheWidest() {
        let widths = HorizonLayout.columnWidths(totalWidth: 1200, count: 7, focused: 3)
        #expect(widths[3] == 1200 * HorizonLayout.defaultFocusShare)
        #expect(widths.enumerated().allSatisfy { $0.offset == 3 || $0.element < widths[3] })
    }

    @Test func columnsNarrowWithDistanceAndStaySymmetric() {
        let widths = HorizonLayout.columnWidths(totalWidth: 1200, count: 7, focused: 3)
        #expect(widths[2] > widths[1] && widths[1] > widths[0])
        #expect(widths[4] > widths[5] && widths[5] > widths[6])
        #expect(abs(widths[0] - widths[6]) < 0.0001)
        #expect(abs(widths[2] - widths[4]) < 0.0001)
    }

    @Test func zeroFalloffKeepsUnfocusedColumnsEqual() {
        let widths = HorizonLayout.columnWidths(totalWidth: 1000, count: 5, focused: 2, focusShare: 0.6, falloff: 0)
        #expect(widths == [100, 100, 600, 100, 100])
    }

    @Test func degenerateInputs() {
        #expect(HorizonLayout.columnWidths(totalWidth: 500, count: 0, focused: 0).isEmpty)
        #expect(HorizonLayout.columnWidths(totalWidth: 500, count: 1, focused: 4) == [500])
        #expect(HorizonLayout.columnWidths(totalWidth: -10, count: 3, focused: 1) == [0, 0, 0])
        // Out-of-range focus is clamped to the last column.
        let clamped = HorizonLayout.columnWidths(totalWidth: 700, count: 7, focused: 99)
        #expect(clamped[6] == clamped.max())
    }
}
