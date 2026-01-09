import SwiftUI

/// Main view for displaying transcription results
struct TranscriptionListView: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel
    @State private var searchText = ""
    @State private var selectedResultId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Search and filter bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search transcriptions...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .frame(height: 20)

                Text("\(filteredResults.count) result(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Results list
            if filteredResults.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No Transcriptions", systemImage: "text.quote")
                    } description: {
                        Text("Completed transcriptions will appear here")
                    }
                } else {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "magnifyingglass")
                    } description: {
                        Text("No transcriptions match '\(searchText)'")
                    }
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredResults) { result in
                                TranscriptionCardView(result: result)
                                    .id(result.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.transcriptionResults.count) { _, newCount in
                        // Auto-scroll to newest result
                        if let lastResult = viewModel.transcriptionResults.last {
                            withAnimation {
                                proxy.scrollTo(lastResult.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }

    private var filteredResults: [TranscriptionResult] {
        if searchText.isEmpty {
            return viewModel.transcriptionResults
        }
        return viewModel.transcriptionResults.filter { result in
            result.text.localizedCaseInsensitiveContains(searchText) ||
            result.fileName.localizedCaseInsensitiveContains(searchText)
        }
    }
}

/// Extended card view for a single transcription result
struct TranscriptionDetailCard: View {
    let result: TranscriptionResult
    @State private var isExpanded = true
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView

            if isExpanded {
                // Metadata section
                VStack(alignment: .leading, spacing: 16) {
                    metadataSection
                    Divider()
                    transcriptionSection
                }
                .padding()
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private var headerView: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.fileName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("\(result.wordCount) words • \(result.formattedDuration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .buttonStyle(.plain)

            // Copy button
            Button {
                copyToClipboard()
            } label: {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .foregroundColor(showCopied ? .green : .secondary)
            }
            .buttonStyle(.borderless)
            .padding(.trailing)
            .help("Copy transcription")
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("File Information")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], alignment: .leading, spacing: 12) {
                MetadataItem(icon: "calendar", label: "Created", value: result.formattedCreationDate)
                MetadataItem(icon: "clock", label: "Duration", value: result.formattedDuration)
                MetadataItem(icon: "waveform", label: "Format", value: result.formatType.uppercased())
                MetadataItem(icon: "internaldrive", label: "Size", value: result.formattedFileSize)
                MetadataItem(icon: "gauge.medium", label: "Sample Rate", value: result.formattedSampleRate)
                MetadataItem(icon: "textformat.size", label: "Words", value: "\(result.wordCount)")
            }
        }
    }

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transcription")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    copyToClipboard()
                } label: {
                    Label(showCopied ? "Copied!" : "Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text(result.text)
                .font(.body)
                .textSelection(.enabled)
                .lineSpacing(6)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.text, forType: .string)

        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopied = false
        }
    }
}

/// Combined view showing all transcriptions in markdown-style format
struct CombinedTranscriptionView: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcription Results")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Generated on \(formattedDate)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("\(viewModel.transcriptionResults.count) file(s) transcribed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Divider()

                // All transcriptions
                ForEach(viewModel.transcriptionResults) { result in
                    VStack(alignment: .leading, spacing: 16) {
                        // File header
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.accentColor)

                            Text(result.fileName)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }

                        // Metadata table
                        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                            GridRow {
                                Text("Created").foregroundColor(.secondary)
                                Text(result.formattedCreationDate)
                            }
                            GridRow {
                                Text("Duration").foregroundColor(.secondary)
                                Text(result.formattedDuration)
                            }
                            GridRow {
                                Text("Format").foregroundColor(.secondary)
                                Text(result.formatType.uppercased())
                            }
                            GridRow {
                                Text("Size").foregroundColor(.secondary)
                                Text(result.formattedFileSize)
                            }
                            GridRow {
                                Text("Words").foregroundColor(.secondary)
                                Text("\(result.wordCount)")
                            }
                        }
                        .font(.callout)

                        // Transcription text
                        Text(result.text)
                            .font(.body)
                            .textSelection(.enabled)
                            .lineSpacing(6)
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                            .cornerRadius(8)

                        if result.id != viewModel.transcriptionResults.last?.id {
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

#Preview {
    TranscriptionListView()
        .environmentObject(TranscriptionViewModel())
        .frame(width: 600, height: 500)
}
