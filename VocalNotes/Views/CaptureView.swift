//
//  CaptureView.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import SwiftUI

struct CaptureView: View {
    @ObservedObject var notesViewModel: NotesViewModel
    @StateObject private var speechService = SpeechService()
    
    @State private var showingPermissionAlert = false
    @State private var showingNotePreview = false
    @State private var recordingResult: RecordingResult?
    @State private var isProcessing = false
    @State private var pulseAnimation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.accentColor.opacity(0.1),
                        Color.accentColor.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Title
                    VStack(spacing: 8) {
                        Text(speechService.isRecording ? "Listening..." : "Ready to Capture")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(speechService.isRecording ? "Speak your thoughts" : "Tap to start recording")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)
                    
                    // Transcribed text display
                    if speechService.isRecording && !speechService.transcribedText.isEmpty {
                        ScrollView {
                            Text(speechService.transcribedText)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.05), radius: 10)
                        }
                        .frame(maxHeight: 200)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .scale))
                    }
                    
                    Spacer()
                    
                    // Microphone button
                    Button(action: handleMicTap) {
                        ZStack {
                            // Pulse animation
                            if speechService.isRecording {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.3))
                                    .frame(width: 160, height: 160)
                                    .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                                    .opacity(pulseAnimation ? 0 : 1)
                            }
                            
                            // Main button
                            Circle()
                                .fill(
                                    speechService.isRecording ?
                                    Color.red.gradient :
                                    Color.accentColor.gradient
                                )
                                .frame(width: 120, height: 120)
                                .shadow(
                                    color: speechService.isRecording ?
                                    Color.red.opacity(0.4) :
                                    Color.accentColor.opacity(0.4),
                                    radius: 20
                                )
                            
                            Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isProcessing)
                    
                    // Recording indicator
                    if speechService.isRecording {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("Recording")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .transition(.opacity)
                    }
                    
                    Spacer()
                }
                .animation(.easeInOut, value: speechService.isRecording)
                
                // Processing overlay
                if isProcessing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Saving note...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding(30)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                }
            }
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                checkPermissions()
            }
            .onChange(of: speechService.isRecording) { oldValue, newValue in
                if newValue {
                    startPulseAnimation()
                }
            }
            .alert("Microphone Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings", action: openSettings)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable microphone and speech recognition permissions in Settings to use voice capture.")
            }
            .sheet(isPresented: $showingNotePreview) {
                if let result = recordingResult {
                    NotePreviewSheet(
                        result: result,
                        notesViewModel: notesViewModel,
                        onSave: {
                            showingNotePreview = false
                            recordingResult = nil
                        }
                    )
                }
            }
        }
    }
    
    private func handleMicTap() {
        if speechService.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        do {
            try speechService.startRecording()
        } catch {
            showingPermissionAlert = true
        }
    }
    
    private func stopRecording() {
        if let result = speechService.stopRecording() {
            recordingResult = result
            if !result.transcribedText.isEmpty {
                showingNotePreview = true
            }
        }
    }
    
    private func checkPermissions() {
        Task {
            let speechAuthorized = await speechService.requestAuthorization()
            let micAuthorized = await speechService.requestMicrophonePermission()
            
            if !speechAuthorized || !micAuthorized {
                showingPermissionAlert = true
            }
        }
    }
    
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
            pulseAnimation = true
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct NotePreviewSheet: View {
    let result: RecordingResult
    @ObservedObject var notesViewModel: NotesViewModel
    let onSave: () -> Void
    
    @State private var selectedTopics: Set<UUID> = []
    @State private var isEnhancing = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Transcribed text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcribed Text")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(result.transcribedText)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                    
                    // Duration
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(.secondary)
                        Text("Duration: \(formatDuration(result.duration))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Topic selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add to Topics")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(notesViewModel.topics) { topic in
                                TopicChip(
                                    topic: topic,
                                    isSelected: selectedTopics.contains(topic.id)
                                ) {
                                    toggleTopic(topic.id)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNote()
                    }
                    .disabled(isEnhancing)
                }
            }
        }
    }
    
    private func toggleTopic(_ topicId: UUID) {
        if selectedTopics.contains(topicId) {
            selectedTopics.remove(topicId)
        } else {
            selectedTopics.insert(topicId)
        }
    }
    
    private func saveNote() {
        Task {
            isEnhancing = true
            var note = Note(
                rawText: result.transcribedText,
                topics: Array(selectedTopics),
                audioFileURL: result.audioFileURL,
                audioDuration: result.duration
            )
            
            // Enhance the note
            await notesViewModel.createNote(
                rawText: result.transcribedText,
                audioURL: result.audioFileURL,
                duration: result.duration
            )
            
            isEnhancing = false
            dismiss()
            onSave()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    CaptureView(notesViewModel: NotesViewModel())
}

