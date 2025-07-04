//
//  SessionTranscriptView.swift
//  AudioTranscriber
//
//  Created by Skanda Gonur Nagaraj on 7/3/25.
//

import SwiftUI
import SwiftData

struct SessionTranscriptView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordingSession.startTime, order: .reverse) var sessions: [RecordingSession]

    var body: some View {
        NavigationStack {
            VStack {
                Text("Sessions Loaded: \(sessions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top)

                List {
                    ForEach(sessions) { session in
                        Section(header: Text("Session: \(formatted(session.startTime))")) {
                            ForEach(session.segments) { segment in
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
                        }
                    }
                }
                .id(UUID()) // Force reload on each appearance
            }
            .navigationTitle("Past Transcripts")
            .onAppear {
                print("Found \(sessions.count) sessions")
                for session in sessions {
                    print("Session started at: \(session.startTime)")
                    for segment in session.segments {
                        print("Segment: \(segment.filePath)")
                        print("Transcript: \(segment.transcript?.text ?? "nil")")

                        // Force access to trigger lazy load if needed
                        _ = segment.transcript?.text
                    }
                }
            }
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
