import Foundation
import LiveKit

/// Gate on outgoing audio plus a mic level meter. WebRTC calls it on its audio thread, ~10 ms per buffer,
/// after its own software noise suppression has run.
final class NoiseGate: NSObject, AudioCustomProcessingDelegate, @unchecked Sendable {
    // Opening threshold in dBFS: voice into the built-in mic is roughly −35…−20, room noise and screen taps sit lower.
    static let openThreshold: Float = -45
    // Stay open ~250 ms after the last loud buffer so word endings aren't cut off.
    private static let holdBuffers = 25

    private let lock = NSLock()
    private var _level: Float = 0   // 0…1 for the UI, read from the main thread
    // Touched only on the audio thread.
    private var gain: Float = 0
    private var hold = 0

    var level: Float {
        lock.lock(); defer { lock.unlock() }
        return _level
    }

    func audioProcessingInitialize(sampleRate sampleRateHz: Int, channels: Int) {
        gain = 0
        hold = 0
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

        hold = db > Self.openThreshold ? Self.holdBuffers : max(hold - 1, 0)
        let target: Float = hold > 0 ? 1 : 0
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
