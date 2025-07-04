//
//  RecordingModels.swift
//  AudioTranscriber
//
//  Created by Skanda Gonur Nagaraj on 7/3/25.
//

import Foundation
import SwiftData

@Model
class RecordingSession {
    var id: UUID
    var startTime: Date
    var segments: [Segment]

    init(startTime: Date) {
        self.id = UUID()
        self.startTime = startTime
        self.segments = []
    }
}

@Model
class Segment {
    var id: UUID
    var filePath: String
    var timestamp: Date
    var transcript: Transcript?
    var status: TranscriptionStatus

    init(filePath: String, timestamp: Date) {
        self.id = UUID()
        self.filePath = filePath
        self.timestamp = timestamp
        self.status = .pending
    }
}

@Model
class Transcript {
    var id: UUID
    var text: String
    var createdAt: Date

    init(text: String) {
        self.id = UUID()
        self.text = text
        self.createdAt = Date()
    }
}

enum TranscriptionStatus: String, Codable {
    case pending
    case success
    case failed
    case fallback
}
