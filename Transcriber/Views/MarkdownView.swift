import SwiftUI

/// View for rendering transcriptions with Markdown-style formatting
struct MarkdownStyleView: View {
    let results: [TranscriptionResult]
    @State private var viewMode: ViewMode = .styled

    enum ViewMode: String, CaseIterable {
        case styled = "Styled"
        case raw = "Raw Markdown"
    }

    var body: some View {
        VStack(spacing: 0) {
            // View mode picker
            HStack {
                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()

                Button {
                    copyMarkdown()
                } label: {
                    Label("Copy Markdown", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Content
            ScrollView {
                if viewMode == .styled {
                    styledContent
                } else {
                    rawMarkdownContent
                }
            }
        }
    }

    private var styledContent: some View {
        VStack(alignment: .leading, spacing: 32) {
            ForEach(results) { result in
                VStack(alignment: .leading, spacing: 16) {
                    // H1: Filename
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 4)

                        Text(result.fileName)
                            .font(.system(size: 28, weight: .bold))
                    }
                    .padding(.bottom, 8)

                    // H2: File Information
                    Text("File Information")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.secondary)

                    // Metadata table
                    MetadataTableView(result: result)

                    // H2: Transcription
                    Text("Transcription")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)

                    // Transcription text
                    Text(result.text)
                        .font(.system(size: 16))
                        .lineSpacing(8)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                        )

                    // Divider between results
                    if result.id != results.last?.id {
                        HStack {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .padding(32)
    }

    private var rawMarkdownContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(markdownText)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var markdownText: String {
        results.map { $0.markdownFormatted }.joined(separator: "\n")
    }

    private func copyMarkdown() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdownText, forType: .string)
    }
}

/// Table view for displaying metadata
struct MetadataTableView: View {
    let result: TranscriptionResult

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Property")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Value")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))

            // Rows
            MetadataRow(property: "Created", value: result.formattedCreationDate)
            MetadataRow(property: "Duration", value: result.formattedDuration)
            MetadataRow(property: "Format", value: result.formatType.uppercased())
            MetadataRow(property: "Size", value: result.formattedFileSize)
            MetadataRow(property: "Sample Rate", value: result.formattedSampleRate)
            MetadataRow(property: "Word Count", value: "\(result.wordCount)")
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

/// Single row in the metadata table
struct MetadataRow: View {
    let property: String
    let value: String

    var body: some View {
        HStack {
            Text(property)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.clear)
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }
}

/// Export preview sheet
struct ExportPreviewView: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var exportFormat: ExportFormat = .markdown
    @State private var includeMetadata = true

    enum ExportFormat: String, CaseIterable {
        case markdown = "Markdown (.md)"
        case plainText = "Plain Text (.txt)"
        case json = "JSON (.json)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export Transcriptions")
                    .font(.headline)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Options
            Form {
                Section("Format") {
                    Picker("Export Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                Section("Options") {
                    Toggle("Include file metadata", isOn: $includeMetadata)
                }

                Section("Preview") {
                    ScrollView {
                        Text(previewText)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(4)
                }
            }
            .formStyle(.grouped)

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Export...") {
                    exportFile()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(width: 500, height: 500)
    }

    private var previewText: String {
        let results = viewModel.transcriptionResults

        switch exportFormat {
        case .markdown:
            return results.map { result in
                if includeMetadata {
                    return result.markdownFormatted
                } else {
                    return "# \(result.fileName)\n\n\(result.text)\n\n---\n"
                }
            }.joined(separator: "\n")

        case .plainText:
            return results.map { result in
                var text = "\(result.fileName)\n"
                text += String(repeating: "=", count: result.fileName.count) + "\n\n"
                if includeMetadata {
                    text += "Created: \(result.formattedCreationDate)\n"
                    text += "Duration: \(result.formattedDuration)\n"
                    text += "Format: \(result.formatType.uppercased())\n\n"
                }
                text += result.text + "\n\n"
                return text
            }.joined(separator: "\n---\n\n")

        case .json:
            let data = results.map { result -> [String: Any] in
                var dict: [String: Any] = [
                    "fileName": result.fileName,
                    "text": result.text
                ]
                if includeMetadata {
                    dict["creationDate"] = result.creationDate?.timeIntervalSince1970
                    dict["duration"] = result.duration
                    dict["format"] = result.formatType
                    dict["fileSize"] = result.fileSize
                    dict["wordCount"] = result.wordCount
                }
                return dict
            }

            if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
            return "Error generating JSON"
        }
    }

    private func exportFile() {
        let savePanel = NSSavePanel()

        switch exportFormat {
        case .markdown:
            savePanel.allowedContentTypes = [.text]
            savePanel.nameFieldStringValue = "transcriptions.md"
        case .plainText:
            savePanel.allowedContentTypes = [.plainText]
            savePanel.nameFieldStringValue = "transcriptions.txt"
        case .json:
            savePanel.allowedContentTypes = [.json]
            savePanel.nameFieldStringValue = "transcriptions.json"
        }

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try previewText.write(to: url, atomically: true, encoding: .utf8)
                    dismiss()
                } catch {
                    // Handle error
                }
            }
        }
    }
}

#Preview {
    MarkdownStyleView(results: [
        TranscriptionResult(
            fileName: "Sample Recording.m4a",
            filePath: "/path/to/file",
            text: "This is a sample transcription text that demonstrates how the markdown view displays transcription results. It includes multiple sentences to show line spacing and text flow.",
            creationDate: Date(),
            duration: 125.5,
            formatType: "m4a",
            fileSize: 2_500_000,
            sampleRate: 44100
        )
    ])
    .frame(width: 700, height: 600)
}
