import SwiftUI

/// Compact progress indicator for the sidebar
struct CompactProgressIndicator: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ProgressView()
                    .scaleEffect(0.7)

                Text("Processing...")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(viewModel.completedFiles)/\(viewModel.totalFiles)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: viewModel.overallProgress)
                .progressViewStyle(.linear)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

/// Circular progress indicator with percentage
struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat

    init(progress: Double, lineWidth: CGFloat = 4, size: CGFloat = 40) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.size = size
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            // Percentage text
            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.25, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(width: size, height: size)
    }
}

/// Full-screen progress overlay
struct ProgressOverlayView: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel
    @State private var showDetails = false

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Progress card
            VStack(spacing: 24) {
                // Circular progress
                CircularProgressView(progress: viewModel.overallProgress, lineWidth: 8, size: 100)

                // Status text
                VStack(spacing: 8) {
                    Text("Transcribing Audio")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(viewModel.currentFileName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Progress details
                VStack(spacing: 4) {
                    HStack {
                        Text("Overall")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(viewModel.completedFiles) of \(viewModel.totalFiles) files")
                    }
                    .font(.caption)

                    ProgressView(value: viewModel.overallProgress)
                        .progressViewStyle(.linear)
                }

                // Cancel button
                Button(role: .destructive) {
                    viewModel.cancelTranscription()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(32)
            .frame(width: 320)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
    }
}

/// Inline progress bar for toolbar
struct ToolbarProgressView: View {
    @EnvironmentObject var viewModel: TranscriptionViewModel

    var body: some View {
        HStack(spacing: 8) {
            if viewModel.isTranscribing {
                ProgressView()
                    .scaleEffect(0.6)

                Text("\(viewModel.completedFiles)/\(viewModel.totalFiles)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ProgressView(value: viewModel.overallProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 80)
            }
        }
    }
}

/// Status badge showing transcription state
struct TranscriptionStatusBadge: View {
    let status: TranscriptionStatus

    var body: some View {
        HStack(spacing: 4) {
            statusIcon
            Text(status.rawValue.capitalized)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .pending:
            Image(systemName: "clock")
        case .processing:
            ProgressView()
                .scaleEffect(0.5)
        case .completed:
            Image(systemName: "checkmark")
        case .failed:
            Image(systemName: "exclamationmark.triangle")
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .pending:
            return Color.secondary.opacity(0.2)
        case .processing:
            return Color.accentColor.opacity(0.2)
        case .completed:
            return Color.green.opacity(0.2)
        case .failed:
            return Color.red.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .pending:
            return .secondary
        case .processing:
            return .accentColor
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

#Preview("Circular Progress") {
    VStack(spacing: 20) {
        CircularProgressView(progress: 0.25)
        CircularProgressView(progress: 0.5, size: 60)
        CircularProgressView(progress: 0.75, lineWidth: 6, size: 80)
    }
    .padding()
}

#Preview("Status Badges") {
    VStack(spacing: 10) {
        TranscriptionStatusBadge(status: .pending)
        TranscriptionStatusBadge(status: .processing)
        TranscriptionStatusBadge(status: .completed)
        TranscriptionStatusBadge(status: .failed)
    }
    .padding()
}
