import Foundation
import whisper

enum WhisperEngineError: LocalizedError {
    case modelLoadFailed
    case inferenceFailed(Int)

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed: return "Could not load Whisper model"
        case .inferenceFailed(let code): return "Whisper inference failed (\(code))"
        }
    }
}

final class WhisperEngine {
    private let ctx: OpaquePointer
    private let threadCount: Int32

    init(modelPath: String) throws {
        var params = whisper_context_default_params()
        params.use_gpu = true
        params.flash_attn = true
        guard let ctx = whisper_init_from_file_with_params(modelPath, params) else {
            throw WhisperEngineError.modelLoadFailed
        }
        self.ctx = ctx
        let cores = ProcessInfo.processInfo.activeProcessorCount
        self.threadCount = Int32(min(8, max(2, cores - 2)))
    }

    deinit {
        whisper_free(ctx)
    }

    /// Transcribes `samples` in the given `language`. Pass `"auto"` to let
    /// whisper.cpp detect the language per utterance.
    func transcribe(samples: [Float], language: String) throws -> String {
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.no_context = true
        params.single_segment = false
        params.suppress_blank = true
        params.n_threads = threadCount

        let lang = strdup(language.isEmpty ? "auto" : language)
        defer { free(lang) }
        params.language = UnsafePointer(lang)

        let status = samples.withUnsafeBufferPointer { buf -> Int32 in
            whisper_full(ctx, params, buf.baseAddress, Int32(buf.count))
        }
        guard status == 0 else {
            throw WhisperEngineError.inferenceFailed(Int(status))
        }

        let n = whisper_full_n_segments(ctx)
        var output = ""
        for i in 0..<n {
            if let cstr = whisper_full_get_segment_text(ctx, i) {
                output += String(cString: cstr)
            }
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
