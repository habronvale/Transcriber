import SwiftUI

/// Main content view of the Transcriber application
struct ContentView: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .frame(minWidth: 250)
        } detail: {
            MainContentView()
        }
        .navigationSplitViewStyle(.balanced)
        .fileImporter(
            isPresented: $viewModel.showFilePicker,
            allowedContentTypes: viewModel.supportedAudioTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
        .fileImporter(
            isPresented: $viewModel.showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            viewModel.addFiles(urls)
        case .failure(let error):
            viewModel.showError(error.localizedDescription)
        }
    }

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let folderURL = urls.first {
                viewModel.addFolder(folderURL)
            }
        case .failure(let error):
            viewModel.showError(error.localizedDescription)
        }
    }
}

/// Sidebar view showing file list and controls
struct SidebarView: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header with buttons
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Button {
                        viewModel.showFilePicker = true
                    } label: {
                        Label("Add Files", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.showFolderPicker = true
                    } label: {
                        Label("Add Folder", systemImage: "folder.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                // Transcribe button
                Button {
                    Task {
                        await viewModel.startTranscription()
                    }
                } label: {
                    HStack {
                        if viewModel.isTranscribing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "waveform")
                        }
                        Text(viewModel.isTranscribing ? "Transcribing..." : "Transcribe")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedFiles.isEmpty || viewModel.isTranscribing)
            }
            .padding()

            Divider()

            // File list
            if viewModel.selectedFiles.isEmpty {
                ContentUnavailableView {
                    Label("No Files Selected", systemImage: "doc.text")
                } description: {
                    Text("Add audio files or a folder to begin transcription")
                }
                .frame(maxHeight: .infinity)
            } else {
                List(selection: $viewModel.selectedFileId) {
                    ForEach(viewModel.selectedFiles) { file in
                        FileRowView(file: file)
                            .tag(file.id)
                    }
                    .onDelete { indexSet in
                        viewModel.removeFiles(at: indexSet)
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Bottom controls
            HStack {
                Text("\(viewModel.selectedFiles.count) file(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    viewModel.clearFiles()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.selectedFiles.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

/// Row view for displaying a file in the sidebar
struct FileRowView: View {
    let file: AudioFile
    @EnvironmentObject var viewModel: TranscriptionViewModel

    var body: some View {
        HStack(spacing: 10) {
            // Status icon
            statusIcon
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(.body, design: .default))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(file.formattedDuration)
                    Text("•")
                    Text(file.formatType.uppercased())
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch file.status {
        case .pending:
            Image(systemName: "circle")
                .foregroundColor(.secondary)
        case .processing:
            ProgressView()
                .scaleEffect(0.6)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
        }
    }
}

/// Main content area showing transcription results
struct MainContentView: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Progress section (shown during transcription)
            if viewModel.isTranscribing {
                TranscriptionProgressView()
            }

            // Results section
            if viewModel.transcriptionResults.isEmpty && !viewModel.isTranscribing {
                ContentUnavailableView {
                    Label("No Transcriptions", systemImage: "text.quote")
                } description: {
                    Text("Select files and click Transcribe to see results")
                }
            } else {
                TranscriptionResultsView()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !viewModel.transcriptionResults.isEmpty {
                    Button {
                        viewModel.copyAllTranscriptions()
                    } label: {
                        Label("Copy All", systemImage: "doc.on.doc")
                    }

                    Button {
                        viewModel.exportTranscriptions()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

/// Progress view shown during transcription
struct TranscriptionProgressView: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Processing: \(viewModel.currentFileName)")
                        .font(.headline)

                    Text("\(viewModel.completedFiles) of \(viewModel.totalFiles) files completed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    viewModel.cancelTranscription()
                } label: {
                    Text("Cancel")
                }
                .buttonStyle(.bordered)
            }

            ProgressView(value: viewModel.overallProgress)
                .progressViewStyle(.linear)

            if viewModel.currentFileProgress > 0 {
                HStack {
                    Text("Current file:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ProgressView(value: viewModel.currentFileProgress)
                        .progressViewStyle(.linear)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

/// View for displaying transcription results
struct TranscriptionResultsView: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(filteredResults) { result in
                    TranscriptionCardView(result: result)
                }
            }
            .padding()
        }
        .searchable(text: $searchText, prompt: "Search transcriptions")
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

/// Card view for a single transcription result
struct TranscriptionCardView: View {
    let result: TranscriptionResult
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.accentColor)

                    Text(result.fileName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    // Metadata section
                    MetadataView(result: result)

                    Divider()

                    // Transcription text
                    Text(result.text)
                        .font(.body)
                        .textSelection(.enabled)
                        .lineSpacing(4)
                }
                .padding()
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

/// Metadata display for transcription results
struct MetadataView: View {
    let result: TranscriptionResult

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], alignment: .leading, spacing: 12) {
            MetadataItem(icon: "calendar", label: "Created", value: result.formattedCreationDate)
            MetadataItem(icon: "clock", label: "Duration", value: result.formattedDuration)
            MetadataItem(icon: "waveform", label: "Format", value: result.formatType.uppercased())
            MetadataItem(icon: "ruler", label: "Size", value: result.formattedFileSize)
            MetadataItem(icon: "number", label: "Sample Rate", value: result.formattedSampleRate)
            MetadataItem(icon: "textformat.size", label: "Words", value: "\(result.wordCount)")
        }
    }
}

/// Single metadata item
struct MetadataItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.callout)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TranscriptionViewModel())
        .frame(width: 1000, height: 700)
}
