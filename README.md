# 🎙️ AudioTranscriber – iOS App with Whisper Transcription

An iOS app built using SwiftUI and AVFoundation to record audio in real time, segment it into
30-second chunks, and transcribe the segments using OpenAI Whisper API. The app supports background recording, audio monitoring, offline queuing, and a full SwiftData-based session management system.

---

## 🚀 Features

- Real time audio recording using `AVAudioEngine`
- Automatic 30-second segmentation
- Whisper API integration for transcription
- Retry logic with exponential backoff for failures
- Offline queuing and retry
- Background recording support
- Audio quality selection (low, medium, high)
- Real-time input volume visualization
- Data persistence using SwiftData (`RecordingSession`, `Segment`, `Transcript`)
- VoiceOver accessibility for visually impaired users
- Pause/Resume recording, audio quality selector, and secure HTTPS requests
- Local fallback using Apple’s `SFSpeechRecognizer` if Whisper fails
- Fully tested UI with pagination, pull-to-refresh, and interruption handling
- Cloud-safe secure API key handling

                                
---
                                
## 🧱 Architecture

- AudioRecorder.swift – Core audio engine logic
- ContentView.swift – Main UI for controls, volume meter, and navigation
- SessionListView.swift – Past recordings list with pagination
- SessionDetailView.swift – Shows transcript for each segment
- TranscriptionService.swift – Handles communication with OpenAI Whisper
- SwiftData Models (`RecordingSession`, `Segment`, `Transcript`)
---
                            
## 🛠️ Setup Instructions
                            
1. Clone the Repo
```bash
https://github.com/19ska/AudioTranscriber.git
```
                                
2. Open in Xcode
- Open 'AudioTranscriber.xcodeproj' or 'AudioTranscriber.xcworkspace' in Xcode 15+
                                
3. Add OpenAI API Key
- Create a file named 'Secrets.plist' in the root directory with:
```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>OpenAIKey</key>
<string>sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx</string>
</dict>
</plist>
```
 - Add 'Secrets.plist' to '.gitignore'
                                
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
