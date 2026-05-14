import AVFoundation
import Foundation
import OSLog

private let log = Logger(subsystem: "com.mywhisper.app", category: "AudioRecorder")

enum AudioRecorderError: LocalizedError {
    case converterUnavailable
    case engineFailed(Error)

    var errorDescription: String? {
        switch self {
        case .converterUnavailable: return "Could not create audio converter"
        case .engineFailed(let e): return "Audio engine failed: \(e.localizedDescription)"
        }
    }
}

final class AudioRecorder {
    private var engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = []
    private var converter: AVAudioConverter?
    private var inputPeak: Float = 0
    private var inputBufferCount: Int = 0

    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!

    func start(deviceID: AudioDeviceID? = nil) throws {
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        inputPeak = 0
        inputBufferCount = 0
        lock.unlock()

        // AVAudioEngine doesn't reliably re-start after a stop on macOS once the
        // input node's audio unit has been bound to a custom device. Build a
        // fresh engine each session.
        engine.stop()
        engine = AVAudioEngine()

        let input = engine.inputNode

        if let deviceID {
            do {
                try input.auAudioUnit.setDeviceID(deviceID)
                log.info("inputNode bound to device id=\(deviceID, privacy: .public)")
            } catch {
                log.error("setDeviceID(\(deviceID, privacy: .public)) failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        let inputFormat = input.outputFormat(forBus: 0)
        let deviceName = AudioDeviceProbe.defaultInputDeviceName() ?? "<unknown>"
        log.info("default input device: \(deviceName, privacy: .public)")
        log.info("input format: \(inputFormat.sampleRate, privacy: .public)Hz, \(inputFormat.channelCount, privacy: .public)ch, interleaved=\(inputFormat.isInterleaved, privacy: .public)")

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioRecorderError.converterUnavailable
        }
        self.converter = converter

        let bufferSize: AVAudioFrameCount = 4096
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] inBuffer, _ in
            self?.handle(buffer: inBuffer, inputFormat: inputFormat)
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw AudioRecorderError.engineFailed(error)
        }
    }

    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        lock.lock(); defer { lock.unlock() }
        log.info("input-side: \(self.inputBufferCount, privacy: .public) buffers, peak=\(String(format: "%.4f", self.inputPeak), privacy: .public)")
        return samples
    }

    private func handle(buffer inBuffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat) {
        guard let converter else { return }

        // Measure incoming amplitude so we can tell mic-silence from converter-silence.
        let inLen = Int(inBuffer.frameLength)
        if inLen > 0, let inCh = inBuffer.floatChannelData?[0] {
            var localPeak: Float = 0
            for i in 0..<inLen {
                let v = abs(inCh[i])
                if v > localPeak { localPeak = v }
            }
            lock.lock()
            if localPeak > inputPeak { inputPeak = localPeak }
            inputBufferCount += 1
            lock.unlock()
        }

        let ratio = targetFormat.sampleRate / inputFormat.sampleRate
        let outCapacity = AVAudioFrameCount(Double(inBuffer.frameLength) * ratio + 1024)
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else { return }

        var consumed = false
        var convError: NSError?
        converter.convert(to: outBuffer, error: &convError) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return inBuffer
        }
        if convError != nil { return }

        let count = Int(outBuffer.frameLength)
        guard count > 0, let channel = outBuffer.floatChannelData?[0] else { return }

        let new = Array(UnsafeBufferPointer(start: channel, count: count))
        lock.lock(); samples.append(contentsOf: new); lock.unlock()
    }
}
