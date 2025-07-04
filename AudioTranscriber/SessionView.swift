import SwiftUI
import SwiftData

struct SessionListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var audioRecorder: AudioRecorder

    @Query(sort: \RecordingSession.startTime, order: .reverse)
    private var allSessions: [RecordingSession]

    @State private var searchText: String = ""
    @State private var visibleCount = 10
    @FocusState private var isSearchFieldFocused: Bool

    private var filteredSessions: [RecordingSession] {
        let filtered = searchText.isEmpty ? allSessions : allSessions.filter { session in
            formatted(session.startTime).localizedCaseInsensitiveContains(searchText) ||
            session.segments.contains { $0.transcript?.text.localizedCaseInsensitiveContains(searchText) ?? false }
        }
        return Array(filtered.prefix(visibleCount))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                if !audioRecorder.isNetworkAvailable {
                    Text("You are offline")
                        .foregroundColor(.white)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                VStack(spacing: 10) {
                    // Search bar
                    HStack {
                        TextField("Search transcripts...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                            .focused($isSearchFieldFocused)

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                isSearchFieldFocused = true
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .padding(.trailing)
                        }
                    }

                    List {
                        ForEach(filteredSessions) { session in
                            NavigationLink(destination: SessionDetailView(session: session)) {
                                VStack(alignment: .leading) {
                                    Text("Session: \(formatted(session.startTime))")
                                        .font(.headline)
                                    Text("Segments: \(session.segments.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .onAppear {
                                    if session == filteredSessions.last {
                                        loadMoreIfNeeded()
                                    }
                                }
                            }
                        }

                        if visibleCount < allSessions.count && searchText.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    }
                    .refreshable {
                        // Pull-to-refresh logic
                        visibleCount = 10
                    }
                }
            }
            .navigationTitle("Past Transcripts")
            .animation(.easeInOut, value: audioRecorder.isNetworkAvailable)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isSearchFieldFocused = true
                }
            }
        }
    }

    private func loadMoreIfNeeded() {
        guard visibleCount < allSessions.count else { return }
        visibleCount += 10
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
