import Foundation

/// A set of open-string pitches, listed from the lowest (6th) string to the highest (1st).
struct Tuning: Hashable, Identifiable {
    let id: String
    let name: String
    let strings: [Note]

    init(id: String, name: String, midi: [Int]) {
        self.id = id
        self.name = name
        self.strings = midi.map(Note.init(midi:))
    }

    /// The string whose target pitch is closest (in cents) to `frequency`.
    func closestString(to frequency: Double, a4: Double) -> Note? {
        strings.min { lhs, rhs in
            abs(Note.cents(from: lhs.frequency(a4: a4), to: frequency))
                < abs(Note.cents(from: rhs.frequency(a4: a4), to: frequency))
        }
    }

    static let standard = Tuning(id: "standard", name: "Standard", midi: [40, 45, 50, 55, 59, 64])
    static let dropD = Tuning(id: "dropD", name: "Drop D", midi: [38, 45, 50, 55, 59, 64])
    static let halfStepDown = Tuning(id: "halfStepDown", name: "Half Step Down", midi: [39, 44, 49, 54, 58, 63])
    static let fullStepDown = Tuning(id: "fullStepDown", name: "Full Step Down", midi: [38, 43, 48, 53, 57, 62])
    static let dropC = Tuning(id: "dropC", name: "Drop C", midi: [36, 43, 48, 53, 57, 62])
    static let dadgad = Tuning(id: "dadgad", name: "DADGAD", midi: [38, 45, 50, 55, 57, 62])
    static let openG = Tuning(id: "openG", name: "Open G", midi: [38, 43, 50, 55, 59, 62])
    static let openD = Tuning(id: "openD", name: "Open D", midi: [38, 45, 50, 54, 57, 62])
    static let openE = Tuning(id: "openE", name: "Open E", midi: [40, 47, 52, 56, 59, 64])

    static let all: [Tuning] = [standard, dropD, halfStepDown, fullStepDown, dropC, dadgad, openG, openD, openE]

    static func with(id: String) -> Tuning {
        all.first { $0.id == id } ?? .standard
    }
}
