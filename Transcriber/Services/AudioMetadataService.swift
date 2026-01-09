import Foundation
import AVFoundation

/// Service for extracting metadata from audio files
actor AudioMetadataService {

    /// Metadata extracted from an audio file
    struct AudioMetadata {
        let creationDate: Date?
        let modificationDate: Date?
        let fileSize: Int64
        let duration: TimeInterval
        let formatType: String
        let sampleRate: Double
        let channelCount: Int
        let bitRate: Int
    }

    /// Get metadata for an audio file at the given URL
    func getMetadata(for url: URL) async throws -> AudioMetadata {
        // Get file attributes
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: url.path)

        let creationDate = attributes[.creationDate] as? Date
        let modificationDate = attributes[.modificationDate] as? Date
        let fileSize = attributes[.size] as? Int64 ?? 0

        // Get audio properties using AVFoundation
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds

        // Get audio format details
        var formatType = url.pathExtension.lowercased()
        var sampleRate: Double = 0
        var channelCount: Int = 0
        var bitRate: Int = 0

        // Load audio tracks
        let tracks = try await asset.load(.tracks)
        if let audioTrack = tracks.first(where: { $0.mediaType == .audio }) {
            // Get format descriptions
            let formatDescriptions = try await audioTrack.load(.formatDescriptions)
            if let formatDescription = formatDescriptions.first {
                let audioDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                if let asbd = audioDesc?.pointee {
                    sampleRate = asbd.mSampleRate
                    channelCount = Int(asbd.mChannelsPerFrame)
                }

                // Get format name
                if let formatName = getFormatName(from: formatDescription) {
                    formatType = formatName
                }
            }

            // Estimate bit rate
            let estimatedDataRate = try? await audioTrack.load(.estimatedDataRate)
            bitRate = Int(estimatedDataRate ?? 0)
        }

        return AudioMetadata(
            creationDate: creationDate,
            modificationDate: modificationDate,
            fileSize: fileSize,
            duration: duration.isNaN ? 0 : duration,
            formatType: formatType,
            sampleRate: sampleRate,
            channelCount: channelCount,
            bitRate: bitRate
        )
    }

    /// Get a human-readable format name from a format description
    private func getFormatName(from formatDescription: CMFormatDescription) -> String? {
        let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)

        switch mediaSubType {
        case kAudioFormatLinearPCM:
            return "wav"
        case kAudioFormatMPEG4AAC, kAudioFormatMPEG4AAC_HE, kAudioFormatMPEG4AAC_HE_V2:
            return "aac"
        case kAudioFormatMPEGLayer3:
            return "mp3"
        case kAudioFormatAppleLossless:
            return "alac"
        case kAudioFormatFLAC:
            return "flac"
        case kAudioFormatOpus:
            return "opus"
        default:
            // Return FourCC code as string
            let fourCC = [
                UInt8((mediaSubType >> 24) & 0xFF),
                UInt8((mediaSubType >> 16) & 0xFF),
                UInt8((mediaSubType >> 8) & 0xFF),
                UInt8(mediaSubType & 0xFF)
            ]
            return String(bytes: fourCC, encoding: .ascii)?.trimmingCharacters(in: .whitespaces)
        }
    }
}

/// Extension for formatting audio metadata
extension AudioMetadataService.AudioMetadata {
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

    /// Formatted sample rate
    var formattedSampleRate: String {
        if sampleRate >= 1000 {
            return String(format: "%.1f kHz", sampleRate / 1000)
        }
        return "\(Int(sampleRate)) Hz"
    }

    /// Formatted bit rate
    var formattedBitRate: String {
        if bitRate >= 1000 {
            return "\(bitRate / 1000) kbps"
        }
        return "\(bitRate) bps"
    }
}
