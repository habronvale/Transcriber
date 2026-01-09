import Foundation
import AVFoundation

/// Service for managing audio transcription
actor TranscriptionService {
    // MARK: - Properties

    private let whisperWrapper = WhisperWrapper()
    private var isCancelled = false

    @AppStorage("selectedModel") private var selectedModel = "base"
    @AppStorage("selectedLanguage") private var selectedLanguage = "auto"

    // MARK: - Initialization

    init() {}

    // MARK: - Transcription

    /// Transcribe an audio file and return the result
    func transcribe(
        file: AudioFile,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> TranscriptionResult {
        isCancelled = false

        // Ensure model is loaded
        let modelSize = WhisperWrapper.ModelSize(rawValue: UserDefaults.standard.string(forKey: "selectedModel") ?? "base") ?? .base

        // Check if model is available, download if not
        if await !whisperWrapper.isModelAvailable(size: modelSize) {
            // For now, we'll use whatever is available or instruct user
            // In a full implementation, we would trigger download here
        }

        // Load the model
        try await whisperWrapper.loadModel(size: modelSize)

        // Get language setting
        let language = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "auto"
        let langParam = language == "auto" ? nil : language

        // Perform transcription
        let output = try await whisperWrapper.transcribe(
            audioURL: file.url,
            language: langParam,
            progressHandler: progressHandler
        )

        // Create transcription result
        let segments = output.segments.map { segment in
            TranscriptionSegment(
                text: segment.text,
                startTime: segment.start,
                endTime: segment.end
            )
        }

        return TranscriptionResult(
            fileName: file.name,
            filePath: file.url.path,
            text: output.text,
            creationDate: file.creationDate,
            duration: file.duration,
            formatType: file.formatType,
            fileSize: file.fileSize,
            sampleRate: file.sampleRate,
            segments: segments
        )
    }

    /// Cancel ongoing transcription
    func cancel() {
        isCancelled = true
        Task {
            await whisperWrapper.cancel()
        }
    }

    // MARK: - Model Management

    /// Check if a model is available locally
    func isModelAvailable(_ size: WhisperWrapper.ModelSize) async -> Bool {
        await whisperWrapper.isModelAvailable(size: size)
    }

    /// Download a model
    func downloadModel(
        _ size: WhisperWrapper.ModelSize,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        try await whisperWrapper.downloadModel(size: size, progressHandler: progressHandler)
    }

    /// Get available model sizes
    var availableModels: [WhisperWrapper.ModelSize] {
        WhisperWrapper.ModelSize.allCases
    }
}

// MARK: - AppStorage wrapper for actor

@propertyWrapper
struct AppStorage<Value> {
    private let key: String
    private let defaultValue: Value

    init(wrappedValue: Value, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
    }

    var wrappedValue: Value {
        get {
            UserDefaults.standard.object(forKey: key) as? Value ?? defaultValue
        }
        nonmutating set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}
