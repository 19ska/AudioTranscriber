//
//  ContentView.swift
//  AudioTranscriber
//
//  Created by Skanda Gonur Nagaraj on 7/3/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var recorder = AudioRecorder()

    var body: some View {
        VStack(spacing: 20) {
            Text("Audio Transcriber")
                .font(.title)

            Button(action: {
                recorder.isRecording ? recorder.stopRecording() : recorder.startRecording()
            }) {
                Text(recorder.isRecording ? "Stop Recording" : "Start Recording")
                    .padding()
                    .background(recorder.isRecording ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}
