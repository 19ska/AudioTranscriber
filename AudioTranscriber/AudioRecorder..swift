//
//  AudioRecorder..swift
//  AudioTranscriber
//
//  Created by Skanda Gonur Nagaraj on 7/3/25.
//

import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject {
    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private let fileManager = FileManager.default

    @Published var isRecording = false

    override init() {
        super.init()
        setupNotifications()
    }

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try session.setActive(true)

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)

            let dir = fileManager.temporaryDirectory
            let fileURL = dir.appendingPathComponent("recording_\(Date().timeIntervalSince1970).caf")
            audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)

            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                do {
                    try self.audioFile?.write(from: buffer)
                } catch {
                    print("Failed to write audio buffer: \(error)")
                }
            }

            engine.prepare()
            try engine.start()
            isRecording = true
            print("Recording started at \(fileURL)")
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    func stopRecording() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        print("Recording stopped.")
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
        } else if type == .ended {
            startRecording() // optional: auto-resume
        }
    }
}
