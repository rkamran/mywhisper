import Foundation

enum ModelDownloaderError: LocalizedError {
    case badResponse(Int)
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .badResponse(let code): return "Server returned HTTP \(code)"
        case .writeFailed(let e): return "Failed to write model: \(e.localizedDescription)"
        }
    }
}

final class ModelDownloader: NSObject {
    static let modelName = "ggml-base.en.bin"
    static let remoteURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin")!

    static var directory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("MyWhisper", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var localPath: URL { directory.appendingPathComponent(modelName) }

    static var isDownloaded: Bool {
        guard FileManager.default.fileExists(atPath: localPath.path) else { return false }
        // Sanity check: ggml-base.en.bin is ~141 MB. Reject obvious truncations.
        let size = (try? FileManager.default.attributesOfItem(atPath: localPath.path)[.size] as? Int) ?? 0
        return size > 50_000_000
    }

    private var progressHandler: ((Double) -> Void)?
    private var continuation: CheckedContinuation<Void, Error>?

    func download(progress: @escaping (Double) -> Void) async throws {
        self.progressHandler = progress
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.downloadTask(with: ModelDownloader.remoteURL)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.continuation = cont
            task.resume()
        }
    }
}

extension ModelDownloader: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let pct = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressHandler?(pct)
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let response = downloadTask.response as? HTTPURLResponse
        let status = response?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            continuation?.resume(throwing: ModelDownloaderError.badResponse(status))
            continuation = nil
            return
        }
        let dest = ModelDownloader.localPath
        do {
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: location, to: dest)
            continuation?.resume(returning: ())
        } catch {
            continuation?.resume(throwing: ModelDownloaderError.writeFailed(error))
        }
        continuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
