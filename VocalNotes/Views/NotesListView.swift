//
//  NotesListView.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import SwiftUI

struct NotesListView: View {
    @ObservedObject var notesViewModel: NotesViewModel
    @State private var showingFilters = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $notesViewModel.searchQuery)
                    .padding()
                    .onChange(of: notesViewModel.searchQuery) { _, _ in
                        Task {
                            try? await notesViewModel.loadNotes()
                        }
                    }
                
                // Active filters
                if notesViewModel.selectedTopic != nil || notesViewModel.selectedDate != nil {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if let topic = notesViewModel.selectedTopic {
                                FilterChip(
                                    text: topic.name,
                                    color: topic.color,
                                    onRemove: {
                                        notesViewModel.filterByTopic(nil)
                                    }
                                )
                            }
                            
                            if let date = notesViewModel.selectedDate {
                                FilterChip(
                                    text: formatDate(date),
                                    color: .accentColor,
                                    onRemove: {
                                        notesViewModel.filterByDate(nil)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                }
                
                // Notes list
                Group {
                    if notesViewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if notesViewModel.notes.isEmpty {
                        EmptyNotesView()
                    } else {
                        List {
                            ForEach(notesViewModel.notes) { note in
                                NavigationLink(destination: NoteDetailView(note: note, notesViewModel: notesViewModel)) {
                                    NoteRowView(note: note, topics: notesViewModel.getTopics(for: note))
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteNote(note)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("All Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilters.toggle() }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FiltersSheet(notesViewModel: notesViewModel)
            }
            .refreshable {
                await notesViewModel.refreshNotes()
            }
        }
    }
    
    private func deleteNote(_ note: Note) {
        Task {
            await notesViewModel.deleteNote(note)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct NoteRowView: View {
    let note: Note
    let topics: [Topic]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // First line of text
            Text(note.firstLine)
                .font(.headline)
                .lineLimit(2)
            
            // Metadata
            HStack(spacing: 12) {
                // Date
                Label(
                    formatDate(note.createdAt),
                    systemImage: "calendar"
                )
                .font(.caption)
                .foregroundColor(.secondary)
                
                // Duration if available
                if let duration = note.audioDuration {
                    Label(
                        formatDuration(duration),
                        systemImage: "timer"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            // Topics
            if !topics.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(topics) { topic in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(topic.color)
                                .frame(width: 8, height: 8)
                            Text(topic.name)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(topic.color.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct EmptyNotesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("No notes yet")
                .font(.title2.bold())
            
            Text("Tap the Capture tab to record your first note")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search notes...", text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct FilterChip: View {
    let text: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(text)
                .font(.subheadline)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.2))
        .cornerRadius(16)
    }
}

struct FiltersSheet: View {
    @ObservedObject var notesViewModel: NotesViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Topics") {
                    Button(action: {
                        notesViewModel.filterByTopic(nil)
                        dismiss()
                    }) {
                        HStack {
                            Text("All Topics")
                            Spacer()
                            if notesViewModel.selectedTopic == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    
                    ForEach(notesViewModel.topics) { topic in
                        Button(action: {
                            notesViewModel.filterByTopic(topic)
                            dismiss()
                        }) {
                            HStack {
                                Circle()
                                    .fill(topic.color)
                                    .frame(width: 12, height: 12)
                                Text(topic.name)
                                Spacer()
                                if notesViewModel.selectedTopic?.id == topic.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NotesListView(notesViewModel: NotesViewModel())
}

