//
//  Note.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import Foundation

struct Note: Identifiable, Hashable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var rawText: String
    var cleanedText: String?
    var summaryText: String?
    var topics: [UUID]
    var audioFileURL: URL?
    var audioDuration: TimeInterval?
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        rawText: String,
        cleanedText: String? = nil,
        summaryText: String? = nil,
        topics: [UUID] = [],
        audioFileURL: URL? = nil,
        audioDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.rawText = rawText
        self.cleanedText = cleanedText
        self.summaryText = summaryText
        self.topics = topics
        self.audioFileURL = audioFileURL
        self.audioDuration = audioDuration
    }
    
    var displayText: String {
        cleanedText ?? rawText
    }
    
    var firstLine: String {
        displayText.components(separatedBy: .newlines).first ?? ""
    }
}

