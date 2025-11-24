//
//  DaySummary.swift
//  VocalNotes
//
//  Created by Roberto Mecca on 23/11/2025.
//

import Foundation

struct DaySummary: Identifiable {
    var id: String {
        dateString
    }
    
    let date: Date
    let noteCount: Int
    let totalDuration: TimeInterval?
    let topicCounts: [UUID: Int]
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    var hasNotes: Bool {
        noteCount > 0
    }
}

