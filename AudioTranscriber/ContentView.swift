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
            VStack(spacing: 20) {
                Text("Audio Transcriber")
                    .font(.largeTitle)

                Button(action: {
                    recorder.isRecording ? recorder.stopRecording() : recorder.startRecording()
                }) {
                    Text(recorder.isRecording ? "Stop Recording" : "Start Recording")
                        .padding()
                        .foregroundColor(.white)
                        .background(recorder.isRecording ? Color.red : Color.green)
                        .cornerRadius(10)
                }

                if let recordingURL = recorder.recordingURL {
                    Text("Current File: \(recordingURL.lastPathComponent)")
                        .font(.footnote)
                        .padding(.top)
                }

                NavigationLink("View Past Transcripts") {
                    SessionTranscriptView()
                }
                .padding()

                Spacer()
            }
            .padding()
            .onAppear {
                recorder.inject(modelContext: modelContext)
            }
        }
    }
}
