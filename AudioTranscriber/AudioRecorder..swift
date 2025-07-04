//
//  AudioRecorder.swift
//  AudioTranscriber
//
//  Created by Skanda Gonur Nagaraj on 7/3/25.
//

import Foundation
import AVFoundation
import SwiftUI
import Network
import SwiftData

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    private let engine = AVAudioEngine()
    private let fileManager = FileManager.default
    private var audioFile: AVAudioFile?
    private var segmentTimer: Timer?
    private var retryCounts: [URL: Int] = [:]
    private var failedSegments: [URL] = []

    private var currentSession: RecordingSession?
    private var modelContext: ModelContext?

    private var monitor: NWPathMonitor?
    private var isNetworkAvailable: Bool = true
    private var fallbackTriggered = false

    @Published var isRecording = false
    @Published var recordingURL: URL?

    override init() {
        super.init()
        setupNotifications()
        setupNetworkMonitor()
    }

    func inject(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func startRecording() {
        currentSession = RecordingSession(startTime: Date())
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)

            try startNewSegment()

            engine.prepare()
            try engine.start()
            isRecording = true
            print("Recording started")

            segmentTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                Task { await self?.rotateSegment() }
            }

        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        segmentTimer?.invalidate()
        segmentTimer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        print("Recording stopped")

        if let fileURL = recordingURL {
            transcribe(fileURL)
           // saveSegmentToDatabase(fileURL: fileURL, transcriptText: nil)
        }
    }

    private func startNewSegment() throws {
        let formatSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false
        ]

        let fileURL = getUniqueRecordingURL(withExtension: "wav")
        audioFile = try AVAudioFile(forWriting: fileURL, settings: formatSettings)
        recordingURL = fileURL
        print("Audio segment saved at: \(fileURL.path)")

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            try? self.audioFile?.write(from: buffer)
        }

        print("Started segment: \(fileURL.lastPathComponent)")
    }

    private func getUniqueRecordingURL(withExtension ext: String = "wav") -> URL {
        let fileName = "recording_\(Int(Date().timeIntervalSince1970)).\(ext)"
        return fileManager.temporaryDirectory.appendingPathComponent(fileName)
    }

    private func rotateSegment() {
        engine.inputNode.removeTap(onBus: 0)
        engine.pause()

        guard let fileURL = recordingURL else { return }

        transcribe(fileURL)
        //saveSegmentToDatabase(fileURL: fileURL, transcriptText: "some transcription")

        do {
            try startNewSegment()
            try engine.start()
        } catch {
            print("Failed to rotate segment: \(error.localizedDescription)")
        }
    }

    private func transcribe(_ fileURL: URL) {
        guard isNetworkAvailable else {
            print("Network unavailable, queued segment: \(fileURL.lastPathComponent)")
            failedSegments.append(fileURL)
            return
        }

        Task {
            do {
                try await whisperTranscriptionAPI(fileURL: fileURL)
                print("Transcription success: \(fileURL.lastPathComponent)")
                retryCounts[fileURL] = 0
            } catch {
                print(" Transcription failed: \(fileURL.lastPathComponent)")
                let currentRetry = retryCounts[fileURL, default: 0] + 1
                retryCounts[fileURL] = currentRetry

                if currentRetry >= 5 {
                    print(" Fallback to local transcription for: \(fileURL.lastPathComponent)")
                    fallbackToLocalTranscription(fileURL)
                } else {
                    failedSegments.append(fileURL)
                    let delay = pow(2.0, Double(currentRetry))
                    print(" Retrying in \(delay) sec")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.transcribe(fileURL)
                    }
                }
            }
        }
    }
    
    private func fallbackToLocalTranscription(_ fileURL: URL) {
        // You can replace this with actual Apple Speech API later
        print("Local transcription triggered for \(fileURL.lastPathComponent)")
        saveSegmentToDatabase(fileURL: fileURL, transcriptText: "[Local fallback transcription]")
    }

    private func whisperTranscriptionAPI(fileURL: URL) async throws {
        guard let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !openAIKey.isEmpty else {
            print("Missing OPENAI_API_KEY environment variable.")
            return
        }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var data = Data()

        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        data.append(try Data(contentsOf: fileURL))
        data.append("\r\n".data(using: .utf8)!)

        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        data.append("whisper-1\r\n".data(using: .utf8)!)

        data.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("Status Code: \(httpResponse.statusCode)")

            let responseString = String(data: responseData, encoding: .utf8) ?? "No response body"
            print("Response: \(responseString)")

            if httpResponse.statusCode != 200 {
                throw URLError(.badServerResponse)
            }
        }
        if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let text = json["text"] as? String {
                print("Final transcript: \(text)")
                saveSegmentToDatabase(fileURL: fileURL, transcriptText: text)
            }
    }

    private func saveSegmentToDatabase(fileURL: URL, transcriptText: String? = nil) {
        guard let modelContext = modelContext else { return }

        let segment = Segment(filePath: fileURL.path, timestamp: Date())

        if let text = transcriptText {
            let transcript = Transcript(text: text)
            segment.transcript = transcript
        }

        currentSession?.segments.append(segment)

        // Ensure session is inserted only once
        if let session = currentSession {
            if session.persistentModelID == nil {
                modelContext.insert(session)
            }
            modelContext.insert(segment)
            if let transcript = segment.transcript {
                modelContext.insert(transcript)
            }
        }

        try? modelContext.save()
        print("Saved segment: \(segment.filePath)")
       // print("Transcript: \(segment.transcript?.text ?? "nil")")
    }

    private func setupNetworkMonitor() {
        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isNetworkAvailable = path.status == .satisfied
                print("Network status: \(self.isNetworkAvailable ? "Online" : "Offline")")

                if self.isNetworkAvailable {
                    self.retryQueuedSegments()
                }
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor?.start(queue: queue)
    }

    private func retryQueuedSegments() {
        for fileURL in failedSegments {
            transcribe(fileURL)
        }
        failedSegments.removeAll()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if type == .began {
            stopRecording()
        }
    }
}
