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
    @StateObject private var whisperService = WhisperService.shared
    @AppStorage("transcriptionEngine") private var transcriptionEngine = "apple"
    
    @State private var showingPermissionAlert = false
    @State private var showingNotePreview = false
    @State private var recordingResult: RecordingResult?
    @State private var isProcessing = false
    @State private var pulseAnimation = false
    
    // Computed properties for unified access
    private var isRecording: Bool {
        transcriptionEngine == "whisper" ? whisperService.isRecording : speechService.isRecording
    }
    
    private var transcribedText: String {
        transcriptionEngine == "whisper" ? whisperService.transcribedText : speechService.transcribedText
    }
    
    private var engineName: String {
        transcriptionEngine == "whisper" ? "OpenAI Whisper" : "Apple Speech"
    }
    
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
                        Text(isRecording ? "Listening..." : "Ready to Capture")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(isRecording ? "Speak your thoughts" : "Tap to start recording")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Engine indicator
                        if !isRecording {
                            HStack(spacing: 4) {
                                Image(systemName: transcriptionEngine == "whisper" ? "brain" : "waveform")
                                    .font(.caption2)
                                Text(engineName)
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.bottom, 20)
                    
                    // Transcribed text display (real-time)
                    if isRecording && !transcribedText.isEmpty {
                        VStack(spacing: 0) {
                            // Live indicator
                            HStack {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                    Text("Live Transcription")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground).opacity(0.8))
                            
                            ScrollViewReader { proxy in
                                ScrollView {
                                    VStack {
                                        Text(transcribedText)
                                            .font(.body)
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .id("transcription")
                                    }
                                }
                                .frame(maxHeight: 180)
                                .onChange(of: transcribedText) { _, _ in
                                    withAnimation {
                                        proxy.scrollTo("transcription", anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 10)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .scale))
                    }
                    
                    Spacer()
                    
                    // Microphone button
                    Button(action: handleMicTap) {
                        ZStack {
                            // Pulse animation
                            if isRecording {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.3))
                                    .frame(width: 160, height: 160)
                                    .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                                    .opacity(pulseAnimation ? 0 : 1)
                            }
                            
                            // Main button
                            Circle()
                                .fill(
                                    isRecording ?
                                    Color.red.gradient :
                                    Color.accentColor.gradient
                                )
                                .frame(width: 120, height: 120)
                                .shadow(
                                    color: isRecording ?
                                    Color.red.opacity(0.4) :
                                    Color.accentColor.opacity(0.4),
                                    radius: 20
                                )
                            
                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isProcessing)
                    
                    // Recording indicator
                    if isRecording {
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
            .onChange(of: isRecording) { oldValue, newValue in
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
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        Task {
            do {
                if transcriptionEngine == "whisper" {
                    _ = try await whisperService.startRecording()
                } else {
                    try speechService.startRecording()
                }
            } catch {
                showingPermissionAlert = true
            }
        }
    }
    
    private func stopRecording() {
        Task {
            do {
                let result: RecordingResult
                if transcriptionEngine == "whisper" {
                    let whisperResult = try await whisperService.stopRecording()
                    // Convert tuple to RecordingResult
                    result = RecordingResult(
                        transcribedText: whisperResult.transcribedText,
                        audioFileURL: whisperResult.audioFileURL ?? URL(fileURLWithPath: ""),
                        duration: whisperResult.duration ?? 0
                    )
                } else {
                    guard let speechResult = speechService.stopRecording() else { return }
                    result = speechResult
                }
                
                await MainActor.run {
                    recordingResult = result
                    if !result.transcribedText.isEmpty {
                        showingNotePreview = true
                    }
                }
            } catch {
                print("Error stopping recording: \(error)")
            }
        }
    }
    
    private func checkPermissions() {
        Task {
            let speechAuthorized: Bool
            let micAuthorized: Bool
            
            if transcriptionEngine == "whisper" {
                speechAuthorized = await whisperService.requestAuthorization()
                micAuthorized = await whisperService.requestMicrophonePermission()
                
                // Check if model is downloaded
                if !whisperService.isModelAvailable {
                    print("⚠️ Whisper model not downloaded. Please download it in Settings.")
                }
            } else {
                speechAuthorized = await speechService.requestAuthorization()
                micAuthorized = await speechService.requestMicrophonePermission()
            }
            
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
    @State private var isSummarizing = false
    @State private var cleanedText: String?
    @State private var summaryText: String?
    @State private var showingAppleIntelligence = false
    @State private var selectedAIAction: WritingToolsAction = .rewrite
    @State private var aiText: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Transcribed text
                    VStack(alignment: .leading, spacing: 16) {
                        // Original Text Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Original")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if isEnhancing || isSummarizing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                            
                            Text(result.transcribedText)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                        }
                        
                        // Enhanced Text Section (if available)
                        if let enhanced = cleanedText {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.purple)
                                        .font(.caption)
                                    Text("Enhanced")
                                        .font(.headline)
                                        .foregroundColor(.purple)
                                    
                                    Spacer()
                                    
                                    Button(action: { cleanedText = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Text(enhanced)
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                        
                        // Summary Section (if available)
                        if let summary = summaryText {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "text.quote")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("Summary")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                    
                                    Spacer()
                                    
                                    Button(action: { summaryText = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Text(summary)
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                        
                        // AI Action Buttons
                        HStack(spacing: 12) {
                            // Rewrite Button
                            Button(action: {
                                rewriteWithAI()
                            }) {
                                HStack(spacing: 8) {
                                    if isEnhancing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(cleanedText == nil ? "Rewrite" : "Redo")
                                            .fontWeight(.semibold)
                                            .font(.subheadline)
                                        
                                        if isEnhancing && !LLMService.shared.processingProgress.isEmpty {
                                            Text(LLMService.shared.processingProgress)
                                                .font(.caption2)
                                                .opacity(0.9)
                                        } else {
                                            Text("Clean text")
                                                .font(.caption2)
                                                .opacity(0.9)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple.gradient)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isEnhancing || isSummarizing)
                            
                            // Summarize Button
                            Button(action: {
                                summarizeWithAI()
                            }) {
                                HStack(spacing: 8) {
                                    if isSummarizing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "text.quote")
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(summaryText == nil ? "Summarize" : "Redo")
                                            .fontWeight(.semibold)
                                            .font(.subheadline)
                                        
                                        if isSummarizing && !LLMService.shared.processingProgress.isEmpty {
                                            Text(LLMService.shared.processingProgress)
                                                .font(.caption2)
                                                .opacity(0.9)
                                        } else {
                                            Text("Key points")
                                                .font(.caption2)
                                                .opacity(0.9)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.gradient)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isEnhancing || isSummarizing)
                        }
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
            .sheet(isPresented: $showingAppleIntelligence) {
                AppleIntelligenceSheet(text: $aiText, action: selectedAIAction)
                    .onDisappear {
                        if !aiText.isEmpty && aiText != result.transcribedText {
                            cleanedText = aiText
                        }
                    }
            }
            .onAppear {
                enhanceTextPreview()
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
    
    private func enhanceTextPreview() {
        // Auto-enhance is now handled by button press only
        // This keeps the UI snappy on initial load
    }
    
    private func rewriteWithAI() {
        Task {
            isEnhancing = true
            do {
                let textToEnhance = cleanedText ?? result.transcribedText
                print("🤖 Starting AI rewrite...")
                
                cleanedText = try await IntelligenceService.shared.cleanText(textToEnhance)
                
                print("✅ Rewrite complete!")
            } catch {
                print("❌ Failed to rewrite text: \(error)")
            }
            isEnhancing = false
        }
    }
    
    private func summarizeWithAI() {
        Task {
            isSummarizing = true
            do {
                let textToSummarize = cleanedText ?? result.transcribedText
                print("🤖 Starting AI summarization...")
                
                summaryText = try await IntelligenceService.shared.summarize(textToSummarize)
                
                print("✅ Summarization complete!")
            } catch {
                print("❌ Failed to summarize text: \(error)")
            }
            isSummarizing = false
        }
    }
    
    private func saveNote() {
        Task {
            // Create the note with enhanced text and summary
            await notesViewModel.createNote(
                rawText: result.transcribedText,
                cleanedText: cleanedText,
                summaryText: summaryText,
                audioURL: result.audioFileURL,
                duration: result.duration
            )
            
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

