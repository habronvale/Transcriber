import SwiftUI

/// Drop zone view for dragging and dropping audio files
struct FileDropZone: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 48))
                .foregroundColor(isTargeted ? .accentColor : .secondary)

            Text("Drop audio files here")
                .font(.headline)
                .foregroundColor(isTargeted ? .accentColor : .primary)

            Text("or use the buttons above to select files")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach(["MP3", "M4A", "WAV", "AAC", "FLAC"], id: \.self) { format in
                    Text(format)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
        )
        .padding()
        .onDrop(of: [.audio, .fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                    guard error == nil,
                          let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else {
                        return
                    }

                    DispatchQueue.main.async {
                        // Check if it's a directory or file
                        var isDirectory: ObjCBool = false
                        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                            if isDirectory.boolValue {
                                viewModel.addFolder(url)
                            } else {
                                viewModel.addFiles([url])
                            }
                        }
                    }
                }
                handled = true
            }
        }

        return handled
    }
}

/// Quick action buttons for file operations
struct FileActionButtons: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel
    let compact: Bool

    init(compact: Bool = false) {
        self.compact = compact
    }

    var body: some View {
        Group {
            if compact {
                HStack(spacing: 8) {
                    compactButton(title: "File", icon: "doc.badge.plus") {
                        viewModel.showFilePicker = true
                    }

                    compactButton(title: "Folder", icon: "folder.badge.plus") {
                        viewModel.showFolderPicker = true
                    }
                }
            } else {
                VStack(spacing: 12) {
                    expandedButton(title: "Add Audio Files", icon: "doc.badge.plus", shortcut: "O") {
                        viewModel.showFilePicker = true
                    }

                    expandedButton(title: "Add Folder", icon: "folder.badge.plus", shortcut: "Shift+O") {
                        viewModel.showFolderPicker = true
                    }
                }
            }
        }
    }

    private func compactButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.bordered)
    }

    private func expandedButton(title: String, icon: String, shortcut: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 32)

                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                    Text("Keyboard: Cmd+\(shortcut)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

/// Empty state view when no files are selected
struct EmptyStateView: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("Welcome to Transcriber")
                    .font(.title)

                Text("Select audio files or a folder to begin transcription")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            FileActionButtons(compact: false)
                .frame(maxWidth: 400)

            Divider()
                .frame(maxWidth: 300)

            FileDropZone()
                .frame(maxWidth: 500, maxHeight: 200)
        }
        .padding(40)
    }
}

#Preview {
    EmptyStateView()
        .environmentObject(TranscriptionViewModel())
        .frame(width: 600, height: 600)
}
