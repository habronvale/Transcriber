import SwiftUI

/// Main entry point for the Transcriber application
/// A native macOS app for local audio transcription using Whisper
@main
struct TranscriberApp: App {
    @StateObject private var viewModel = TranscriptionViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("Open File...") {
                    viewModel.showFilePicker = true
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Open Folder...") {
                    viewModel.showFolderPicker = true
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(viewModel)
        }
    }
}

/// Settings view for configuring transcription options
struct SettingsView: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel
    @AppStorage("selectedModel") private var selectedModel = "base"
    @AppStorage("selectedLanguage") private var selectedLanguage = "auto"

    private let availableModels = ["tiny", "base", "small", "medium", "large"]
    private let availableLanguages = [
        ("auto", "Automatic"),
        ("en", "English"),
        ("de", "German"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("nl", "Dutch"),
        ("ja", "Japanese"),
        ("zh", "Chinese"),
        ("ko", "Korean"),
        ("ru", "Russian")
    ]

    var body: some View {
        Form {
            Section("Whisper Model") {
                Picker("Model", selection: $selectedModel) {
                    ForEach(availableModels, id: \.self) { model in
                        Text(model.capitalized).tag(model)
                    }
                }
                .pickerStyle(.segmented)

                Text("Larger models are more accurate but slower")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Language") {
                Picker("Language", selection: $selectedLanguage) {
                    ForEach(availableLanguages, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
            }
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}
