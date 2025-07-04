//
//  ContentView.swift
//  AudioTranscriber
//
//  Created by Skanda Gonur Nagaraj on 7/3/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var recorder = AudioRecorder()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Audio Transcriber")
                    .font(.largeTitle)
                    .bold()

                // Recording Status Indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(recorder.isRecording ? Color.red : Color.gray)
                        .frame(width: 12, height: 12)

                    Text(recorder.isRecording ? "Recording…" : "Not Recording")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Recording Controls
                HStack(spacing: 16) {
                    Button(action: {
                        recorder.isRecording ? recorder.stopRecording() : recorder.startRecording()
                    }) {
                        Label(recorder.isRecording ? "Stop" : "Start", systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .padding()
                            .foregroundColor(.white)
                            .background(recorder.isRecording ? Color.red : Color.green)
                            .cornerRadius(12)
                    }

                    if recorder.isRecording {
                        Button(action: {
                            recorder.isPaused ? recorder.resumeRecording() : recorder.pauseRecording()
                        }) {
                            Label(recorder.isPaused ? "Resume" : "Pause",
                                  systemImage: recorder.isPaused ? "play.circle.fill" : "pause.circle.fill")
                                .padding()
                                .foregroundColor(.white)
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                    }
                }

                // Show current recording file name
                if let recordingURL = recorder.recordingURL {
                    Text("Current File: \(recordingURL.lastPathComponent)")
                        .font(.footnote)
                        .padding(.top)
                }

                // Navigation to transcripts
                NavigationLink("View Past Transcripts") {
                    SessionListView()
                }
                .padding(.top, 20)

                Spacer()
            }
            .padding()
            .onAppear {
                recorder.inject(modelContext: modelContext)
            }
        }
    }
}
