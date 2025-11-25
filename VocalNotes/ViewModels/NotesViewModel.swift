//
//  NotesViewModel.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import Foundation
import SwiftUI
import Combine

class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var topics: [Topic] = []
    @Published var selectedTopic: Topic?
    @Published var selectedDate: Date?
    @Published var searchQuery: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let storageService: StorageService
    private let intelligenceService: IntelligenceService
    
    init(
        storageService: StorageService = .shared,
        intelligenceService: IntelligenceService = .shared
    ) {
        self.storageService = storageService
        self.intelligenceService = intelligenceService
    }
    
    // MARK: - Data Loading
    
    func loadInitialData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load topics first
            topics = try storageService.fetchAllTopics()
            
            // If no topics exist, create defaults
            if topics.isEmpty {
                for defaultTopic in Topic.defaultTopics {
                    try storageService.createTopic(defaultTopic)
                }
                topics = try storageService.fetchAllTopics()
            }
            
            // Load notes
            try await loadNotes()
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }
    }
    
    func loadNotes() async throws {
        if let topic = selectedTopic {
            notes = try storageService.fetchNotes(forTopic: topic.id)
        } else if let date = selectedDate {
            notes = try storageService.fetchNotes(for: date)
        } else if !searchQuery.isEmpty {
            notes = try storageService.searchNotes(query: searchQuery)
        } else {
            notes = try storageService.fetchAllNotes()
        }
    }
    
    func refreshNotes() async {
        do {
            try await loadNotes()
        } catch {
            errorMessage = "Failed to refresh: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Note Management
    
    func createNote(rawText: String, cleanedText: String? = nil, summaryText: String? = nil, audioURL: URL?, duration: TimeInterval?) async {
        do {
            // Check if auto-enhance is enabled
            let autoEnhance = UserDefaults.standard.bool(forKey: "autoEnhanceNotes")
            
            // Use provided texts or generate if auto-enhance is on
            let finalCleanedText: String?
            let finalSummary: String?
            
            if cleanedText != nil {
                // User already enhanced manually
                finalCleanedText = cleanedText
            } else if autoEnhance {
                // Auto-enhance
                finalCleanedText = try? await intelligenceService.cleanText(rawText)
            } else {
                finalCleanedText = nil
            }
            
            if summaryText != nil {
                // User already summarized manually
                finalSummary = summaryText
            } else if autoEnhance {
                // Auto-summarize
                finalSummary = try? await intelligenceService.summarize(rawText)
            } else {
                finalSummary = nil
            }
            
            var note = Note(
                rawText: rawText,
                cleanedText: finalCleanedText,
                summaryText: finalSummary,
                audioFileURL: audioURL,
                audioDuration: duration
            )
            
            // Suggest topics if none assigned
            let suggestedTopics = await intelligenceService.suggestTopics(
                for: rawText,
                existingTopics: topics
            )
            if !suggestedTopics.isEmpty {
                note.topics = suggestedTopics.prefix(3).map { $0.id }
            }
            
            try storageService.createNote(note)
            try await loadNotes()
        } catch {
            errorMessage = "Failed to create note: \(error.localizedDescription)"
        }
    }
    
    func updateNote(_ note: Note) async {
        do {
            try storageService.updateNote(note)
            try await loadNotes()
        } catch {
            errorMessage = "Failed to update note: \(error.localizedDescription)"
        }
    }
    
    func deleteNote(_ note: Note) async {
        do {
            try storageService.deleteNote(note)
            try await loadNotes()
        } catch {
            errorMessage = "Failed to delete note: \(error.localizedDescription)"
        }
    }
    
    func enhanceNote(_ note: Note) async {
        do {
            var updatedNote = note
            updatedNote.cleanedText = try await intelligenceService.cleanText(note.rawText)
            updatedNote.summaryText = try await intelligenceService.summarize(note.rawText)
            
            // Suggest topics if none assigned
            if updatedNote.topics.isEmpty {
                let suggestedTopics = await intelligenceService.suggestTopics(
                    for: note.rawText,
                    existingTopics: topics
                )
                if !suggestedTopics.isEmpty {
                    updatedNote.topics = [suggestedTopics[0].id]
                }
            }
            
            try storageService.updateNote(updatedNote)
            try await loadNotes()
        } catch {
            errorMessage = "Failed to enhance note: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Topic Management
    
    func createTopic(_ topic: Topic) async {
        do {
            try storageService.createTopic(topic)
            topics = try storageService.fetchAllTopics()
        } catch {
            errorMessage = "Failed to create topic: \(error.localizedDescription)"
        }
    }
    
    func updateTopic(_ topic: Topic) async {
        do {
            try storageService.updateTopic(topic)
            topics = try storageService.fetchAllTopics()
        } catch {
            errorMessage = "Failed to update topic: \(error.localizedDescription)"
        }
    }
    
    func deleteTopic(_ topic: Topic) async {
        do {
            try storageService.deleteTopic(topic)
            topics = try storageService.fetchAllTopics()
            if selectedTopic?.id == topic.id {
                selectedTopic = nil
            }
            try await loadNotes()
        } catch {
            errorMessage = "Failed to delete topic: \(error.localizedDescription)"
        }
    }
    
    func getTopics(for note: Note) -> [Topic] {
        topics.filter { note.topics.contains($0.id) }
    }
    
    // MARK: - Filtering
    
    func filterByTopic(_ topic: Topic?) {
        selectedTopic = topic
        selectedDate = nil
        Task {
            try? await loadNotes()
        }
    }
    
    func filterByDate(_ date: Date?) {
        selectedDate = date
        selectedTopic = nil
        Task {
            try? await loadNotes()
        }
    }
    
    func clearFilters() {
        selectedTopic = nil
        selectedDate = nil
        searchQuery = ""
        Task {
            try? await loadNotes()
        }
    }
}

