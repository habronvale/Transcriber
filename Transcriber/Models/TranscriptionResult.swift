import Foundation

/// Represents the result of a transcription operation
struct TranscriptionResult: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let filePath: String
    let text: String
    let creationDate: Date?
    let duration: TimeInterval
    let formatType: String
    let fileSize: Int64
    let sampleRate: Double
    let transcriptionDate: Date
    let segments: [TranscriptionSegment]

    init(
        id: UUID = UUID(),
        fileName: String,
        filePath: String,
        text: String,
        creationDate: Date?,
        duration: TimeInterval,
        formatType: String,
        fileSize: Int64,
        sampleRate: Double,
        transcriptionDate: Date = Date(),
        segments: [TranscriptionSegment] = []
    ) {
        self.id = id
        self.fileName = fileName
        self.filePath = filePath
        self.text = text
        self.creationDate = creationDate
        self.duration = duration
        self.formatType = formatType
        self.fileSize = fileSize
        self.sampleRate = sampleRate
        self.transcriptionDate = transcriptionDate
        self.segments = segments
    }

    /// Formatted duration string
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

    /// Formatted file size
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// Formatted creation date
    var formattedCreationDate: String {
        guard let date = creationDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Formatted sample rate (e.g., "44.1 kHz")
    var formattedSampleRate: String {
        if sampleRate >= 1000 {
            return String(format: "%.1f kHz", sampleRate / 1000)
        }
        return "\(Int(sampleRate)) Hz"
    }

    /// Word count in the transcription
    var wordCount: Int {
        text.split(separator: " ").count
    }

    /// Export as Markdown formatted text
    var markdownFormatted: String {
        var output = "# \(fileName)\n\n"
        output += "## File Information\n\n"
        output += "| Property | Value |\n"
        output += "|----------|-------|\n"
        output += "| Created | \(formattedCreationDate) |\n"
        output += "| Duration | \(formattedDuration) |\n"
        output += "| Format | \(formatType.uppercased()) |\n"
        output += "| Size | \(formattedFileSize) |\n"
        output += "| Sample Rate | \(formattedSampleRate) |\n"
        output += "| Word Count | \(wordCount) |\n\n"
        output += "## Transcription\n\n"
        output += text
        output += "\n\n---\n\n"
        return output
    }
}

/// Represents a segment of transcribed text with timing information
struct TranscriptionSegment: Identifiable, Codable {
    let id: UUID
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval

    init(
        id: UUID = UUID(),
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }

    /// Formatted start time
    var formattedStartTime: String {
        formatTime(startTime)
    }

    /// Formatted end time
    var formattedEndTime: String {
        formatTime(endTime)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
}
