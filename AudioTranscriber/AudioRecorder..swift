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
import Speech


enum AudioQuality: String, CaseIterable, Identifiable {
    case low, medium, high

    var id: String { rawValue }

    var settings: [String: Any] {
        switch self {
        case .low:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 8000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 8,
                AVLinearPCMIsFloatKey: false
            ]
        case .medium:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false
            ]
        case .high:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false
            ]
        }
    }
}

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
    @Published var isNetworkAvailable: Bool = true
    private var fallbackTriggered = false

    @Published var isRecording = false
    @Published var recordingURL: URL?
    @Published var isPaused = false
    @Published var volumeLevel: Float = 0.0
    @Published var selectedQuality: AudioQuality = .high
    @Published var showingPermissionAlert = false
    @Published var alertMessage = ""
    @Published var showDiskSpaceAlert: Bool = false

    override init() {
        super.init()
        setupNotifications()
        setupNetworkMonitor()
        restoreFailedSegmentsFromDisk()
    }

    func inject(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func startRecording() {
        // Check current microphone permission status
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            beginRecording()

        case .denied:
            DispatchQueue.main.async {
                self.alertMessage = "Microphone access is denied. Please enable it in Settings."
                self.showingPermissionAlert = true
            }

        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                // This callback runs on a background thread, so UI updates must be dispatched to the main queue
                DispatchQueue.main.async {
                    if granted {
                        self.beginRecording()
                    } else {
                        self.alertMessage = "Microphone access is required to record audio."
                        self.showingPermissionAlert = true
                    }
                }
            }

        @unknown default:
            print("Unknown microphone permission status")
        }
    }
    
    
    func beginRecording() {
        currentSession = RecordingSession(startTime: Date())
        // Start a new recording session with current timestamp
        let session = AVAudioSession.sharedInstance()
        do {
            // Configure the AVAudioSession category for both playback and recording
            // This setup supports Bluetooth, default-to-speaker, and mixing with other audio
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers, .duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            guard hasSufficientDiskSpace() else {
                DispatchQueue.main.async {
                    self.showDiskSpaceAlert = true
                }
                return
            }
            
            let formatSettings = selectedQuality.settings
            let fileName = "recording_\(Date().timeIntervalSince1970).wav"
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            recordingURL = fileURL

            audioFile = try AVAudioFile(forWriting: fileURL, settings: formatSettings)

            let inputNode = engine.inputNode
            let format = inputNode.inputFormat(forBus: 0)
            
            // Install tap on input node to receive PCM buffers in real time
            // This closure executes on an internal audio thread
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                self.processVolume(from: buffer)
                try? self.audioFile?.write(from: buffer)
            }

            engine.prepare()
            try engine.start()

            isRecording = true
            print("Recording started")

            // Schedule a timer that fires every 30 seconds to rotate segments
            // Wrapping in a Task ensures async support for rotateSegment() (uses async/await)
            segmentTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                Task { await self?.rotateSegment() }
            }

        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    
    // Checks if the device has enough free disk space before recording audio.
    // This prevents failures due to I/O issues when the disk is full.
    func hasSufficientDiskSpace(thresholdInMB: Double = 50) -> Bool {
        if let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSize = systemAttributes[.systemFreeSize] as? NSNumber {
            let freeMB = freeSize.doubleValue / (1024 * 1024)
            return freeMB > thresholdInMB
        }
        return false
    }
    
    
    // Computes the root-mean-square (RMS) volume from the incoming audio buffer
    //  and updates a normalized UI volume level between 0 and 1.
    func processVolume(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }
        // Root Mean Square (RMS) is used as an estimate of signal volume
        let rms = sqrt(sum / Float(frameLength))

        
        let normalizedVolume = CGFloat(rms) * 20
        DispatchQueue.main.async {
            self.volumeLevel = Float(min(max(normalizedVolume, 0), 1))        }
    }

    func stopRecording() {
        segmentTimer?.invalidate()
        segmentTimer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        print("Recording stopped")

        guard let url = recordingURL else {
            print("No recording URL")
            return
        }
        
        
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.pause()

            if FileManager.default.fileExists(atPath: url.path) {
                transcribe(url)
            } else {
                print("Recorded file not found at path: \(url.path)")
            }
        } else {
            // This handles longer recordings (segment already rotated)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if FileManager.default.fileExists(atPath: url.path) {
                    self.transcribe(url)
                } else {
                    print("Recorded file not found at path: \(url.path)")
                }
            }
        }

       
  
    
        
       
    }

    
    // This is triggered by the rotation timer or after a previous segment is finalized.
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

        // Install a tap on the input node to receive audio buffers in real time
        // Buffer size of 1024 provides low latency without overwhelming CPU
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            try? self.audioFile?.write(from: buffer)

            let rms = self.computeVolumeLevel(from: buffer)
            DispatchQueue.main.async {
                self.volumeLevel = rms
            }
        }

        print("Started segment: \(fileURL.lastPathComponent)")
    }

    // Computes RMS (Root Mean Square) volume level from an audio buffer.
    private func computeVolumeLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }

        let frameLength = Int(buffer.frameLength)
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

        let rms = sqrt(channelDataArray.reduce(0) { $0 + $1 * $1 } / Float(frameLength))
        return rms
    }

    // Generates a unique file URL in the temporary directory for storing a new audio segment.
    private func getUniqueRecordingURL(withExtension ext: String = "wav") -> URL {
        let fileName = "recording_\(Int(Date().timeIntervalSince1970)).\(ext)"
        return fileManager.temporaryDirectory.appendingPathComponent(fileName)
    }
    
    // This is called every 30 seconds using a repeating timer. Handles I/O and audio engine transition.
    private func rotateSegment() {
        engine.inputNode.removeTap(onBus: 0)
        engine.pause()

        guard let fileURL = recordingURL else { return }

        transcribe(fileURL)

        do {
            // Start a new recording segment file and re-attach the tap
            try startNewSegment()
            try engine.start()
        } catch {
            print("Failed to rotate segment: \(error.localizedDescription)")
        }
    }

    
    // Attempts to transcribe the given audio file using Whisper API.
    // If the network is unavailable, it queues the file for retry.
    // Uses async/await to perform transcription, with retry and fallback strategies.
    private func transcribe(_ fileURL: URL) {
        guard isNetworkAvailable else {
            print("Network unavailable, queued segment: \(fileURL.lastPathComponent)")
            failedSegments.append(fileURL)
            saveFailedSegmentsToDisk()
            return
        }

        // Launch an async task to avoid blocking the main thread
        Task {
            do {
                // remote Whisper API
                let transcriptText = try await whisperTranscriptionAPI(fileURL: fileURL)
                print("Transcription success: \(fileURL.lastPathComponent)")
                retryCounts[fileURL] = 0
                self.failedSegments.removeAll { $0 == fileURL }

                DispatchQueue.main.async {
                    if self.currentSession == nil {
                        self.currentSession = RecordingSession(startTime: Date())
                    }

                    self.saveSegmentToDatabase(fileURL: fileURL, transcriptText: transcriptText)
                    self.recordingURL = nil
                }
            } catch {
                print(" Transcription failed: \(fileURL.lastPathComponent)")
                // Increment retry count with exponential backoff
                let currentRetry = retryCounts[fileURL, default: 0] + 1
                retryCounts[fileURL] = currentRetry

                if currentRetry >= 5 {
                    // After 5 failures, fall back to local iOS transcription engine
                    print(" Fallback to local transcription for: \(fileURL.lastPathComponent)")
                    fallbackToLocalTranscription(fileURL)
                } else {
                    // Schedule a retry with exponential delay (2, 4, 8... seconds)
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
    
    private func setupOfflineDicataion() {
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized:
                print("Authorized to use offline speech recognition.")
            case .denied:
                print("Denied to use offline speech recognition.")
            case .notDetermined:
                print("Not determined to use offline speech recognition.")
            case .restricted:
                print("Restricted to use offline speech recognition.")
            }
        }
    }

    
    
    private func fallbackToLocalTranscription(_ fileURL: URL) {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true

        recognizer?.recognitionTask(with: request) { result, error in
            if let error = error {
                let nsError = error as NSError
                print("Local transcription failed: \(nsError.localizedDescription)")
                self.saveSegmentToDatabase(fileURL: fileURL, transcriptText: "[Local STT failed]")

                // REMOVE after local fallback failure
                self.failedSegments.removeAll { $0 == fileURL }
                self.saveFailedSegmentsToDisk()

            } else if let result = result, result.isFinal {
                print("Local transcription: \(result.bestTranscription.formattedString)")
                self.saveSegmentToDatabase(fileURL: fileURL, transcriptText: result.bestTranscription.formattedString)

                // REMOVE after local STT success
                self.failedSegments.removeAll { $0 == fileURL }
                self.saveFailedSegmentsToDisk()
            }
        }
    }

    
    // Sends an audio file to OpenAI's Whisper transcription API and returns the transcript
    private func whisperTranscriptionAPI(fileURL: URL) async throws -> String {
        // Load the API key from the environment or fallback plist
        guard let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? loadAPIKey(), !openAIKey.isEmpty else {
            throw NSError(domain: "OpenAIKeyError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing API Key"])
        }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        
        // a unique boundary string for multipart form-data
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

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
           let text = json["text"] as? String {
            print("Final transcript: \(text)")
            return text
        } else {
            throw URLError(.cannotParseResponse)
        }
    }


    
    private func saveSegmentToDatabase(fileURL: URL, transcriptText: String? = nil) {
        guard let modelContext = modelContext else { return }

        // Ensure session exists
        if currentSession == nil {
            currentSession = RecordingSession(startTime: Date())
            modelContext.insert(currentSession!)
        }

        // Avoid duplicates
        let existing = try? modelContext.fetch(FetchDescriptor<Segment>(
            predicate: #Predicate { $0.filePath == fileURL.path }
        ))
        if let existing = existing, !existing.isEmpty {
            print("Segment already exists for: \(fileURL.lastPathComponent)")
            return
        }

        // Create and relate segment
        let segment = Segment(filePath: fileURL.path, timestamp: Date())
        segment.session = currentSession // links inverse relationship
        segment.status = .success

        if let text = transcriptText {
            let transcript = Transcript(text: text)
            segment.transcript = transcript
            modelContext.insert(transcript)
        }

        modelContext.insert(segment)

        try? modelContext.save()
        print("Saved segment and session: \(segment.filePath)")
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

    private let transcriptionQueue = DispatchQueue(label: "transcription.queue", attributes: .concurrent)

    private func retryQueuedSegments() {
        let uniqueSegments = Set(failedSegments)
        failedSegments.removeAll()

        for fileURL in uniqueSegments {
            transcriptionQueue.async {
                Task {
                    await self.transcribe(fileURL)
                }
            }
        }
    }

    func pauseRecording() {
        engine.pause()
        isPaused = true
        print("Recording paused")
    }

    func resumeRecording() {
        do {
            try engine.start()
            isPaused = false
            print("Recording resumed")
        } catch {
            print("Failed to resume recording: \(error.localizedDescription)")
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    private func saveFailedSegmentsToDisk() {
        let paths = failedSegments.map { $0.path }
        UserDefaults.standard.set(paths, forKey: "FailedSegmentPaths")
    }


    
    private func restoreFailedSegmentsFromDisk() {
        if let paths = UserDefaults.standard.stringArray(forKey: "FailedSegmentPaths") {
            failedSegments = paths.compactMap { path in
                let url = URL(fileURLWithPath: path)
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
            print("Restored \(failedSegments.count) valid failed segments from disk")
        }
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

func loadAPIKey() -> String? {
    guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
          let data = try? Data(contentsOf: url),
          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
        return nil
    }
    return plist["OpenAIKey"] as? String
}
