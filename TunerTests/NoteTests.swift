import XCTest
@testable import Tuner

final class NoteTests: XCTestCase {
    func testNamesAndOctaves() {
        XCTAssertEqual(Note(midi: 69).fullName, "A4")
        XCTAssertEqual(Note(midi: 60).fullName, "C4")
        XCTAssertEqual(Note(midi: 40).fullName, "E2")
        XCTAssertEqual(Note(midi: 61).fullName, "C♯4")
    }

    func testFrequencies() {
        XCTAssertEqual(Note(midi: 69).frequency(a4: 440), 440, accuracy: 1e-9)
        XCTAssertEqual(Note(midi: 40).frequency(a4: 440), 82.4069, accuracy: 1e-3)
        XCTAssertEqual(Note(midi: 64).frequency(a4: 440), 329.6276, accuracy: 1e-3)
        XCTAssertEqual(Note(midi: 69).frequency(a4: 432), 432, accuracy: 1e-9)
    }

    func testNearestNote() {
        XCTAssertEqual(Note.nearest(to: 445, a4: 440).midi, 69)
        XCTAssertEqual(Note.nearest(to: 455, a4: 440).midi, 70)
        XCTAssertEqual(Note.nearest(to: 81, a4: 440).midi, 40)
    }

    func testCents() {
        XCTAssertEqual(Note.cents(from: 440, to: 880), 1200, accuracy: 1e-9)
        XCTAssertEqual(Note.cents(from: 440, to: 445), 19.56, accuracy: 0.01)
        XCTAssertLessThan(Note.cents(from: 110, to: 109), 0)
    }

    func testClosestStringInStandardTuning() {
        let tuning = Tuning.standard
        XCTAssertEqual(tuning.closestString(to: 80, a4: 440)?.fullName, "E2")
        XCTAssertEqual(tuning.closestString(to: 112, a4: 440)?.fullName, "A2")
        XCTAssertEqual(tuning.closestString(to: 250, a4: 440)?.fullName, "B3")
        XCTAssertEqual(tuning.closestString(to: 335, a4: 440)?.fullName, "E4")
    }

    func testTuningsHaveSixStringsOrderedLowToHigh() {
        for tuning in Tuning.all {
            XCTAssertEqual(tuning.strings.count, 6, tuning.name)
            XCTAssertEqual(tuning.strings.map(\.midi), tuning.strings.map(\.midi).sorted(), tuning.name)
        }
    }
}
