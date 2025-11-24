//
//  NoteDetailView.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import SwiftUI
import AVFoundation

struct NoteDetailView: View {
    let note: Note
    @ObservedObject var notesViewModel: NotesViewModel
    
    @State private var selectedTab: NoteTab = .cleaned
    @State private var isEditing = false
    @State private var editedText = ""
    @State private var selectedTopics: Set<UUID> = []
    @State private var isEnhancing = false
    @State private var showingTopicPicker = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    
    enum NoteTab: String, CaseIterable {
        case summary = "Summary"
        case cleaned = "Cleaned"
        case raw = "Raw"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date and metadata
                VStack(spacing: 8) {
                    Text(formatDate(note.createdAt))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let duration = note.audioDuration {
                        Label(formatDuration(duration), systemImage: "timer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top)
                
                // Audio player
                if note.audioFileURL != nil {
                    Button(action: toggleAudioPlayback) {
                        HStack {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title)
                            Text(isPlaying ? "Pause Recording" : "Play Recording")
                                .font(.headline)
                        }
                        .foregroundColor(.accentColor)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // Tabs
                Picker("View", selection: $selectedTab) {
                    ForEach(NoteTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Content
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        switch selectedTab {
                        case .summary:
                            if let summary = note.summaryText {
                                Text(summary)
                                    .font(.body)
                            } else {
                                VStack(spacing: 12) {
                                    Text("No summary available")
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: enhanceNote) {
                                        Label("Generate Summary", systemImage: "sparkles")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isEnhancing)
                                }
                            }
                            
                        case .cleaned:
                            if isEditing {
                                TextEditor(text: $editedText)
                                    .frame(minHeight: 200)
                                    .padding(8)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                            } else {
                                if let cleaned = note.cleanedText {
                                    Text(cleaned)
                                        .font(.body)
                                } else {
                                    VStack(spacing: 12) {
                                        Text("No cleaned version available")
                                            .foregroundColor(.secondary)
                                        
                                        Button(action: enhanceNote) {
                                            Label("Clean Text", systemImage: "sparkles")
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(isEnhancing)
                                    }
                                }
                            }
                            
                        case .raw:
                            Text(note.rawText)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Topics section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Topics")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: { showingTopicPicker.toggle() }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    let noteTopics = notesViewModel.getTopics(for: note)
                    if noteTopics.isEmpty {
                        Text("No topics assigned")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(noteTopics) { topic in
                                TopicChip(topic: topic, isSelected: true) {
                                    removeTopicFromNote(topic)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Note Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedTab == .cleaned {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            saveEdits()
                        } else {
                            startEditing()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingTopicPicker) {
            TopicPickerSheet(
                notesViewModel: notesViewModel,
                selectedTopics: $selectedTopics,
                onSave: saveTopics
            )
        }
        .onAppear {
            selectedTopics = Set(note.topics)
            editedText = note.cleanedText ?? note.rawText
        }
        .onDisappear {
            audioPlayer?.stop()
        }
    }
    
    private func startEditing() {
        editedText = note.cleanedText ?? note.rawText
        isEditing = true
    }
    
    private func saveEdits() {
        var updatedNote = note
        updatedNote.cleanedText = editedText
        Task {
            await notesViewModel.updateNote(updatedNote)
        }
        isEditing = false
    }
    
    private func enhanceNote() {
        isEnhancing = true
        Task {
            await notesViewModel.enhanceNote(note)
            isEnhancing = false
        }
    }
    
    private func saveTopics() {
        var updatedNote = note
        updatedNote.topics = Array(selectedTopics)
        Task {
            await notesViewModel.updateNote(updatedNote)
        }
    }
    
    private func removeTopicFromNote(_ topic: Topic) {
        selectedTopics.remove(topic.id)
        saveTopics()
    }
    
    private func toggleAudioPlayback() {
        guard let audioURL = note.audioFileURL else { return }
        
        if isPlaying {
            audioPlayer?.stop()
            isPlaying = false
        } else {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
                audioPlayer?.play()
                isPlaying = true
            } catch {
                print("Failed to play audio: \(error)")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TopicPickerSheet: View {
    @ObservedObject var notesViewModel: NotesViewModel
    @Binding var selectedTopics: Set<UUID>
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(notesViewModel.topics) { topic in
                    Button(action: {
                        if selectedTopics.contains(topic.id) {
                            selectedTopics.remove(topic.id)
                        } else {
                            selectedTopics.insert(topic.id)
                        }
                    }) {
                        HStack {
                            Circle()
                                .fill(topic.color)
                                .frame(width: 12, height: 12)
                            
                            Text(topic.name)
                            
                            Spacer()
                            
                            if selectedTopics.contains(topic.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Topics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        NoteDetailView(
            note: Note(rawText: "This is a sample note for preview purposes"),
            notesViewModel: NotesViewModel()
        )
    }
}

