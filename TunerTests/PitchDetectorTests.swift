import XCTest
@testable import Tuner

final class PitchDetectorTests: XCTestCase {
    private let sampleRates: [Double] = [44_100, 48_000]
    /// Open strings in standard tuning plus a fretted high note.
    private let frequencies: [Double] = [82.41, 110.0, 146.83, 196.0, 246.94, 329.63, 659.26]

    /// A plucked-string-like tone: weak fundamental, strong low harmonics, exponential decay.
    private func pluckedTone(frequency: Double, sampleRate: Double, count: Int = 4096) -> [Float] {
        let harmonics: [Double] = [0.4, 1.0, 0.8, 0.5, 0.3, 0.2]
        var generator = SystemRandomNumberGenerator()
        return (0..<count).map { index in
            let t = Double(index) / sampleRate
            var value = 0.0
            for (k, amplitude) in harmonics.enumerated() {
                value += amplitude * sin(2 * .pi * frequency * Double(k + 1) * t + Double(k))
            }
            let noise = Double.random(in: -0.005...0.005, using: &generator)
            return Float(value * exp(-3 * t) * 0.1 + noise)
        }
    }

    func testDetectsGuitarStringsWithinOneCent() throws {
        for sampleRate in sampleRates {
            let detector = PitchDetector(sampleRate: sampleRate)
            for frequency in frequencies {
                let samples = pluckedTone(frequency: frequency, sampleRate: sampleRate)
                let result = try XCTUnwrap(detector.detect(samples), "No pitch for \(frequency) Hz @ \(sampleRate)")
                let error = Note.cents(from: frequency, to: result.frequency)
                XCTAssertLessThan(abs(error), 1, "\(frequency) Hz @ \(sampleRate): off by \(error) cents")
                XCTAssertGreaterThan(result.confidence, 0.8)
            }
        }
    }

    func testDetectsPureSine() throws {
        let sampleRate = 48_000.0
        let detector = PitchDetector(sampleRate: sampleRate)
        let samples = (0..<4096).map { Float(0.3 * sin(2 * .pi * 440 * Double($0) / sampleRate)) }
        let result = try XCTUnwrap(detector.detect(samples))
        XCTAssertEqual(result.frequency, 440, accuracy: 0.1)
    }

    func testSilenceReturnsNil() {
        let detector = PitchDetector(sampleRate: 48_000)
        XCTAssertNil(detector.detect([Float](repeating: 0, count: 4096)))
    }

    func testWhiteNoiseReturnsNil() {
        let detector = PitchDetector(sampleRate: 48_000)
        let noise = (0..<4096).map { _ in Float.random(in: -0.2...0.2) }
        XCTAssertNil(detector.detect(noise))
    }

    func testTooFewSamplesReturnsNil() {
        let detector = PitchDetector(sampleRate: 48_000)
        XCTAssertNil(detector.detect([Float](repeating: 0.1, count: 256)))
    }
}
