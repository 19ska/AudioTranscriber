import SwiftUI
import SwiftData

import SwiftUI
import SwiftData

struct SessionListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var audioRecorder: AudioRecorder

    @State private var allSessions: [RecordingSession] = []
    @State private var isLoading = false
    @State private var batchSize = 10
    @State private var currentOffset = 0

    @State private var searchText: String = ""
    @FocusState private var isSearchFieldFocused: Bool

    private var filteredSessions: [RecordingSession] {
        if searchText.isEmpty {
            return allSessions
        } else {
            return allSessions.filter { session in
                formatted(session.startTime).localizedCaseInsensitiveContains(searchText) ||
                session.segments.contains { $0.transcript?.text.localizedCaseInsensitiveContains(searchText) ?? false }
            }
        }
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
                                    if session == filteredSessions.last && searchText.isEmpty {
                                        loadMoreSessions()
                                    }
                                }
                            }
                        }

                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    }
                    .refreshable {
                        resetAndReload()
                    }
                }
            }
            .navigationTitle("Past Transcripts")
            .animation(.easeInOut, value: audioRecorder.isNetworkAvailable)
            .onAppear {
                if allSessions.isEmpty {
                    loadMoreSessions()
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isSearchFieldFocused = true
                }
            }
        }
    }

    private func loadMoreSessions() {
        guard !isLoading else { return }
        isLoading = true

        Task {
            var descriptor = FetchDescriptor<RecordingSession>(
                sortBy: [SortDescriptor(\.startTime, order: .reverse)]
            )
            descriptor.fetchOffset = currentOffset
            descriptor.fetchLimit = batchSize

            do {
                let result = try modelContext.fetch(descriptor)
                DispatchQueue.main.async {
                    allSessions.append(contentsOf: result)
                    currentOffset += batchSize
                    isLoading = false
                }
            } catch {
                print("Failed to fetch sessions: \(error)")
                isLoading = false
            }
        }
    }

    private func resetAndReload() {
        allSessions.removeAll()
        currentOffset = 0
        loadMoreSessions()
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
