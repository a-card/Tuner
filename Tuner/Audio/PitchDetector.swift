import Accelerate
import Foundation

/// Monophonic pitch detector based on the YIN algorithm
/// (de Cheveigné & Kawahara, 2002), using Accelerate for the inner products.
///
/// YIN is well suited to guitar: it is robust against the strong upper
/// harmonics of plucked strings and rarely makes octave errors.
struct PitchDetector {
    struct Result: Equatable {
        /// Detected fundamental frequency in Hz.
        let frequency: Double
        /// 0...1, where 1 means a perfectly periodic signal.
        let confidence: Double
        /// RMS level of the analysed window.
        let rms: Float
    }

    var sampleRate: Double
    /// Lowest frequency to search for. 60 Hz leaves headroom below drop tunings.
    var minFrequency: Double = 60
    /// Highest frequency to search for. 1200 Hz covers the guitar's fundamentals.
    var maxFrequency: Double = 1200
    /// YIN absolute threshold. Lower is stricter.
    var threshold: Double = 0.15
    /// If no dip falls below `threshold`, the global minimum is still accepted
    /// when it is below this value (helps with decaying notes).
    var fallbackThreshold: Double = 0.35
    /// Windows quieter than this are treated as silence.
    var minimumRMS: Float = 0.005

    /// Minimum number of samples `detect` needs for the configured range.
    var requiredSampleCount: Int {
        2 * (Int(sampleRate / minFrequency) + 2)
    }

    func detect(_ samples: [Float]) -> Result? {
        let n = samples.count
        guard n >= requiredSampleCount else { return nil }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(n))
        guard rms >= minimumRMS else { return nil }

        let tauMin = max(2, Int(sampleRate / maxFrequency))
        let tauMax = Int(sampleRate / minFrequency) + 1
        // Integration window: every lag up to tauMax stays inside the buffer.
        let window = n - tauMax - 1

        // Difference function d(tau) = sum_j (x_j - x_{j+tau})^2
        //                            = E(0) + E(tau) - 2 * r(tau)
        var difference = [Double](repeating: 0, count: tauMax + 2)
        samples.withUnsafeBufferPointer { x in
            guard let base = x.baseAddress else { return }

            var e0: Float = 0
            vDSP_svesq(base, 1, &e0, vDSP_Length(window))
            var eTau = Double(e0)

            for tau in 1...(tauMax + 1) {
                // Slide the energy window from [tau-1, tau-1+W) to [tau, tau+W).
                let leaving = Double(x[tau - 1])
                let entering = Double(x[tau - 1 + window])
                eTau += entering * entering - leaving * leaving

                var cross: Float = 0
                vDSP_dotpr(base, 1, base + tau, 1, &cross, vDSP_Length(window))
                difference[tau] = max(0, Double(e0) + eTau - 2 * Double(cross))
            }
        }

        // Cumulative mean normalised difference function.
        var cmnd = [Double](repeating: 1, count: tauMax + 2)
        var runningSum = 0.0
        for tau in 1...(tauMax + 1) {
            runningSum += difference[tau]
            cmnd[tau] = runningSum > 0 ? difference[tau] * Double(tau) / runningSum : 1
        }

        // Absolute threshold: first dip below the threshold, then walk to its bottom.
        var chosen: Int?
        var tau = tauMin
        while tau <= tauMax {
            if cmnd[tau] < threshold {
                while tau + 1 <= tauMax, cmnd[tau + 1] < cmnd[tau] {
                    tau += 1
                }
                chosen = tau
                break
            }
            tau += 1
        }

        if chosen == nil {
            // No clear dip: fall back to the global minimum if it is good enough.
            var best = tauMin
            for t in tauMin...tauMax where cmnd[t] < cmnd[best] {
                best = t
            }
            if cmnd[best] < fallbackThreshold {
                chosen = best
            }
        }

        guard let bestTau = chosen, bestTau > tauMin, bestTau < tauMax else { return nil }

        // Parabolic interpolation around the minimum for sub-sample accuracy.
        let a = cmnd[bestTau - 1]
        let b = cmnd[bestTau]
        let c = cmnd[bestTau + 1]
        let denominator = a - 2 * b + c
        var refinedTau = Double(bestTau)
        if abs(denominator) > .ulpOfOne {
            let offset = 0.5 * (a - c) / denominator
            if abs(offset) < 1 {
                refinedTau += offset
            }
        }

        let frequency = sampleRate / refinedTau
        guard frequency >= minFrequency * 0.95, frequency <= maxFrequency * 1.05 else { return nil }

        return Result(frequency: frequency, confidence: max(0, min(1, 1 - b)), rms: rms)
    }
}
