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
    @State private var audioPlayerDelegate = AudioPlayerDelegate()
    @State private var showingAppleIntelligence = false
    @State private var selectedAIAction: WritingToolsAction = .rewrite
    @State private var aiText: String = ""
    @State private var isGeneratingAI = false
    
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
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(summary)
                                        .font(.body)
                                    
                                    Button(action: { generateSummary() }) {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Regenerate Summary")
                                        }
                                        .font(.subheadline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                    }
                                    .disabled(isGeneratingAI)
                                }
                            } else {
                                VStack(spacing: 16) {
                                    Text("No summary available")
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: { generateSummary() }) {
                                        HStack {
                                            if isGeneratingAI {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle())
                                                    .scaleEffect(0.8)
                                            } else {
                                                Image(systemName: "text.quote")
                                            }
                                            Text(isGeneratingAI ? "Generating..." : "Generate Summary")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(10)
                                    }
                                    .disabled(isGeneratingAI)
                                }
                            }
                            
                        case .cleaned:
                            if isEditing {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Editing cleaned text")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        if isEnhancing || isGeneratingAI {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                    
                                    WritingToolsTextEditor(
                                        text: $editedText,
                                        isEnabled: true,
                                        onShowWritingTools: { action in
                                            print("✨ Writing Tools shown for: \(action)")
                                        }
                                    )
                                    .frame(minHeight: 200)
                                }
                            } else {
                                if let cleaned = note.cleanedText {
                                    Text(cleaned)
                                        .font(.body)
                                } else {
                                    VStack(spacing: 16) {
                                        Text("No enhanced version available")
                                            .foregroundColor(.secondary)
                                        
                                        Button(action: { generateCleanedText() }) {
                                            HStack {
                                                if isGeneratingAI {
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle())
                                                        .scaleEffect(0.8)
                                                } else {
                                                    Image(systemName: "wand.and.stars")
                                                }
                                                Text(isGeneratingAI ? "Generating..." : "Generate with AI")
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.purple.opacity(0.1))
                                            .foregroundColor(.purple)
                                            .cornerRadius(10)
                                        }
                                        .disabled(isGeneratingAI)
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
                    HStack(spacing: 8) {
                        if isEditing {
                            Menu {
                                Button {
                                    showAppleIntelligence(action: .rewrite)
                                } label: {
                                    Label("Rewrite", systemImage: "arrow.triangle.2.circlepath")
                                }
                                
                                Button {
                                    showAppleIntelligence(action: .makeConcise)
                                } label: {
                                    Label("Make Concise", systemImage: "text.alignleft")
                                }
                                
                                Button {
                                    showAppleIntelligence(action: .summarize)
                                } label: {
                                    Label("Summarize", systemImage: "text.quote")
                                }
                                
                                Divider()
                                
                                Button {
                                    showAppleIntelligence(action: .polish)
                                } label: {
                                    Label("Polish", systemImage: "wand.and.stars")
                                }
                                
                                Button {
                                    showAppleIntelligence(action: .proofread)
                                } label: {
                                    Label("Proofread", systemImage: "checkmark.circle")
                                }
                                
                                Divider()
                                
                                Button {
                                    polishTextWithAI()
                                } label: {
                                    Label("Quick Clean (Offline)", systemImage: "sparkles")
                                }
                            } label: {
                                Image(systemName: "wand.and.stars.inverse")
                                    .foregroundColor(.purple)
                            }
                            .disabled(isEnhancing)
                        }
                        
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
        }
        .sheet(isPresented: $showingTopicPicker) {
            TopicPickerSheet(
                notesViewModel: notesViewModel,
                selectedTopics: $selectedTopics,
                onSave: saveTopics
            )
        }
        .sheet(isPresented: $showingAppleIntelligence) {
            AppleIntelligenceSheet(text: $aiText, action: selectedAIAction)
                .onDisappear {
                    if aiText != editedText && !aiText.isEmpty {
                        editedText = aiText
                    }
                }
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
    
    private func polishTextWithAI() {
        isEnhancing = true
        Task {
            do {
                let polished = try await AppleIntelligenceService.shared.polishText(editedText)
                editedText = polished
            } catch {
                print("Failed to polish text: \(error)")
            }
            isEnhancing = false
        }
    }
    
    private func showAppleIntelligence(action: WritingToolsAction) {
        selectedAIAction = action
        aiText = editedText
        showingAppleIntelligence = true
        
        print("✨ Opening Apple Intelligence for: \(action)")
    }
    
    private func generateCleanedText() {
        isGeneratingAI = true
        Task {
            do {
                var updatedNote = note
                print("🤖 Generating cleaned text with AI...")
                updatedNote.cleanedText = try await IntelligenceService.shared.cleanText(note.rawText)
                await notesViewModel.updateNote(updatedNote)
                print("✅ Cleaned text generated!")
            } catch {
                print("❌ Failed to generate cleaned text: \(error)")
            }
            isGeneratingAI = false
        }
    }
    
    private func generateSummary() {
        isGeneratingAI = true
        Task {
            do {
                var updatedNote = note
                print("🤖 Generating summary with AI...")
                updatedNote.summaryText = try await IntelligenceService.shared.summarize(note.rawText)
                await notesViewModel.updateNote(updatedNote)
                print("✅ Summary generated!")
            } catch {
                print("❌ Failed to generate summary: \(error)")
            }
            isGeneratingAI = false
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
        guard let audioURL = note.audioFileURL else { 
            print("❌ No audio URL available for this note")
            return 
        }
        
        if isPlaying {
            print("⏸️ Stopping audio playback")
            audioPlayer?.stop()
            isPlaying = false
            
            // Reset audio session
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                print("⚠️ Failed to deactivate audio session: \(error)")
            }
        } else {
            do {
                print("🎵 Attempting to play audio from: \(audioURL.path)")
                
                // Check if file exists
                guard FileManager.default.fileExists(atPath: audioURL.path) else {
                    print("❌ Audio file does not exist at path: \(audioURL.path)")
                    print("📂 Checking parent directory...")
                    let parentDir = audioURL.deletingLastPathComponent()
                    if let files = try? FileManager.default.contentsOfDirectory(at: parentDir, includingPropertiesForKeys: nil) {
                        print("📁 Files in directory:")
                        files.forEach { print("  - \($0.lastPathComponent)") }
                    }
                    return
                }
                
                // Get file size
                if let attrs = try? FileManager.default.attributesOfItem(atPath: audioURL.path),
                   let fileSize = attrs[.size] as? UInt64 {
                    print("📄 Audio file size: \(fileSize) bytes")
                }
                
                // Configure audio session for playback
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default, options: [])
                try audioSession.setActive(true, options: [])
                print("✅ Audio session configured for playback")
                
                // Create and configure player
                audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
                audioPlayer?.delegate = audioPlayerDelegate
                
                // Set up completion handler
                audioPlayerDelegate.onFinish = { [self] in
                    Task { @MainActor in
                        self.isPlaying = false
                        print("✅ Audio playback finished")
                    }
                }
                
                audioPlayer?.prepareToPlay()
                print("⏳ Audio player prepared, duration: \(audioPlayer?.duration ?? 0)s")
                
                let success = audioPlayer?.play() ?? false
                
                if success {
                    isPlaying = true
                    print("▶️ Audio playback started successfully")
                } else {
                    print("❌ Failed to start audio playback (play() returned false)")
                }
            } catch let error as NSError {
                print("❌ Failed to play audio: \(error.localizedDescription)")
                print("   Domain: \(error.domain), Code: \(error.code)")
                print("   Audio URL: \(audioURL)")
                if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                    print("   Underlying: \(underlyingError.localizedDescription)")
                }
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

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
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

