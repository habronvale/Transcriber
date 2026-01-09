import Foundation
import AVFoundation
import Accelerate

/// Wrapper for Whisper transcription functionality
/// Uses whisper.cpp via a bundled binary or WhisperKit when available
actor WhisperWrapper {
    // MARK: - Types

    /// Whisper model sizes
    enum ModelSize: String, CaseIterable {
        case tiny = "tiny"
        case base = "base"
        case small = "small"
        case medium = "medium"
        case large = "large"

        var displayName: String {
            rawValue.capitalized
        }

        var estimatedSize: String {
            switch self {
            case .tiny: return "~75 MB"
            case .base: return "~142 MB"
            case .small: return "~466 MB"
            case .medium: return "~1.5 GB"
            case .large: return "~2.9 GB"
            }
        }
    }

    /// Transcription output with timing information
    struct TranscriptionOutput {
        let text: String
        let segments: [Segment]

        struct Segment {
            let text: String
            let start: TimeInterval
            let end: TimeInterval
        }
    }

    // MARK: - Properties

    private var isModelLoaded = false
    private var currentModelSize: ModelSize = .base
    private var isCancelled = false

    // MARK: - Model Management

    /// Check if the model is downloaded and available
    func isModelAvailable(size: ModelSize) -> Bool {
        let modelURL = getModelURL(for: size)
        return FileManager.default.fileExists(atPath: modelURL.path)
    }

    /// Get the URL for a model file
    private func getModelURL(for size: ModelSize) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appendingPathComponent("Transcriber/Models", isDirectory: true)
        return modelsDir.appendingPathComponent("ggml-\(size.rawValue).bin")
    }

    /// Download a Whisper model
    func downloadModel(size: ModelSize, progressHandler: @escaping (Double) -> Void) async throws {
        let modelURL = getModelURL(for: size)
        let modelsDir = modelURL.deletingLastPathComponent()

        // Create models directory if needed
        try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        // Download URL for whisper.cpp models
        let downloadURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-\(size.rawValue).bin")!

        let (tempURL, response) = try await URLSession.shared.download(from: downloadURL) { progress in
            Task { @MainActor in
                progressHandler(progress.fractionCompleted)
            }
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WhisperError.downloadFailed
        }

        // Move to final location
        if FileManager.default.fileExists(atPath: modelURL.path) {
            try FileManager.default.removeItem(at: modelURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: modelURL)
    }

    /// Load a model for transcription
    func loadModel(size: ModelSize) async throws {
        guard isModelAvailable(size: size) else {
            throw WhisperError.modelNotFound
        }

        currentModelSize = size
        isModelLoaded = true
    }

    // MARK: - Transcription

    /// Transcribe an audio file
    func transcribe(
        audioURL: URL,
        language: String? = nil,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> TranscriptionOutput {
        isCancelled = false

        // Convert audio to WAV format suitable for Whisper (16kHz, mono, 16-bit)
        let processedURL = try await prepareAudioForWhisper(audioURL)
        defer {
            try? FileManager.default.removeItem(at: processedURL)
        }

        // Use whisper.cpp command line tool or simulate for development
        let result = try await performTranscription(
            audioURL: processedURL,
            language: language,
            progressHandler: progressHandler
        )

        return result
    }

    /// Cancel ongoing transcription
    func cancel() {
        isCancelled = true
    }

    // MARK: - Audio Preparation

    /// Prepare audio file for Whisper (convert to 16kHz mono WAV)
    private func prepareAudioForWhisper(_ inputURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)

        // Create temporary output file
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent(UUID().uuidString + ".wav")

        // Configure audio export settings for Whisper
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        // Export using AVAssetExportSession
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw WhisperError.audioConversionFailed
        }

        // For actual conversion, we need to use AVAssetReader/Writer
        try await convertAudio(from: inputURL, to: outputURL, settings: audioSettings)

        return outputURL
    }

    /// Convert audio using AVAssetReader and AVAssetWriter
    private func convertAudio(from inputURL: URL, to outputURL: URL, settings: [String: Any]) async throws {
        let asset = AVURLAsset(url: inputURL)
        let tracks = try await asset.load(.tracks)

        guard let audioTrack = tracks.first(where: { $0.mediaType == .audio }) else {
            throw WhisperError.noAudioTrack
        }

        // Setup reader
        let reader = try AVAssetReader(asset: asset)
        let readerSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: readerSettings)
        reader.add(readerOutput)

        // Setup writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .wav)
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        writer.add(writerInput)

        // Start conversion
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        await withCheckedContinuation { continuation in
            writerInput.requestMediaDataWhenReady(on: DispatchQueue(label: "audio.conversion")) {
                while writerInput.isReadyForMoreMediaData {
                    if self.isCancelled {
                        reader.cancelReading()
                        writer.cancelWriting()
                        continuation.resume()
                        return
                    }

                    if let buffer = readerOutput.copyNextSampleBuffer() {
                        writerInput.append(buffer)
                    } else {
                        writerInput.markAsFinished()
                        writer.finishWriting {
                            continuation.resume()
                        }
                        return
                    }
                }
            }
        }

        guard writer.status == .completed else {
            throw WhisperError.audioConversionFailed
        }
    }

    // MARK: - Transcription Implementation

    /// Perform the actual transcription using whisper.cpp or built-in processing
    private func performTranscription(
        audioURL: URL,
        language: String?,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> TranscriptionOutput {
        // Check for whisper.cpp binary in app bundle
        let whisperPath = Bundle.main.path(forResource: "whisper", ofType: nil)

        if let whisperPath = whisperPath, FileManager.default.fileExists(atPath: whisperPath) {
            // Use bundled whisper.cpp
            return try await runWhisperCLI(
                whisperPath: whisperPath,
                audioURL: audioURL,
                modelPath: getModelURL(for: currentModelSize).path,
                language: language,
                progressHandler: progressHandler
            )
        } else {
            // Fallback: Use system whisper if installed, or simulate
            return try await runSystemWhisper(
                audioURL: audioURL,
                language: language,
                progressHandler: progressHandler
            )
        }
    }

    /// Run whisper.cpp command line tool
    private func runWhisperCLI(
        whisperPath: String,
        audioURL: URL,
        modelPath: String,
        language: String?,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> TranscriptionOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: whisperPath)

        var arguments = [
            "-m", modelPath,
            "-f", audioURL.path,
            "--output-json",
            "--print-progress"
        ]

        if let language = language, language != "auto" {
            arguments += ["-l", language]
        }

        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        // Monitor progress from stderr
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw WhisperError.transcriptionFailed(errorString)
        }

        // Parse JSON output
        return try parseWhisperOutput(outputData)
    }

    /// Run system-installed whisper or provide simulated output
    private func runSystemWhisper(
        audioURL: URL,
        language: String?,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> TranscriptionOutput {
        // Try to find whisper in common locations
        let whisperPaths = [
            "/usr/local/bin/whisper",
            "/opt/homebrew/bin/whisper",
            "/usr/bin/whisper"
        ]

        for path in whisperPaths {
            if FileManager.default.fileExists(atPath: path) {
                // Found system whisper, use it
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)

                var arguments = [
                    audioURL.path,
                    "--model", currentModelSize.rawValue,
                    "--output_format", "json",
                    "--output_dir", FileManager.default.temporaryDirectory.path
                ]

                if let language = language, language != "auto" {
                    arguments += ["--language", language]
                }

                process.arguments = arguments

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                try process.run()

                // Simulate progress
                for i in 1...10 {
                    if isCancelled { throw WhisperError.cancelled }
                    try await Task.sleep(nanoseconds: 100_000_000)
                    progressHandler(Double(i) / 10.0)
                }

                process.waitUntilExit()

                // Read JSON output file
                let outputName = audioURL.deletingPathExtension().lastPathComponent + ".json"
                let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(outputName)

                if FileManager.default.fileExists(atPath: outputURL.path) {
                    let data = try Data(contentsOf: outputURL)
                    try? FileManager.default.removeItem(at: outputURL)
                    return try parseWhisperOutput(data)
                }
            }
        }

        // No whisper found - provide instructions
        throw WhisperError.whisperNotInstalled
    }

    /// Parse Whisper JSON output
    private func parseWhisperOutput(_ data: Data) throws -> TranscriptionOutput {
        struct WhisperJSON: Decodable {
            let text: String
            let segments: [SegmentJSON]?

            struct SegmentJSON: Decodable {
                let text: String
                let start: Double
                let end: Double
            }
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(WhisperJSON.self, from: data)

        let segments = result.segments?.map { seg in
            TranscriptionOutput.Segment(
                text: seg.text,
                start: seg.start,
                end: seg.end
            )
        } ?? []

        return TranscriptionOutput(text: result.text.trimmingCharacters(in: .whitespacesAndNewlines), segments: segments)
    }
}

// MARK: - Errors

enum WhisperError: LocalizedError {
    case modelNotFound
    case downloadFailed
    case audioConversionFailed
    case noAudioTrack
    case transcriptionFailed(String)
    case cancelled
    case whisperNotInstalled

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Whisper model not found. Please download a model first."
        case .downloadFailed:
            return "Failed to download the model. Please check your internet connection."
        case .audioConversionFailed:
            return "Failed to convert audio to the required format."
        case .noAudioTrack:
            return "No audio track found in the file."
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .cancelled:
            return "Transcription was cancelled."
        case .whisperNotInstalled:
            return "Whisper is not installed. Please install whisper.cpp or OpenAI Whisper using: brew install whisper-cpp"
        }
    }
}

// MARK: - URLSession Extension for Progress

extension URLSession {
    func download(from url: URL, progressHandler: @escaping (Progress) -> Void) async throws -> (URL, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = self.downloadTask(with: url) { url, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = url, let response = response {
                    continuation.resume(returning: (url, response))
                } else {
                    continuation.resume(throwing: URLError(.unknown))
                }
            }

            // Observe progress
            let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                progressHandler(progress)
            }

            task.resume()

            // Store observation to prevent deallocation
            objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}
