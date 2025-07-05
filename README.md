# 🎙️ AudioTranscriber – iOS App with Whisper Transcription

**AudioTranscriber** is a robust iOS app that records audio in segments, transcribes each using OpenAI Whisper API, and stores the full session using SwiftData. It supports background recording, Bluetooth input, offline queuing, retry logic, and real-time volume monitoring.

---

## 📱 Features

- 🎤 Record audio in 30-second segments using `AVAudioEngine`
- 🧠 Transcribe using OpenAI Whisper API (with exponential backoff retries)
- 📶 Offline support with queued uploads and retry on reconnection
- 🔊 Real-time volume meter visualization
- 🗃️ Data persistence using SwiftData (`RecordingSession`, `Segment`, `Transcript`)
- 🧭 VoiceOver accessibility for visually impaired users
- 🔁 Pause/Resume recording, audio quality selector, and secure HTTPS requests
- 📦 Local fallback using Apple’s `SFSpeechRecognizer` if Whisper fails
- 🧪 Fully tested UI with pagination, pull-to-refresh, and interruption handling

---

## 🧱 Data Model

```swift
@Model
class RecordingSession {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var segments: [Segment]
}

@Model
class Segment {
    @Attribute(.unique) var id: UUID
    var filePath: String
    var timestamp: Date
    var transcript: Transcript?
    var session: RecordingSession
}

@Model
class Transcript {
    @Attribute(.unique) var id: UUID
    var text: String
    var segment: Segment
}
