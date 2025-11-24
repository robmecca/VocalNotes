//
//  StorageService.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import Foundation
import CoreData

@MainActor
class StorageService {
    static let shared = StorageService()
    
    private let persistenceController: PersistenceController
    private var context: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Notes
    
    func createNote(_ note: Note) throws {
        let cdNote = CDNote(context: context)
        cdNote.id = note.id
        cdNote.createdAt = note.createdAt
        cdNote.updatedAt = note.updatedAt
        cdNote.rawText = note.rawText
        cdNote.cleanedText = note.cleanedText
        cdNote.summaryText = note.summaryText
        cdNote.audioFileURL = note.audioFileURL
        cdNote.audioDuration = note.audioDuration ?? 0
        
        // Link topics
        if !note.topics.isEmpty {
            let topics = try fetchTopics(withIds: note.topics)
            cdNote.topics = NSSet(array: topics)
        }
        
        try context.save()
    }
    
    func updateNote(_ note: Note) throws {
        let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)
        
        guard let cdNote = try context.fetch(request).first else {
            throw StorageError.noteNotFound
        }
        
        cdNote.updatedAt = Date()
        cdNote.rawText = note.rawText
        cdNote.cleanedText = note.cleanedText
        cdNote.summaryText = note.summaryText
        cdNote.audioFileURL = note.audioFileURL
        cdNote.audioDuration = note.audioDuration ?? 0
        
        // Update topics
        let topics = try fetchTopics(withIds: note.topics)
        cdNote.topics = NSSet(array: topics)
        
        try context.save()
    }
    
    func deleteNote(_ note: Note) throws {
        let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)
        
        guard let cdNote = try context.fetch(request).first else {
            throw StorageError.noteNotFound
        }
        
        // Delete audio file if exists
        if let audioURL = note.audioFileURL {
            try? FileManager.default.removeItem(at: audioURL)
        }
        
        context.delete(cdNote)
        try context.save()
    }
    
    func fetchAllNotes() throws -> [Note] {
        let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDNote.createdAt, ascending: false)]
        
        let cdNotes = try context.fetch(request)
        return cdNotes.map { convertToNote($0) }
    }
    
    func fetchNotes(for date: Date) throws -> [Note] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        request.predicate = NSPredicate(format: "createdAt >= %@ AND createdAt < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDNote.createdAt, ascending: true)]
        
        let cdNotes = try context.fetch(request)
        return cdNotes.map { convertToNote($0) }
    }
    
    func fetchNotes(forTopic topicId: UUID) throws -> [Note] {
        let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        request.predicate = NSPredicate(format: "ANY topics.id == %@", topicId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDNote.createdAt, ascending: false)]
        
        let cdNotes = try context.fetch(request)
        return cdNotes.map { convertToNote($0) }
    }
    
    func searchNotes(query: String) throws -> [Note] {
        let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        request.predicate = NSPredicate(format: "rawText CONTAINS[cd] %@ OR cleanedText CONTAINS[cd] %@", query, query)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDNote.createdAt, ascending: false)]
        
        let cdNotes = try context.fetch(request)
        return cdNotes.map { convertToNote($0) }
    }
    
    // MARK: - Topics
    
    func createTopic(_ topic: Topic) throws {
        let cdTopic = CDTopic(context: context)
        cdTopic.id = topic.id
        cdTopic.name = topic.name
        cdTopic.colorHex = topic.colorHex
        cdTopic.iconName = topic.iconName
        cdTopic.createdAt = topic.createdAt
        
        try context.save()
    }
    
    func updateTopic(_ topic: Topic) throws {
        let request: NSFetchRequest<CDTopic> = CDTopic.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", topic.id as CVarArg)
        
        guard let cdTopic = try context.fetch(request).first else {
            throw StorageError.topicNotFound
        }
        
        cdTopic.name = topic.name
        cdTopic.colorHex = topic.colorHex
        cdTopic.iconName = topic.iconName
        
        try context.save()
    }
    
    func deleteTopic(_ topic: Topic) throws {
        let request: NSFetchRequest<CDTopic> = CDTopic.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", topic.id as CVarArg)
        
        guard let cdTopic = try context.fetch(request).first else {
            throw StorageError.topicNotFound
        }
        
        context.delete(cdTopic)
        try context.save()
    }
    
    func fetchAllTopics() throws -> [Topic] {
        let request: NSFetchRequest<CDTopic> = CDTopic.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDTopic.name, ascending: true)]
        
        let cdTopics = try context.fetch(request)
        return cdTopics.map { convertToTopic($0) }
    }
    
    func fetchTopics(withIds ids: [UUID]) throws -> [CDTopic] {
        let request: NSFetchRequest<CDTopic> = CDTopic.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids)
        
        return try context.fetch(request)
    }
    
    // MARK: - Calendar Summaries
    
    func fetchDaySummaries(for month: Date) throws -> [DaySummary] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return []
        }
        
        let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        request.predicate = NSPredicate(format: "createdAt >= %@ AND createdAt <= %@", startOfMonth as NSDate, endOfMonth as NSDate)
        
        let cdNotes = try context.fetch(request)
        let notes = cdNotes.map { convertToNote($0) }
        
        // Group by day
        var summariesDict: [String: DaySummary] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for note in notes {
            let dayStart = calendar.startOfDay(for: note.createdAt)
            let key = dateFormatter.string(from: dayStart)
            
            if var summary = summariesDict[key] {
                summary = DaySummary(
                    date: summary.date,
                    noteCount: summary.noteCount + 1,
                    totalDuration: (summary.totalDuration ?? 0) + (note.audioDuration ?? 0),
                    topicCounts: mergeCounts(summary.topicCounts, note.topics)
                )
                summariesDict[key] = summary
            } else {
                var topicCounts: [UUID: Int] = [:]
                for topicId in note.topics {
                    topicCounts[topicId] = 1
                }
                summariesDict[key] = DaySummary(
                    date: dayStart,
                    noteCount: 1,
                    totalDuration: note.audioDuration,
                    topicCounts: topicCounts
                )
            }
        }
        
        return Array(summariesDict.values).sorted { $0.date < $1.date }
    }
    
    // MARK: - Helper Methods
    
    private func convertToNote(_ cdNote: CDNote) -> Note {
        let topicIds = (cdNote.topics?.allObjects as? [CDTopic])?.map { $0.id! } ?? []
        
        return Note(
            id: cdNote.id!,
            createdAt: cdNote.createdAt!,
            updatedAt: cdNote.updatedAt!,
            rawText: cdNote.rawText!,
            cleanedText: cdNote.cleanedText,
            summaryText: cdNote.summaryText,
            topics: topicIds,
            audioFileURL: cdNote.audioFileURL,
            audioDuration: cdNote.audioDuration > 0 ? cdNote.audioDuration : nil
        )
    }
    
    private func convertToTopic(_ cdTopic: CDTopic) -> Topic {
        Topic(
            id: cdTopic.id!,
            name: cdTopic.name!,
            colorHex: cdTopic.colorHex!,
            iconName: cdTopic.iconName,
            createdAt: cdTopic.createdAt!
        )
    }
    
    private func mergeCounts(_ existing: [UUID: Int], _ newTopics: [UUID]) -> [UUID: Int] {
        var result = existing
        for topicId in newTopics {
            result[topicId, default: 0] += 1
        }
        return result
    }
}

enum StorageError: Error {
    case noteNotFound
    case topicNotFound
    case saveFailed
}

