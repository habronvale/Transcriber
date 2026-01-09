# Transcriber

A native macOS application for local audio transcription using Whisper AI, built with Swift and SwiftUI for Apple Silicon Macs.

## Features

- **Local Transcription**: All transcription happens locally on your Mac using Whisper - no data leaves your device
- **Multiple Audio Formats**: Supports MP3, M4A, WAV, AAC, FLAC, AIFF, and more
- **Batch Processing**: Transcribe entire folders of audio files at once
- **File Metadata Display**: Shows creation date, duration, format, file size, and sample rate
- **Chronological Ordering**: When processing folders, files are sorted by creation date (oldest first)
- **Progress Tracking**: Real-time progress bar with current file status
- **Markdown Export**: Export transcriptions in Markdown, plain text, or JSON format
- **Modern UI**: Built with SwiftUI following Apple Human Interface Guidelines
- **Apple Silicon Optimized**: Built specifically for M1/M2/M3 Macs

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon Mac (M1, M2, M3, or later)
- Whisper.cpp installed via Homebrew (recommended)

## Installation

### 1. Install Whisper

The application uses whisper.cpp for transcription. Install it using Homebrew:

```bash
brew install whisper-cpp
```

### 2. Download Whisper Models

Download the Whisper model you want to use:

```bash
# For the base model (recommended for most uses)
whisper-cpp-download-ggml-model base

# Other options: tiny, small, medium, large
whisper-cpp-download-ggml-model small
```

### 3. Build the Application

Open the project in Xcode:

```bash
cd Transcriber
open Transcriber.xcodeproj
```

Then build and run (Cmd+R).

## Usage

1. **Add Files**: Click "Add Files" or "Add Folder" to select audio files for transcription
2. **Transcribe**: Click the "Transcribe" button to start processing
3. **View Results**: Transcriptions appear in the main view with file metadata
4. **Export**: Use the export button to save transcriptions as Markdown, text, or JSON

### Keyboard Shortcuts

- `Cmd+O`: Open file picker
- `Cmd+Shift+O`: Open folder picker
- `Cmd+,`: Open settings

## Project Structure

```
Transcriber/
├── TranscriberApp.swift          # App entry point
├── ContentView.swift             # Main content view
├── Models/
│   ├── AudioFile.swift           # Audio file model
│   ├── TranscriptionResult.swift # Transcription result model
│   └── TranscriptionViewModel.swift # Main view model
├── Views/
│   ├── FilePickerView.swift      # File selection views
│   ├── TranscriptionView.swift   # Results display
│   ├── TranscriptionProgressView.swift # Progress indicators
│   └── MarkdownView.swift        # Markdown rendering
├── Services/
│   ├── TranscriptionService.swift    # Transcription orchestration
│   ├── AudioMetadataService.swift    # Audio metadata extraction
│   └── WhisperWrapper.swift          # Whisper integration
└── Resources/
    ├── Info.plist
    ├── Transcriber.entitlements
    └── Assets.xcassets/
```

## Settings

Access settings via the menu bar (Transcriber > Settings) or `Cmd+,`:

- **Model Size**: Choose between tiny, base, small, medium, or large models
- **Language**: Set the language for transcription or use automatic detection

## Whisper Model Comparison

| Model  | Size    | Speed   | Accuracy |
|--------|---------|---------|----------|
| tiny   | ~75 MB  | Fastest | Basic    |
| base   | ~142 MB | Fast    | Good     |
| small  | ~466 MB | Medium  | Better   |
| medium | ~1.5 GB | Slow    | Great    |
| large  | ~2.9 GB | Slowest | Best     |

## Technical Details

- **Framework**: SwiftUI with AppKit integration
- **Audio Processing**: AVFoundation for audio conversion (16kHz mono WAV)
- **Transcription**: whisper.cpp via command-line or bundled binary
- **Concurrency**: Swift async/await with actor isolation
- **Architecture**: MVVM with services layer

## Privacy

All audio processing happens locally on your device. No audio data is sent to external servers. The only network access is for downloading Whisper models.

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
