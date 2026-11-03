import Foundation
import Observation

/// App state for the tuner screen: turns raw detections into a stable reading.
@MainActor
@Observable
final class TunerModel {
    struct Reading: Equatable {
        let frequency: Double
        /// The note the reading is compared against.
        let target: Note
        let targetFrequency: Double
        /// Positive = sharp, negative = flat.
        let cents: Double

        var isInTune: Bool { abs(cents) <= TunerModel.inTuneTolerance }
    }

    /// ± cents considered "in tune".
    static let inTuneTolerance = 5.0

    enum Mode: Hashable {
        /// Compare against the closest string of the selected tuning.
        case auto
        /// Compare against one string the user picked.
        case string(Note)
        /// Compare against the nearest chromatic note.
        case chromatic
    }

    // MARK: Settings (persisted)

    var tuning: Tuning {
        didSet {
            UserDefaults.standard.set(tuning.id, forKey: Keys.tuning)
            if case .string = mode { mode = .auto }
            recompute()
        }
    }

    var a4: Double {
        didSet {
            UserDefaults.standard.set(a4, forKey: Keys.a4)
            recompute()
        }
    }

    var mode: Mode = .auto {
        didSet { recompute() }
    }

    // MARK: Live state

    private(set) var reading: Reading?
    /// True while a note is currently sounding; false once the signal has faded.
    private(set) var isSignalPresent = false
    private(set) var isListening = false
    private(set) var errorMessage: String?

    // MARK: Private

    private enum Keys {
        static let tuning = "tuning"
        static let a4 = "a4"
    }

    @ObservationIgnored private let input = AudioInput()
    @ObservationIgnored private var history: [Double] = []
    @ObservationIgnored private var smoothedFrequency: Double?
    @ObservationIgnored private var lastDetection = Date.distantPast
    @ObservationIgnored private var silenceTimer: Timer?
    @ObservationIgnored private var isStarting = false

    init() {
        let defaults = UserDefaults.standard
        tuning = Tuning.with(id: defaults.string(forKey: Keys.tuning) ?? Tuning.standard.id)
        let storedA4 = defaults.double(forKey: Keys.a4)
        a4 = (420...460).contains(storedA4) ? storedA4 : 440

        input.onPitch = { [weak self] result in
            MainActor.assumeIsolated {
                self?.handle(result)
            }
        }
    }

    func start() async {
        // The launch task and a scene-phase change can both ask to start.
        guard !isListening, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        errorMessage = nil
        do {
            try await input.start()
            isListening = true
            startSilenceTimer()
        } catch {
            isListening = false
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        input.stop()
        isListening = false
        isSignalPresent = false
        silenceTimer?.invalidate()
        silenceTimer = nil
    }

    func toggleString(_ note: Note) {
        if case .string(let current) = mode, current == note {
            mode = .auto
        } else {
            mode = .string(note)
        }
    }

    // MARK: Processing

    private func handle(_ result: PitchDetector.Result?) {
        guard let result, result.confidence > 0.6 else { return }
        lastDetection = Date()
        isSignalPresent = true

        // A jump of more than ~a semitone means a new note: start over.
        if let current = smoothedFrequency,
           abs(Note.cents(from: current, to: result.frequency)) > 80 {
            history.removeAll()
            smoothedFrequency = nil
        }

        // Median of recent detections rejects occasional outliers...
        history.append(result.frequency)
        if history.count > 7 { history.removeFirst() }
        let median = history.sorted()[history.count / 2]

        // ...and a light low-pass keeps the needle from jittering.
        if let current = smoothedFrequency {
            smoothedFrequency = current + 0.35 * (median - current)
        } else {
            smoothedFrequency = median
        }
        recompute()
    }

    private func recompute() {
        guard let frequency = smoothedFrequency else {
            reading = nil
            return
        }

        let target: Note
        switch mode {
        case .auto:
            target = tuning.closestString(to: frequency, a4: a4) ?? Note.nearest(to: frequency, a4: a4)
        case .string(let note):
            target = note
        case .chromatic:
            target = Note.nearest(to: frequency, a4: a4)
        }

        let targetFrequency = target.frequency(a4: a4)
        reading = Reading(
            frequency: frequency,
            target: target,
            targetFrequency: targetFrequency,
            cents: Note.cents(from: targetFrequency, to: frequency)
        )
    }

    private func startSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.isSignalPresent, Date().timeIntervalSince(self.lastDetection) > 0.5 {
                    self.isSignalPresent = false
                    self.history.removeAll()
                }
            }
        }
    }
}
