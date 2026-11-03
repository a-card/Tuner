import AVFoundation
import Foundation

/// Captures microphone audio and runs pitch detection off the main thread.
///
/// Samples from the input tap are appended to a sliding window; every time a
/// new buffer arrives the most recent window is analysed and the result is
/// delivered through `onPitch` on the main queue.
final class AudioInput {
    enum StartError: LocalizedError {
        case permissionDenied
        case noInput

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Microphone access is turned off. Enable it in Settings › Privacy & Security › Microphone."
            case .noInput:
                return "No microphone input is available."
            }
        }
    }

    /// Called on the main queue with a detection result, or `nil` when no pitch is found.
    var onPitch: ((PitchDetector.Result?) -> Void)?

    private let engine = AVAudioEngine()
    private let analysisQueue = DispatchQueue(label: "Tuner.analysis", qos: .userInteractive)
    private var detector = PitchDetector(sampleRate: 48_000)
    private var window: [Float] = []
    private var windowSize = 4096
    private var isAnalysing = false
    private let lock = NSLock()
    private var observers: [NSObjectProtocol] = []

    private(set) var isRunning = false

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handleInterruption(note)
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isRunning else { return }
            self.stop()
            try? self.startEngine()
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        stop()
    }

    static func requestPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        default:
            return await AVAudioApplication.requestRecordPermission()
        }
    }

    func start() async throws {
        guard !isRunning else { return }
        guard await Self.requestPermission() else { throw StartError.permissionDenied }
        try startEngine()
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRunning = false
    }

    private func startEngine() throws {
        let session = AVAudioSession.sharedInstance()
        // Measurement mode turns off automatic gain control and voice processing,
        // which would otherwise colour the signal we analyse.
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw StartError.noInput }

        lock.lock()
        detector = PitchDetector(sampleRate: format.sampleRate)
        // Smallest power of two that fits two periods of the lowest frequency.
        var size = 2048
        while size < detector.requiredSampleCount { size *= 2 }
        windowSize = size
        window.removeAll(keepingCapacity: true)
        lock.unlock()

        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.receive(buffer)
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    /// Runs on the real-time audio thread: copy the samples and hand off quickly.
    private func receive(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))

        analysisQueue.async { [weak self] in
            self?.analyse(newSamples: samples)
        }
    }

    private func analyse(newSamples: [Float]) {
        lock.lock()
        window.append(contentsOf: newSamples)
        if window.count > windowSize {
            window.removeFirst(window.count - windowSize)
        }
        let ready = window.count == windowSize && !isAnalysing
        let snapshot = ready ? window : []
        let detector = self.detector
        if ready { isAnalysing = true }
        lock.unlock()

        guard ready else { return }
        let result = detector.detect(snapshot)

        lock.lock()
        isAnalysing = false
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.onPitch?(result)
        }
    }

    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            if isRunning {
                engine.inputNode.removeTap(onBus: 0)
                engine.stop()
                isRunning = false
            }
        case .ended:
            let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            if AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume) {
                try? startEngine()
            }
        @unknown default:
            break
        }
    }
}
