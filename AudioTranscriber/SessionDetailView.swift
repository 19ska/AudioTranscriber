import SwiftUI

struct SessionDetailView: View {
    let session: RecordingSession

    var body: some View {
        List(session.segments, id: \.id) { segment in
            VStack(alignment: .leading, spacing: 4) {
                Text("Segment: \(URL(fileURLWithPath: segment.filePath).lastPathComponent)")
                    .font(.subheadline)
                    .bold()

                Text("Timestamp: \(formatted(segment.timestamp))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Status: \(segment.status.rawValue.capitalized)")
                    .font(.caption2)
                    .foregroundColor(color(for: segment.status))

                if let transcript = segment.transcript {
                    Text("Transcript:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(transcript.text)
                        .font(.body)
                        .foregroundStyle(.green)
                } else {
                    Text("Transcript: Pending…")
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Segment recorded at \(formatted(segment.timestamp))")
            .accessibilityHint(segment.transcript?.text ?? "Transcription pending")
        }
        .navigationTitle(formatted(session.startTime))
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func color(for status: TranscriptionStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .success:
            return .green
        case .failed:
            return .red
        case .fallback:
            return .blue
        }
    }
}
