import SwiftUI

/// Detailed progress view for transcription process
struct DetailedProgressView: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel
    @State private var animationProgress: CGFloat = 0

    var body: some View {
        VStack(spacing: 20) {
            // Header with waveform animation
            HStack(spacing: 12) {
                WaveformAnimation()
                    .frame(width: 60, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Transcribing...")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Using Whisper AI for accurate speech recognition")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Current file info
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.accentColor)

                        Text(viewModel.currentFileName)
                            .font(.headline)
                            .lineLimit(1)

                        Spacer()

                        Text("Processing")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }

                    // Current file progress
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: viewModel.currentFileProgress)
                            .progressViewStyle(CustomProgressStyle(color: .accentColor))

                        HStack {
                            Text("\(Int(viewModel.currentFileProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            if viewModel.currentFileProgress > 0 && viewModel.currentFileProgress < 1 {
                                Text("Analyzing audio...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(4)
            }

            // Overall progress
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Overall Progress")
                            .font(.headline)

                        Spacer()

                        Text("\(viewModel.completedFiles) of \(viewModel.totalFiles)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    ProgressView(value: viewModel.overallProgress)
                        .progressViewStyle(CustomProgressStyle(color: .green))

                    // File queue
                    if viewModel.totalFiles > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(viewModel.selectedFiles.enumerated()), id: \.element.id) { index, file in
                                    FileProgressChip(
                                        name: file.name,
                                        status: file.status,
                                        index: index + 1
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(4)
            }

            // Cancel button
            Button(role: .destructive) {
                viewModel.cancelTranscription()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Cancel Transcription")
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

/// Custom progress bar style
struct CustomProgressStyle: ProgressViewStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geometry.size.width * (configuration.fractionCompleted ?? 0), height: 8)
                    .animation(.easeInOut(duration: 0.3), value: configuration.fractionCompleted)
            }
        }
        .frame(height: 8)
    }
}

/// Small chip showing file progress status
struct FileProgressChip: View {
    let name: String
    let status: TranscriptionStatus
    let index: Int

    var body: some View {
        HStack(spacing: 6) {
            statusIcon
                .frame(width: 16, height: 16)

            Text("\(index). \(name)")
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .cornerRadius(16)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .foregroundColor(.secondary)
        case .processing:
            ProgressView()
                .scaleEffect(0.5)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .pending:
            return Color.secondary.opacity(0.1)
        case .processing:
            return Color.accentColor.opacity(0.2)
        case .completed:
            return Color.green.opacity(0.2)
        case .failed:
            return Color.red.opacity(0.2)
        }
    }
}

/// Animated waveform visualization
struct WaveformAnimation: View {
    @State private var animating = false

    private let barCount = 5
    private let animationDuration = 0.5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(delay: Double(index) * 0.1, animating: animating)
            }
        }
        .onAppear {
            animating = true
        }
    }
}

/// Single bar in the waveform animation
struct WaveformBar: View {
    let delay: Double
    let animating: Bool

    @State private var height: CGFloat = 0.3

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.accentColor)
            .frame(width: 6)
            .scaleEffect(y: height, anchor: .center)
            .animation(
                Animation
                    .easeInOut(duration: 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: height
            )
            .onAppear {
                if animating {
                    height = 1.0
                }
            }
    }
}

#Preview {
    DetailedProgressView()
        .environmentObject({
            let vm = TranscriptionViewModel()
            return vm
        }())
        .frame(width: 500)
        .padding()
}
