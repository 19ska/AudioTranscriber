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
                        .accessibilityLabel("Network offline")
                        .accessibilityHint("You are currently disconnected from the internet")
                }

                Text("Audio Transcriber")
                    .font(.largeTitle)
                    .bold()
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 8) {
                    Circle()
                        .fill(recorder.isRecording ? Color.red : Color.gray)
                        .frame(width: 12, height: 12)

                    Text(recorder.isRecording ? "Recording…" : "Not Recording")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(recorder.isRecording ? "Recording in progress" : "Not recording")

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
                                .frame(
                                    width: CGFloat(min(max(recorder.volumeLevel, 0.0), 1.0)) * geometry.size.width,
                                    height: 10
                                )
                                .animation(.linear(duration: 0.1), value: recorder.volumeLevel)
                        }
                        .cornerRadius(5)
                    }
                    .accessibilityElement()
                    .accessibilityLabel("Input volume level")
                    .accessibilityValue("\(Int(recorder.volumeLevel * 100)) percent")
                    .accessibilityHint("Indicates current audio input strength")
                    .frame(height: 10)
                    .padding(.horizontal)
                }

                Picker("Audio Quality", selection: $recorder.selectedQuality) {
                    ForEach(AudioQuality.allCases) { quality in
                        Text(quality.rawValue.capitalized).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .accessibilityLabel("Select audio recording quality")
                .accessibilityHint("Choose low, medium, or high quality for recording")

                HStack(spacing: 16) {
                    Button(action: {
                        recorder.isRecording ? recorder.stopRecording() : recorder.startRecording()
                    }) {
                        Label(
                            recorder.isRecording ? "Stop" : "Start",
                            systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                        )
                        .padding()
                        .foregroundColor(.white)
                        .background(recorder.isRecording ? Color.red : Color.green)
                        .cornerRadius(12)
                    }
                    .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")
                    .accessibilityHint("Double tap to start or stop audio recording")
                    .accessibilityAddTraits(.isButton)

                    if recorder.isRecording {
                        Button(action: {
                            recorder.isPaused ? recorder.resumeRecording() : recorder.pauseRecording()
                        }) {
                            Label(
                                recorder.isPaused ? "Resume" : "Pause",
                                systemImage: recorder.isPaused ? "play.circle.fill" : "pause.circle.fill"
                            )
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.orange)
                            .cornerRadius(12)
                        }
                        .accessibilityLabel(recorder.isPaused ? "Resume recording" : "Pause recording")
                        .accessibilityHint("Double tap to pause or resume")
                        .accessibilityAddTraits(.isButton)
                    }
                }

                if let recordingURL = recorder.recordingURL {
                    Text("Current File: \(recordingURL.lastPathComponent)")
                        .font(.footnote)
                        .padding(.top)
                        .accessibilityLabel("Current recording file")
                        .accessibilityValue(recordingURL.lastPathComponent)
                }

                NavigationLink("View Past Transcripts") {
                    SessionListView()
                }
                .padding(.top, 20)
                .accessibilityLabel("View Past Transcripts")
                .accessibilityHint("Double tap to browse previous audio sessions")

                Spacer()
            }
            .padding()
            .onAppear {
                recorder.inject(modelContext: modelContext)
            }
            .alert("Microphone Access", isPresented: $recorder.showingPermissionAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(recorder.alertMessage)
            }
            .alert("Not Enough Disk Space", isPresented: $recorder.showDiskSpaceAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("There’s not enough free space to start recording. Please free up storage and try again.")
            }
        }
        .environmentObject(recorder)
    }
}
