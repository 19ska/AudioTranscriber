//
//  SessionDetailView.swift
//  AudioTranscriber
//
//  Created by Skanda Gonur Nagaraj on 7/3/25.
//


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

                if let transcript = segment.transcript {
                    Text("Transcript:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(transcript.text)
                        .font(.body)
                        .foregroundStyle(.green)
                } else {
                    Text("Transcript: Pending...")
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle(formatted(session.startTime))
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
