import Foundation
import UniformTypeIdentifiers

/// Represents an audio file selected for transcription
struct AudioFile: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let creationDate: Date?
    let modificationDate: Date?
    let fileSize: Int64
    let duration: TimeInterval
    let formatType: String
    let sampleRate: Double
    var status: TranscriptionStatus

    init(
        url: URL,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        fileSize: Int64 = 0,
        duration: TimeInterval = 0,
        formatType: String = "",
        sampleRate: Double = 0,
        status: TranscriptionStatus = .pending
    ) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.fileSize = fileSize
        self.duration = duration
        self.formatType = formatType
        self.sampleRate = sampleRate
        self.status = status
    }

    /// Formatted duration string (MM:SS or HH:MM:SS)
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Formatted file size string
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// Formatted creation date string
    var formattedCreationDate: String {
        guard let date = creationDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Hash function for Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Equality check for Hashable conformance
    static func == (lhs: AudioFile, rhs: AudioFile) -> Bool {
        lhs.id == rhs.id
    }
}

/// Status of transcription for an audio file
enum TranscriptionStatus: String, Codable {
    case pending
    case processing
    case completed
    case failed
}

/// Supported audio file extensions
enum SupportedAudioFormat: String, CaseIterable {
    case mp3
    case m4a
    case wav
    case aac
    case flac
    case ogg
    case wma
    case aiff
    case caf

    var utType: UTType? {
        switch self {
        case .mp3: return .mp3
        case .m4a: return .mpeg4Audio
        case .wav: return .wav
        case .aac: return .aac
        case .flac: return UTType("org.xiph.flac")
        case .ogg: return UTType("org.xiph.ogg-vorbis")
        case .wma: return UTType("com.microsoft.windows-media-wma")
        case .aiff: return .aiff
        case .caf: return UTType("com.apple.coreaudio-format")
        }
    }

    static var allUTTypes: [UTType] {
        allCases.compactMap { $0.utType }
    }

    static var allExtensions: [String] {
        allCases.map { $0.rawValue }
    }
}
