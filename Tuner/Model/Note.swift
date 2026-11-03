import Foundation

/// A pitch on the equal-tempered scale, identified by its MIDI note number.
struct Note: Hashable, Identifiable {
    let midi: Int

    var id: Int { midi }

    private static let sharpNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    var name: String { Self.sharpNames[((midi % 12) + 12) % 12] }

    /// Scientific pitch notation octave (A4 = 440 Hz, middle C = C4).
    var octave: Int { Int((Double(midi) / 12).rounded(.down)) - 1 }

    var fullName: String { "\(name)\(octave)" }

    func frequency(a4: Double) -> Double {
        a4 * pow(2, Double(midi - 69) / 12)
    }

    /// The nearest note to the given frequency.
    static func nearest(to frequency: Double, a4: Double) -> Note {
        Note(midi: Int(midiValue(for: frequency, a4: a4).rounded()))
    }

    /// Fractional MIDI note number for a frequency.
    static func midiValue(for frequency: Double, a4: Double) -> Double {
        69 + 12 * log2(frequency / a4)
    }

    /// Distance in cents from `reference` to `frequency` (positive = sharp).
    static func cents(from reference: Double, to frequency: Double) -> Double {
        1200 * log2(frequency / reference)
    }
}
