import Foundation
import LiveKit

/// Adaptive gate on outgoing audio plus a mic level meter. WebRTC calls it on its audio thread, ~10 ms per buffer,
/// after its own software noise suppression has run.
final class NoiseGate: NSObject, AudioCustomProcessingDelegate, @unchecked Sendable {
    /// Gate state that only the audio thread touches; a struct so the logic is testable on its own.
    struct Detector {
        // Opens this far above the measured room noise; closes a bit lower so it doesn't flutter at the edge.
        static let openMargin: Float = 12
        static let hysteresis: Float = 6
        // Clamp so a silent room can't make it hair-trigger, and a loud one can't swallow normal speech.
        static let openRange: ClosedRange<Float> = -55 ... -30
        // Stay open ~250 ms after the last loud buffer so word endings aren't cut off.
        static let holdBuffers = 25

        var noiseFloor: Float = -60
        var isOpen = false
        var hold = 0

        var openThreshold: Float { min(max(noiseFloor + Self.openMargin, Self.openRange.lowerBound), Self.openRange.upperBound) }

        /// Feeds one buffer's level; returns the gain target (0 or 1).
        mutating func process(db: Float) -> Float {
            // Track room noise: drop to quieter levels fast, rise over ~10 s. It learns while open too,
            // otherwise a room that is already noisy on join holds the gate open forever.
            noiseFloor += (db < noiseFloor ? 0.2 : 0.001) * (db - noiseFloor)
            let threshold = isOpen ? openThreshold - Self.hysteresis : openThreshold
            if db > threshold {
                hold = Self.holdBuffers
            } else {
                hold = max(hold - 1, 0)
            }
            isOpen = hold > 0
            return isOpen ? 1 : 0
        }
    }

    private let lock = NSLock()
    private var _level: Float = 0       // 0…1 for the UI, read from the main thread
    private var _isEnabled = true       // set from the main thread
    // Touched only on the audio thread.
    private var detector = Detector()
    private var gain: Float = 1

    var level: Float {
        lock.lock(); defer { lock.unlock() }
        return _level
    }

    var isEnabled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _isEnabled }
        set { lock.lock(); _isEnabled = newValue; lock.unlock() }
    }

    func audioProcessingInitialize(sampleRate sampleRateHz: Int, channels: Int) {
        detector = Detector()
        gain = 1
    }

    func audioProcessingRelease() {
        lock.lock(); _level = 0; lock.unlock()
    }

    func audioProcessingProcess(audioBuffer: LKAudioBuffer) {
        let frames = audioBuffer.frames
        guard frames > 0, audioBuffer.channels > 0 else { return }

        // Samples are Int16-range values stored as Float.
        let first = audioBuffer.rawBuffer(forChannel: 0)
        var sum: Float = 0
        for i in 0..<frames { sum += first[i] * first[i] }
        let db = Self.dbfs(rms: (sum / Float(frames)).squareRoot())

        let target = isEnabled ? detector.process(db: db) : 1
        if gain != 1 || target != 1 {
            // Ramp the gain across the buffer: zeroing it instantly would click.
            let step = (target - gain) / Float(frames)
            for channel in 0..<audioBuffer.channels {
                let samples = audioBuffer.rawBuffer(forChannel: channel)
                var g = gain
                for i in 0..<frames {
                    g += step
                    samples[i] *= g
                }
            }
            gain = target
        }

        let level = Self.meterLevel(db: db)
        lock.lock(); _level = level; lock.unlock()
    }

    static func dbfs(rms: Float) -> Float {
        20 * log10(max(rms / 32768, 1e-6))
    }

    /// −60 dBFS and below → 0, 0 dBFS → 1.
    static func meterLevel(db: Float) -> Float {
        min(max((db + 60) / 60, 0), 1)
    }
}
