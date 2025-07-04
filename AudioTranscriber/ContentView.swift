import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var recorder = AudioRecorder()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if !recorder.isNetworkAvailable {
                        Text("You are offline")
                            .foregroundColor(.white)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                Text("Audio Transcriber")
                    .font(.largeTitle)
                    .bold()

                
                HStack(spacing: 8) {
                    Circle()
                        .fill(recorder.isRecording ? Color.red : Color.gray)
                        .frame(width: 12, height: 12)

                    Text(recorder.isRecording ? "Recording…" : "Not Recording")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                //  Volume Level Bar
                VStack(spacing: 6) {
                    Text("Input Volume")
                        .font(.caption)
                        .foregroundColor(.gray)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 10)

                            Rectangle()
                                .fill(Color.green)
                                .frame(width: CGFloat(min(max(recorder.volumeLevel, 0.0), 1.0)) * geometry.size.width, height: 10)
                                .animation(.linear(duration: 0.1), value: recorder.volumeLevel)
                        }
                        .cornerRadius(5)
                    }
                    .frame(height: 10)
                    .padding(.horizontal)
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
        .environmentObject(recorder)
    }
}
