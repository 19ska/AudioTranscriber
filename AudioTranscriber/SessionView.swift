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
        }

        let lowercasedSearch = searchText.lowercased()

        return allSessions.filter { session in
            let date = session.startTime

            let dateMatch: Bool = {
                if let parsedDate = Date.from(searchText) {
                    return Calendar.current.isDate(date, equalTo: parsedDate, toGranularity: .day)
                }
                let formattedShort = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none).lowercased()
                return formatted(date).lowercased().contains(lowercasedSearch) || formattedShort.contains(lowercasedSearch)
            }()

            let textMatch = session.segments.contains {
                $0.transcript?.text.localizedCaseInsensitiveContains(lowercasedSearch) ?? false
            }

            return dateMatch || textMatch
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

extension Date {
    static func from(_ input: String) -> Date? {
        let formats = ["yyyy-MM-dd", "MM/dd/yyyy", "MMM d, yyyy", "MMM d"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX") 
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: input) {
                return date
            }
        }
        return nil
    }
}
