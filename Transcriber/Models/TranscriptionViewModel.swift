import SwiftUI
import Combine
import UniformTypeIdentifiers
import AppKit

/// Main view model for the Transcriber application
@MainActor
final class TranscriptionViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Selected audio files for transcription
    @Published var selectedFiles: [AudioFile] = []

    /// Currently selected file ID in the sidebar
    @Published var selectedFileId: UUID?

    /// Transcription results
    @Published var transcriptionResults: [TranscriptionResult] = []

    /// Show file picker dialog
    @Published var showFilePicker = false

    /// Show folder picker dialog
    @Published var showFolderPicker = false

    /// Show error alert
    @Published var showError = false

    /// Error message to display
    @Published var errorMessage = ""

    /// Is transcription in progress
    @Published var isTranscribing = false

    /// Current file being processed
    @Published var currentFileName = ""

    /// Number of completed files
    @Published var completedFiles = 0

    /// Total number of files to process
    @Published var totalFiles = 0

    /// Overall progress (0.0 - 1.0)
    @Published var overallProgress: Double = 0

    /// Current file progress (0.0 - 1.0)
    @Published var currentFileProgress: Double = 0

    // MARK: - Private Properties

    private let transcriptionService = TranscriptionService()
    private let metadataService = AudioMetadataService()
    private var transcriptionTask: Task<Void, Never>?

    // MARK: - Computed Properties

    /// Supported audio file types for the file picker
    var supportedAudioTypes: [UTType] {
        var types: [UTType] = [.audio, .mp3, .wav, .aiff, .mpeg4Audio]
        if let aacType = UTType("public.aac-audio") {
            types.append(aacType)
        }
        types.append(contentsOf: SupportedAudioFormat.allUTTypes.compactMap { $0 })
        return types
    }

    // MARK: - File Management

    /// Add files to the selection
    func addFiles(_ urls: [URL]) {
        Task {
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    let metadata = try await metadataService.getMetadata(for: url)
                    let audioFile = AudioFile(
                        url: url,
                        creationDate: metadata.creationDate,
                        modificationDate: metadata.modificationDate,
                        fileSize: metadata.fileSize,
                        duration: metadata.duration,
                        formatType: metadata.formatType,
                        sampleRate: metadata.sampleRate
                    )

                    // Avoid duplicates
                    if !selectedFiles.contains(where: { $0.url == url }) {
                        selectedFiles.append(audioFile)
                    }
                } catch {
                    showError("Could not read file: \(url.lastPathComponent)")
                }
            }

            // Sort by creation date (oldest first)
            sortFilesByDate()
        }
    }

    /// Add all audio files from a folder
    func addFolder(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            showError("Cannot access folder")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let fileManager = FileManager.default
        let extensions = SupportedAudioFormat.allExtensions

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            showError("Cannot enumerate folder contents")
            return
        }

        var audioURLs: [URL] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if extensions.contains(ext) {
                audioURLs.append(fileURL)
            }
        }

        if audioURLs.isEmpty {
            showError("No audio files found in the selected folder")
            return
        }

        addFiles(audioURLs)
    }

    /// Remove files at given indices
    func removeFiles(at indexSet: IndexSet) {
        selectedFiles.remove(atOffsets: indexSet)
    }

    /// Clear all selected files
    func clearFiles() {
        selectedFiles.removeAll()
        transcriptionResults.removeAll()
    }

    /// Sort files by creation date (oldest first)
    private func sortFilesByDate() {
        selectedFiles.sort { file1, file2 in
            let date1 = file1.creationDate ?? Date.distantPast
            let date2 = file2.creationDate ?? Date.distantPast
            return date1 < date2
        }
    }

    // MARK: - Transcription

    /// Start transcription of all selected files
    func startTranscription() async {
        guard !selectedFiles.isEmpty else { return }

        isTranscribing = true
        completedFiles = 0
        totalFiles = selectedFiles.count
        overallProgress = 0
        currentFileProgress = 0
        transcriptionResults.removeAll()

        // Reset all file statuses
        for index in selectedFiles.indices {
            selectedFiles[index].status = .pending
        }

        transcriptionTask = Task {
            for index in selectedFiles.indices {
                guard !Task.isCancelled else { break }

                let file = selectedFiles[index]
                currentFileName = file.name
                selectedFiles[index].status = .processing

                do {
                    // Start security-scoped access
                    guard file.url.startAccessingSecurityScopedResource() else {
                        throw TranscriptionError.accessDenied
                    }
                    defer { file.url.stopAccessingSecurityScopedResource() }

                    // Perform transcription with progress updates
                    let result = try await transcriptionService.transcribe(
                        file: file,
                        progressHandler: { [weak self] progress in
                            Task { @MainActor in
                                self?.currentFileProgress = progress
                            }
                        }
                    )

                    await MainActor.run {
                        selectedFiles[index].status = .completed
                        transcriptionResults.append(result)
                        completedFiles += 1
                        overallProgress = Double(completedFiles) / Double(totalFiles)
                    }

                } catch {
                    await MainActor.run {
                        selectedFiles[index].status = .failed
                        completedFiles += 1
                        overallProgress = Double(completedFiles) / Double(totalFiles)
                    }

                    if !Task.isCancelled {
                        await MainActor.run {
                            showError("Failed to transcribe \(file.name): \(error.localizedDescription)")
                        }
                    }
                }

                currentFileProgress = 0
            }

            await MainActor.run {
                isTranscribing = false
                currentFileName = ""
            }
        }

        await transcriptionTask?.value
    }

    /// Cancel ongoing transcription
    func cancelTranscription() {
        transcriptionTask?.cancel()
        transcriptionService.cancel()
        isTranscribing = false
        currentFileName = ""

        // Reset processing files to pending
        for index in selectedFiles.indices {
            if selectedFiles[index].status == .processing {
                selectedFiles[index].status = .pending
            }
        }
    }

    // MARK: - Export & Copy

    /// Copy all transcriptions to clipboard
    func copyAllTranscriptions() {
        let allText = transcriptionResults
            .map { $0.markdownFormatted }
            .joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(allText, forType: .string)
    }

    /// Export transcriptions to a file
    func exportTranscriptions() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText, .text]
        savePanel.nameFieldStringValue = "transcriptions.md"
        savePanel.title = "Export Transcriptions"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                let allText = self.transcriptionResults
                    .map { $0.markdownFormatted }
                    .joined(separator: "\n")

                do {
                    try allText.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    self.showError("Failed to export: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Error Handling

    /// Show an error message
    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

/// Errors that can occur during transcription
enum TranscriptionError: LocalizedError {
    case accessDenied
    case invalidAudioFile
    case modelNotLoaded
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Cannot access the audio file. Please check permissions."
        case .invalidAudioFile:
            return "The file is not a valid audio file or format is not supported."
        case .modelNotLoaded:
            return "Whisper model is not loaded. Please wait for model to download."
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        }
    }
}
