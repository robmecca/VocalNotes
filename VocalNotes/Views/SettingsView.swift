//
//  SettingsView.swift
//  VocalNotes
//
//  Created by AI Assistant on 24/11/2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var llmService = LLMService.shared
    @ObservedObject var whisperService = WhisperService.shared
    @AppStorage("transcriptionEngine") private var transcriptionEngine = "apple" // "apple" or "whisper"
    @AppStorage("useAIEnhancement") private var useAIEnhancement = true
    @AppStorage("autoEnhanceNotes") private var autoEnhanceNotes = true
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteWhisperConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // Transcription Engine Section
                Section {
                    Picker("Engine", selection: $transcriptionEngine) {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Apple Speech")
                                Text("Built-in, no download").font(.caption).foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "waveform")
                        }
                        .tag("apple")
                        
                        Label {
                            VStack(alignment: .leading) {
                                Text("OpenAI Whisper")
                                Text("Superior accuracy & punctuation").font(.caption).foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "brain")
                        }
                        .tag("whisper")
                    }
                    .pickerStyle(.navigationLink)
                    
                    if transcriptionEngine == "whisper" {
                        if !whisperService.isModelAvailable {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("Whisper model required")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                } header: {
                    Label("Transcription", systemImage: "mic.fill")
                } footer: {
                    if transcriptionEngine == "apple" {
                        Text("Uses Apple's built-in speech recognition. Good accuracy with basic punctuation.")
                    } else {
                        if whisperService.isModelAvailable {
                            Text("OpenAI Whisper provides superior accuracy with proper punctuation, capitalization, and formatting. All processing happens on your device.")
                        } else {
                            Text("⚠️ Model not downloaded - currently using Apple Speech Recognition as fallback. Download the model below for best results with perfect punctuation.")
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // Whisper Model Management (if Whisper is selected)
                if transcriptionEngine == "whisper" {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            // Model selector
                            Picker("Model Quality", selection: $whisperService.selectedModel) {
                                ForEach(WhisperService.WhisperModel.allCases, id: \.self) { model in
                                    Text(model.displayName).tag(model)
                                }
                            }
                            .pickerStyle(.navigationLink)
                            
                            Divider()
                            
                            // Model info
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(whisperService.selectedModel.displayName)
                                        .font(.headline)
                                    Text("OpenAI Whisper - 100% offline")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if whisperService.isModelAvailable {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                }
                            }
                            
                            // Size info
                            HStack {
                                Image(systemName: "externaldrive")
                                    .foregroundColor(.secondary)
                                Text("Size: \(whisperService.selectedModel.size)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Status
                            HStack {
                                Image(systemName: whisperService.isModelAvailable ? "checkmark.circle" : "arrow.down.circle")
                                    .foregroundColor(whisperService.isModelAvailable ? .green : .orange)
                                Text(whisperService.isModelAvailable ? "Downloaded & Ready" : "Not downloaded")
                                    .font(.subheadline)
                                    .foregroundColor(whisperService.isModelAvailable ? .green : .orange)
                            }
                            
                            // Download/Delete button
                            if whisperService.isDownloadingModel {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Downloading Whisper Model...")
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(Int(whisperService.downloadProgress * 100))%")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    ProgressView(value: whisperService.downloadProgress)
                                        .progressViewStyle(.linear)
                                        .tint(.blue)
                                }
                            } else if whisperService.isModelAvailable {
                                Button(role: .destructive, action: {
                                    showingDeleteWhisperConfirmation = true
                                }) {
                                    Label("Delete Model", systemImage: "trash")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button(action: downloadWhisperModel) {
                                    Label("Download Whisper Model", systemImage: "arrow.down.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Label("Whisper Model", systemImage: "arrow.down.circle")
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("OpenAI Whisper runs entirely on your device. Your voice recordings never leave your phone.")
                            
                            if whisperService.isModelAvailable {
                                Text("✓ Accurate transcription\n✓ Proper punctuation\n✓ Sentence capitalization\n✓ 100% offline\n✓ Multi-language support")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // AI Enhancement Section
                Section {
                    Toggle("Use AI Enhancement", isOn: $useAIEnhancement)
                    
                    if useAIEnhancement {
                        Toggle("Auto-enhance new notes", isOn: $autoEnhanceNotes)
                            .disabled(!llmService.isModelAvailable)
                        
                        Text("Automatically clean and enhance text from new voice notes using local AI")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label("AI Features", systemImage: "wand.and.stars")
                } footer: {
                    if useAIEnhancement && !llmService.isModelAvailable {
                        Text("Download the AI model to enable automatic enhancement")
                            .foregroundColor(.orange)
                    }
                }
                
                // AI Model Section
                if useAIEnhancement {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            // Model info
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(llmService.availableModel.name)
                                        .font(.headline)
                                    Text("Quantized for mobile")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if llmService.isModelAvailable {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                }
                            }
                            
                            // Size info
                            HStack {
                                Image(systemName: "externaldrive")
                                    .foregroundColor(.secondary)
                                Text("Size: \(llmService.availableModel.size)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Status
                            HStack {
                                Image(systemName: llmService.isModelAvailable ? "checkmark.circle" : "arrow.down.circle")
                                    .foregroundColor(llmService.isModelAvailable ? .green : .orange)
                                Text(llmService.isModelAvailable ? "Downloaded & Ready" : "Not downloaded")
                                    .font(.subheadline)
                                    .foregroundColor(llmService.isModelAvailable ? .green : .orange)
                            }
                            
                            // Download/Delete button
                            if llmService.isDownloading {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Downloading AI Model...")
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(Int(llmService.downloadProgress * 100))%")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    ProgressView(value: llmService.downloadProgress)
                                        .progressViewStyle(.linear)
                                        .tint(.purple)
                                }
                            } else if llmService.isModelAvailable {
                                Button(role: .destructive, action: {
                                    showingDeleteConfirmation = true
                                }) {
                                    Label("Delete Model", systemImage: "trash")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button(action: downloadModel) {
                                    Label("Download AI Model", systemImage: "arrow.down.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.purple)
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Label("Local AI Model", systemImage: "brain")
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Phi-2 is a powerful language model that runs entirely on your device. No data ever leaves your phone.")
                            
                            if llmService.isModelAvailable {
                                Text("• Professional text enhancement\n• Removes filler words automatically\n• Adds proper punctuation\n• Creates concise summaries\n• Works 100% offline")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://example.com/support")!) {
                        HStack {
                            Text("Support")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "Delete AI Model?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteModel()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will free up \(llmService.availableModel.size) of storage. You can download it again anytime.")
            }
            .confirmationDialog(
                "Delete Whisper Model?",
                isPresented: $showingDeleteWhisperConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteWhisperModel()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will free up \(whisperService.selectedModel.size) of storage. You can download it again anytime.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func downloadModel() {
        Task {
            do {
                try await llmService.downloadModel()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func deleteModel() {
        do {
            try llmService.deleteModel()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func downloadWhisperModel() {
        Task {
            do {
                try await whisperService.downloadModel()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func deleteWhisperModel() {
        do {
            try whisperService.deleteModel()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    SettingsView()
}

